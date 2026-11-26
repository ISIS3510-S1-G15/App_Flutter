import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../models/review.dart';
import '../services/my_reviews_service.dart';
import '../services/restaurant_service.dart';
import '../theme/app_theme.dart';
import '../widgets/back_header.dart';
import '../widgets/my_review_card.dart';
import 'detail_screen.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyReviewsScreen()));

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  static const _white60 = Color(0x99FFFFFF);

  List<Review> _reviews = const [];
  MyReviewsSummary _summary = MyReviewsSummary.empty;
  bool _loading = true;
  bool _failed = false;
  bool _hasData = false; // true after the first successful load; an empty list is data, not "nothing loaded"

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // initState already starts with _loading = true (setState is not allowed inside initState)
    if (!_loading || _failed) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    try {
      final reviews = await MyReviewsService.fetch();
      if (!mounted) return; // the user closed the screen before the answer arrived
      setState(() {
        _reviews = reviews;
        _summary = MyReviewsSummary.from(reviews);
        _hasData = true;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Could not load my reviews: $e');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
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
            _buildBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasData && _loading) {
      return const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.accent)));
    }
    // A failed request must NOT say "No reviews yet": that would tell the user something false
    if (!_hasData && _failed) return _buildError();
    return Expanded(child: _buildList());
  }

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
              TextButton(onPressed: _load, child: const Text('Retry')),
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
