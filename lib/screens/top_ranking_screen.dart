import 'dart:async';
import 'package:flutter/material.dart';
import '../ranking/ranking_models.dart';
import '../ranking/ranking_repository.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';
import '../widgets/restaurant_image.dart';
import 'detail_screen.dart';

// Top Ranking: Flutter mirror of the Kotlin RankingView + RankingViewModel (same pills, texts and order).
//
// EVENTUAL CONNECTIVITY (this view):
// - Opening it shows the last ranking saved in SQLite at once, with or without internet
//   ("Offline · showing saved ranking from 14:05").
// - Tapping refresh offline does not fail: the refresh is QUEUED ("Refresh queued · it will update when
//   you're back online") and runs by itself when the connection comes back.
// - When the connection comes back and the ranking is older than 30 min (TTL), it refreshes by itself.
// - Offline with nothing saved: a specific message instead of an empty screen.
class TopRankingScreen extends StatefulWidget {
  const TopRankingScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TopRankingScreen()));

  @override
  State<TopRankingScreen> createState() => _TopRankingScreenState();
}

class _TopRankingScreenState extends State<TopRankingScreen> {
  static const _gold = Color(0xFFE0A526);
  static const _silver = Color(0xFF9AA0A6);
  static const _bronze = Color(0xFFB87333);
  static const _up = Color(0xFF2E9B57);
  static const _down = Color(0xFFD64545);

  final _repo = RankingRepository.instance;

  RankingCriterion _criterion = RankingCriterion.overall;
  RankingWindow _window = RankingWindow.month;
  List<RankedRestaurant> _items = const [];
  bool _loading = true;
  bool _online = ConnectivityService.isOnline.value;
  DateTime? _lastUpdated;
  bool _refreshQueued = false;
  int _request = 0; // only the answer of the newest request is shown (the user may change pills fast)

  @override
  void initState() {
    super.initState();
    ConnectivityService.isOnline.addListener(_onConnectivity);
    _open();
  }

  @override
  void dispose() {
    ConnectivityService.isOnline.removeListener(_onConnectivity);
    super.dispose();
  }

  Future<void> _onConnectivity() async {
    final online = ConnectivityService.isOnline.value;
    final cameBack = online && !_online;
    if (mounted) setState(() => _online = online);
    if (!cameBack) return;
    if (_refreshQueued) {
      setState(() => _refreshQueued = false);
      _load(refresh: true); // the refresh the user asked for while offline
    } else if (await _repo.isStale()) {
      _load(refresh: true);
    }
  }

  // Saved ranking first (instant, offline too), then the one computed with the data on the phone,
  // and finally a refresh from the backend if there is internet and the data is older than the TTL
  Future<void> _open() async {
    final request = ++_request;
    final c = _criterion, w = _window;
    final stored = await _repo.snapshot(c, w);
    if (!mounted || request != _request) return;
    if (stored != null) {
      setState(() {
        _items = stored.items;
        _loading = false;
        _lastUpdated = stored.computedAt;
      });
    }
    await _show(request, c, w, refresh: false);
    if (mounted && request == _request && _online && await _repo.isStale()) _load(refresh: true);
  }

  void _load({required bool refresh}) {
    final request = ++_request;
    setState(() => _loading = true);
    _show(request, _criterion, _window, refresh: refresh);
  }

  Future<void> _show(int request, RankingCriterion c, RankingWindow w, {required bool refresh}) async {
    try {
      final result = await _repo.load(c, w, refresh: refresh);
      final last = await _repo.lastRefreshAt();
      if (!mounted || request != _request) return;
      setState(() {
        _items = result.items;
        _loading = false;
        _lastUpdated = last ?? result.computedAt;
      });
    } catch (e) {
      debugPrint('Ranking: could not compute: $e');
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _selectCriterion(RankingCriterion c) {
    if (c == _criterion) return;
    setState(() => _criterion = c);
    _load(refresh: false);
  }

  void _selectWindow(RankingWindow w) {
    if (w == _window) return;
    setState(() => _window = w);
    _load(refresh: false);
  }

  void _refresh() {
    if (_online) {
      _load(refresh: true);
    } else {
      setState(() => _refreshQueued = true);
    }
  }

  String? get _status {
    // 24-hour "HH:mm", same as the Kotlin RankingView
    final t = _lastUpdated;
    final time = t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (_refreshQueued) return "Refresh queued · it will update when you're back online";
    if (!_online) return 'Offline · showing saved ranking${time == null ? '' : ' from $time'}';
    if (time != null) return 'Updated $time';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final warn = _refreshQueued || !_online;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundButton(icon: Icons.arrow_back, tooltip: 'Back', onTap: () => Navigator.of(context).pop()),
                  const Text('Top Ranking',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.dark)),
                  _RoundButton(icon: Icons.refresh, tooltip: 'Refresh', onTap: _refresh),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final c in RankingCriterion.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Pill(label: c.label, selected: c == _criterion, onTap: () => _selectCriterion(c)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final w in RankingWindow.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Pill(label: w.label, selected: w == _window, onTap: () => _selectWindow(w)),
                    ),
                ],
              ),
            ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: warn ? AppColors.accent : AppColors.muted,
                    fontWeight: warn ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_items.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _row(_items[i]),
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          _online ? 'Not enough data to rank restaurants yet' : "You're offline and there is no saved data to rank",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.muted),
        ),
      ),
    );
  }

  Widget _row(RankedRestaurant item) {
    final ratings = item.reviewCount == 1 ? 'rating' : 'ratings';
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => DetailScreen(restaurant: item.restaurant))),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _positionBadge(item.position),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RestaurantImage(item.restaurant, width: 52, height: 52),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.dark)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: LinearProgressIndicator(
                        value: (item.score / 5).clamp(0.0, 1.0),
                        minHeight: 5,
                        color: AppColors.accent,
                        backgroundColor: AppColors.border,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.score.toStringAsFixed(2)} · ${item.reviewCount} $ratings'
                      '${item.isFallback ? ' · none this month' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _movementTag(item.movement),
            ],
          ),
        ),
      ),
    );
  }

  Widget _positionBadge(int position) {
    final color = switch (position) {
      1 => _gold,
      2 => _silver,
      3 => _bronze,
      _ => AppColors.border,
    };
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text('$position',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w900, color: position <= 3 ? Colors.white : AppColors.dark)),
    );
  }

  Widget _movementTag(int? movement) {
    if (movement == null) return const SizedBox.shrink();
    final (text, color) = movement > 0
        ? ('▲ $movement', _up)
        : movement < 0
            ? ('▼ ${-movement}', _down)
            : ('–', AppColors.muted);
    return Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color));
  }
}

// Orange trophy button that opens Top Ranking (same as the Kotlin Home header button)
class TopRankingButton extends StatelessWidget {
  const TopRankingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => TopRankingScreen.open(context),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.emoji_events, color: Colors.white, size: 20, semanticLabel: 'Top ranking'),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 18, color: AppColors.dark, semanticLabel: tooltip)),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.accent : AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.dark)),
        ),
      ),
    );
  }
}
