import 'dart:async';
import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../models/review.dart';
import '../services/connectivity_service.dart';
import '../services/my_reviews_service.dart';
import '../services/pending_reviews.dart';
import '../services/restaurant_service.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';
import '../utils/text_utils.dart';
import '../widgets/back_header.dart';
import '../widgets/my_review_card.dart';
import '../widgets/offline_banner.dart';
import 'detail_screen.dart';

// EVENTUAL CONNECTIVITY (this view):
// - Opens with the local copy at once (Hive), offline too, and then the backend answer (cache then network).
// - Reviews written offline are on top as "Pending sync" and are counted in the summary (same as Kotlin).
// - When the connection comes back, or the queue changes, it reloads by itself (no Retry needed).

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyReviewsScreen()));

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  static const _white60 = Color(0x99FFFFFF);

  StreamSubscription<MyReviewsSnapshot>? _sub;
  List<Review> _reviews = const [];
  MyReviewsSummary _summary = MyReviewsSummary.empty;
  bool _loading = true;
  bool _failed = false;
  bool _hasData = false; // true after the first snapshot with data; an empty list is data, not "nothing loaded"
  DateTime? _savedAt;
  int _pendingCount = 0;
  bool _online = ConnectivityService.isOnline.value;

  @override
  void initState() {
    super.initState();
    ConnectivityService.isOnline.addListener(_onConnectivity);
    PendingReviews.count.addListener(_watch);
    ReviewService.syncRejected.addListener(_onSyncRejected);
    // A rejection that happened before the screen was opened is still reported (after the first frame,
    // because a SnackBar needs the Scaffold to exist)
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSyncRejected());
    _watch(); // Like Kotlin: reloaded every time the view is opened
  }

  @override
  void dispose() {
    _sub?.cancel();
    ConnectivityService.isOnline.removeListener(_onConnectivity);
    PendingReviews.count.removeListener(_watch);
    ReviewService.syncRejected.removeListener(_onSyncRejected);
    super.dispose();
  }

  // Subscribes to the repository's cache-then-network stream. The previous subscription is cancelled first,
  // so an old (slower) answer can never overwrite a newer one
  void _watch() {
    _sub?.cancel();
    _sub = MyReviewsService.watch().listen(
      _onSnapshot,
      onError: (Object e) {
        debugPrint('My reviews stream failed: $e');
        _onSnapshot(MyReviewsSnapshot.failure);
      },
    );
  }

  void _onSnapshot(MyReviewsSnapshot s) {
    if (!mounted) return; // the user closed the screen before the answer arrived
    setState(() {
      _loading = false;
      if (s.failed) {
        _failed = true;
        return; // keep what is already on screen, if anything
      }
      _reviews = s.reviews;
      _summary = MyReviewsSummary.from(s.reviews);
      _savedAt = s.savedAt;
      _pendingCount = s.pendingCount;
      _failed = false;
      _hasData = true;
    });
  }

  void _onConnectivity() {
    final online = ConnectivityService.isOnline.value;
    final cameBack = online && !_online;
    if (mounted) setState(() => _online = online);
    if (cameBack) _watch();
  }

  void _onSyncRejected() {
    final name = ReviewService.syncRejected.value;
    if (name == null || !mounted) return;
    ReviewService.syncRejected.value = null; // shown once
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Your review of $name could not be posted.')),
    );
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _watch();
  }

  void _openRestaurant(Review r) {
    final matches = RestaurantService.restaurants.value.where((x) => x.id == r.restaurantId);
    if (matches.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(restaurant: matches.first)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BackHeader(eyebrow: 'Profile', title: 'My Reviews', onBack: () => Navigator.of(context).pop()),
            // Banners only over data: the error states below already explain themselves
            if (_hasData) ...[
              OfflineBanner(margin: const EdgeInsets.fromLTRB(20, 0, 20, 12), message: _offlineMessage()),
              if (_online && _pendingCount > 0) _SyncingBanner(count: _pendingCount),
            ],
            _buildBody(),
          ],
        ),
      ),
    );
  }

  // Same texts as the Kotlin OfflineBanner: pending changes first, otherwise how old the copy is
  String _offlineMessage() {
    if (_pendingCount > 0) {
      return "You're offline · $_pendingCount change${_pendingCount == 1 ? '' : 's'} waiting to sync";
    }
    return _savedAt != null
        ? "You're offline · showing your reviews saved on ${formatDate(_savedAt!)}"
        : "You're offline · showing your reviews from your last visit";
  }

  Widget _buildBody() {
    if (!_hasData && _loading) {
      return const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.accent)));
    }
    // A failed request must NOT say "No reviews yet": that would tell the user something false
    if (!_hasData && _failed) return _online ? _buildError() : _buildOfflineNoCopy();
    return Expanded(child: _buildList());
  }

  // Offline the first time, with no local copy and nothing queued. No Retry: it loads by itself on reconnect
  Widget _buildOfflineNoCopy() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.muted),
              const SizedBox(height: 12),
              Text("You're offline", style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                "Connect once to load your reviews. After that they'll be available offline.",
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Online, but the backend failed and there was nothing local to show
  Widget _buildError() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.muted),
              const SizedBox(height: 12),
              Text("Couldn't load your reviews", style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: _retry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    // Listens to the catalog: if it arrives after the reviews, the restaurant names appear by themselves
    return ValueListenableBuilder<List<Restaurant>>(
      valueListenable: RestaurantService.restaurants,
      builder: (context, restaurants, _) {
        final byId = {for (final r in restaurants) r.id: r};
        // Item 0 = summary card; then the empty state OR one card per review
        final itemCount = 1 + (_reviews.isEmpty ? 1 : _reviews.length);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index == 0) return _buildSummaryCard();
            if (_reviews.isEmpty) return _buildEmpty();
            final review = _reviews[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MyReviewCard(
                review: review,
                restaurantName: byId[review.restaurantId]?.name ?? 'Restaurant',
                onTap: () => _openRestaurant(review),
              ),
            );
          },
        );
      },
    );
  }

  // Dark card: how many reviews the user wrote (left) and the average rating they gave (right)
  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_summary.count}',
                style: AppTextStyles.headline.copyWith(fontSize: 36, color: Colors.white),
              ),
              Text(_summary.countLabel, style: const TextStyle(fontSize: 12, color: _white60)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 18, color: AppColors.amber),
                  const SizedBox(width: 6),
                  Text(
                    _summary.averageLabel,
                    style: AppTextStyles.headline.copyWith(fontSize: 24, color: Colors.white),
                  ),
                ],
              ),
              const Text('Avg. rating given', style: TextStyle(fontSize: 11, color: _white60)),
            ],
          ),
        ],
      ),
    );
  }

  // Only when the request worked and the user has not written any review yet
  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Text('✍️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('No reviews yet', style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'Reviews you write for campus spots will appear here.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// "Syncing N changes…": online with reviews still in the queue (the sync runs ~3 s after reconnecting).
// Same look as OfflineBanner (which only shows offline and must not be modified), with a cloud icon
class _SyncingBanner extends StatelessWidget {
  final int count;

  const _SyncingBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined, color: AppColors.card, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Syncing $count change${count == 1 ? '' : 's'}…',
              style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.card),
            ),
          ),
        ],
      ),
    );
  }
}
