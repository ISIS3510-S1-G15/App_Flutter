import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../services/history_worker.dart';
import '../services/recent_views_service.dart';
import '../services/restaurant_service.dart';
import '../theme/app_theme.dart';
import '../widgets/back_header.dart';
import '../widgets/circle_button.dart';
import '../widgets/offline_banner.dart';
import 'detail_screen.dart';
import '../widgets/restaurant_image.dart';

class RecentlyViewedScreen extends StatefulWidget {
  const RecentlyViewedScreen({super.key});

  @override
  State<RecentlyViewedScreen> createState() => _RecentlyViewedScreenState();
}

class _RecentlyViewedScreenState extends State<RecentlyViewedScreen> {
  List<Map<String, dynamic>> _sections = const [];
  int _groupId = 0;
  Map<String, Restaurant> _byId = const {};
  List<Object> _rows = const [];

  @override
  void initState() {
    super.initState();
    RecentViewsService.items.addListener(_regroup);
    RestaurantService.restaurants.addListener(_onCatalogChanged);
    _indexCatalog();
    _regroup();
    RecentViewsService.load();
  }

  @override
  void dispose() {
    RecentViewsService.items.removeListener(_regroup);
    RestaurantService.restaurants.removeListener(_onCatalogChanged);
    super.dispose();
  }

  void _onCatalogChanged() {
    if (!mounted) return;
    setState(() {
      _indexCatalog();
      _buildRows();
    });
  }

  void _indexCatalog() {
    _byId = {for (final r in RestaurantService.restaurants.value) r.id: r};
  }

  void _buildRows() {
    final rows = <Object>[];
    for (final section in _sections) {
      final entries = <_HistoryEntry>[];
      for (final item in section['items'] as List) {
        final view = RecentView.fromJson(Map<String, dynamic>.from(item as Map));
        final restaurant = _byId[view.restaurantId];
        if (restaurant != null) entries.add(_HistoryEntry(view, restaurant, _time(view.lastViewedAt)));
      }
      if (entries.isEmpty) continue;
      rows.add((section['title'] as String).toUpperCase());
      rows.addAll(entries);
    }
    _rows = rows;
  }

  Future<void> _regroup() async {
    final id = ++_groupId;
    final sections = await HistoryWorker.group(
      RecentViewsService.items.value.map((v) => v.toJson()).toList(),
      DateTime.now(),
    );
    if (!mounted || id != _groupId) return;
    setState(() {
      _sections = sections;
      _buildRows();
    });
  }


  Future<void> _remove(Restaurant r) async {
    final messenger = ScaffoldMessenger.of(context);
    final synced = await RecentViewsService.remove(r.id);
    messenger.showSnackBar(SnackBar(
      content: Text(synced
          ? '${r.name} removed from your history'
          : '${r.name} removed on this phone. It will sync when you\'re back online.'),
    ));
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('All the restaurants you viewed will be removed from this list.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed == true) await RecentViewsService.clearHistory();
  }

  String _time(DateTime utc) {
    final t = utc.toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BackHeader(
              eyebrow: 'History',
              title: 'Recently viewed',
              onBack: () => Navigator.of(context).pop(),
              trailing: AppCircleButton(icon: Icons.delete_outline, onTap: _confirmClear),
            ),
            const OfflineBanner(
              message: "You're offline. This is the history saved on this phone. Removed places will sync when you're back online.",
              margin: EdgeInsets.fromLTRB(20, 0, 20, 8),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ValueListenableBuilder<DateTime?>(
                    valueListenable: RecentViewsService.updatedAt,
                    builder: (context, updated, _) => Text(
                      updated == null ? 'Not synced yet' : 'Updated at ${_time(updated)}',
                      style: AppTextStyles.body.copyWith(fontSize: 11, color: AppColors.closed),
                    ),
                  ),
                  const Spacer(),
                  ValueListenableBuilder<int>(
                    valueListenable: RecentViewsService.pendingChanges,
                    builder: (context, pending, _) => pending == 0
                        ? const SizedBox.shrink()
                        : Text(
                            pending == 1 ? '1 change waiting to sync' : '$pending changes waiting to sync',
                            style: AppTextStyles.body.copyWith(fontSize: 11, color: AppColors.accent),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => RecentViewsService.load(force: true),
                child: _rows.isEmpty ? _empty() : _list(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.history, size: 48, color: AppColors.mutedLight),
        const SizedBox(height: 12),
        Center(
          child: Text(
            "You haven't opened any restaurant yet",
            style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'The places you open will appear here.',
            style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  Widget _list() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _rows.length,
      itemBuilder: (context, i) {
        final row = _rows[i];
        if (row is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              row,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.6),
            ),
          );
        }
        final entry = row as _HistoryEntry;
        final r = entry.restaurant;
        return Dismissible(
          key: ValueKey('recent-${r.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 28),
            color: AppColors.accent,
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) {
            setState(() {
              _sections = [
                for (final s in _sections)
                  {
                    'title': s['title'],
                    'items': (s['items'] as List).where((e) => (e as Map)['restaurant_id'] != r.id).toList(),
                  },
              ];
              _buildRows();
            });
            _remove(r);
          },
          child: _RecentRow(
            restaurant: r,
            view: entry.view,
            lastSeen: entry.lastSeen,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DetailScreen(restaurant: r)),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryEntry {
  final RecentView view;
  final Restaurant restaurant;
  final String lastSeen;

  const _HistoryEntry(this.view, this.restaurant, this.lastSeen);
}

class _RecentRow extends StatelessWidget {
  final Restaurant restaurant;
  final RecentView view;
  final String lastSeen;
  final VoidCallback onTap;

  const _RecentRow({required this.restaurant, required this.view, required this.lastSeen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final open = restaurant.isOpenNow;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RestaurantImage(restaurant, width: 64, height: 64, placeholderColor: AppColors.border),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                        ),
                      ),
                      Text(
                        open ? 'Open' : 'Closed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: open ? AppColors.open : AppColors.closed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${restaurant.category} · ${restaurant.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${view.viewCount == 1 ? 'Viewed 1 time' : 'Viewed ${view.viewCount} times'} · last at $lastSeen',
                    style: AppTextStyles.body.copyWith(fontSize: 11, color: AppColors.mutedLight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
