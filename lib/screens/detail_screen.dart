import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/offline_banner.dart';
import '../models/restaurant.dart';
import '../widgets/crowding_badge.dart';
import '../widgets/occupancy_survey.dart';
import '../services/occupancy_service.dart';
import '../services/review_service.dart';
import '../services/occupancy_check_analytics.dart';
import '../services/place_selection_analytics.dart';
import 'package:url_launcher/url_launcher.dart';
import 'reviews_list_screen.dart';
import 'write_review_screen.dart';
import '../services/saved_service.dart';
import '../services/restaurant_view_analytics.dart';

class DetailScreen extends StatefulWidget {
  final Restaurant restaurant;

  const DetailScreen({super.key, required this.restaurant});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  // Saved state comes from the backend (SavedService), not from the fixed "saved" field of the restaurant
  bool get _saved => SavedService.isSaved(widget.restaurant.id);
  int _activeMenu = 0;
  bool _checkLogged = false; // The occupancy check is logged once per visit to this screen

  // Asks the backend again for the occupancy while the screen is open, so "real time" means
  // "at most 30 s old". A shorter period spends more battery and data for a value that rarely changes faster
  static const _pollEvery = Duration(seconds: 30);
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    RestaurantViewAnalytics.logView(widget.restaurant.id); // BQ Type 3: every time the detail is opened
    _refreshOccupancy(OccupancyRefreshSource.detailOpen);
    _pollTimer = Timer.periodic(_pollEvery, (_) => _refreshOccupancy(OccupancyRefreshSource.detailPoll));
    // The screen redraws when any of the data it shows changes (bookmark, crowding, rating)
    SavedService.savedIds.addListener(_onDataChanged);
    OccupancyService.statuses.addListener(_onDataChanged);
    ReviewService.summaries.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _pollTimer?.cancel(); // without this the timer would keep calling the backend after leaving the screen
    SavedService.savedIds.removeListener(_onDataChanged);
    OccupancyService.statuses.removeListener(_onDataChanged);
    ReviewService.summaries.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onToggleSaved() async {
    final synced = await SavedService.toggle(widget.restaurant.id);
    if (!synced && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Change kept on this phone. It will sync when you're back online.")));
    }
  }

  Future<void> _refreshOccupancy(OccupancyRefreshSource source) async {
    // Updates OccupancyService.statuses; the listener above redraws the card (and the badges of other screens)
    final status = await OccupancyService.refresh(widget.restaurant.id, source: source);
    // The indicator is now on screen: counts as checking the occupancy (once per visit)
    if (mounted && !_checkLogged) {
      _checkLogged = true;
      OccupancyCheckAnalytics.logCheck(widget.restaurant.id, hasData: status.hasData);
    }
  }

  void _onWriteReview() {
    // Opens the review form for this restaurant ("Back to Restaurant" returns here)
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WriteReviewScreen(restaurant: widget.restaurant)),
    );
  }

  void _onSeeReviews() {
    // Opens the list of reviews of this restaurant (from there the user can also write one)
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReviewsListScreen(restaurant: widget.restaurant)),
    );
  }

  Future<void> _onGetDirections() async {
    // Tapping "Get directions" is the user's decision to go (BQ: did they check the occupancy first?)
    final r = widget.restaurant;
    OccupancyCheckAnalytics.logGoDecision(r.id);
    PlaceSelectionAnalytics.logSelection(r.id); // BQ Type 2: time from opening the app to choosing a place
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${r.latitude},${r.longitude}&travelmode=walking');
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the map')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final occupancy = OccupancyService.statusOf(r.id); // same data the badges of Home/Map/Search/Saved use
    final rating = ReviewService.summaryOf(r.id);      // calculated by the backend from the real reviews

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const SafeArea(
        top: false,
        child: OfflineBanner(
          message: "You're offline. Crowding and ratings may be outdated. You can still save this place and it will sync later.",
          margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---------- Hero image with back/save buttons and status chips ----------
          Stack(
            children: [
              SizedBox(
                height: 240,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      r.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: AppColors.closed.withOpacity(0.3)),
                    ),
                    // Dark gradient so the top buttons and bottom chips stay legible
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [AppColors.dark.withOpacity(0.55), Colors.transparent],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                left: 20,
                right: 20,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CircleButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      _CircleButton(
                        icon: _saved ? Icons.bookmark : Icons.bookmark_border,
                        iconColor: _saved ? AppColors.accent : AppColors.dark,
                        onTap: _onToggleSaved,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 20,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: r.isOpenNow ? AppColors.open : AppColors.closed,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        r.isOpenNow ? 'OPEN NOW' : 'CLOSED',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        r.category,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ---------- Info card: name, location, stats ----------
          Transform.translate(
            offset: const Offset(0, -24),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: AppTextStyles.headline.copyWith(fontSize: 22)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(r.location, style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.closed)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.closed.withOpacity(0.15))),
                      ),
                      child: Row(
                        children: [
                          _StatColumn(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star, size: 14, color: AppColors.accent),
                                const SizedBox(width: 3),
                                Text(rating.label, style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
                              ],
                            ),
                            label: '${rating.count} review${rating.count != 1 ? 's' : ''}',
                          ),
                          _StatDivider(),
                          _StatColumn(
                            child: Text(r.waitTime, style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
                            label: 'Wait time',
                          ),
                          _StatDivider(),
                          _StatColumn(
                            child: Text(r.price, style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
                            label: 'Price range',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- Hours & tags ----------
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text(r.hours, style: AppTextStyles.bodyMedium.copyWith(fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: r.tags
                            .map((t) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: AppColors.closed.withOpacity(0.25)),
                                  ),
                                  child: Text(t,
                                      style: AppTextStyles.body.copyWith(fontSize: 11.5, color: AppColors.closed)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),

                // ---------- Crowding ----------
                const SizedBox(height: 12),
                if (occupancy.hasData)
                  _CrowdingCard(restaurantId: r.id, status: occupancy)
                else
                  _EmptyCrowdingCard(),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    // The backend answers the report with the new status, so the card updates by itself
                    await OccupancySurvey.show(context, r.id, r.name);
                  },
                  icon: const Icon(Icons.people_outline, size: 16),
                  label: const Text('Report crowding level'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.closed.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _onGetDirections,
                  icon: const Icon(Icons.directions_walk, size: 16),
                  label: const Text('Get directions'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.closed.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),

                // ---------- Description ----------
                if (r.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(r.description, style: AppTextStyles.body.copyWith(fontSize: 13, height: 1.5, color: AppColors.closed)),
                ],

                // ---------- Menu ----------
                if (r.menu.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Menu', style: AppTextStyles.headline.copyWith(fontSize: 18)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: r.menu.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final active = i == _activeMenu;
                        return GestureDetector(
                          onTap: () => setState(() => _activeMenu = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: active ? AppColors.accent : AppColors.card,
                              borderRadius: BorderRadius.circular(999),
                              border: active ? null : Border.all(color: AppColors.closed.withOpacity(0.25)),
                            ),
                            child: Center(
                              child: Text(
                                r.menu[i].category,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: active ? Colors.white : AppColors.closed,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...r.menu[_activeMenu].items.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
                                  const SizedBox(height: 3),
                                  Text(item.desc,
                                      style: AppTextStyles.body.copyWith(fontSize: 11.5, color: AppColors.closed)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(item.price,
                                style: AppTextStyles.cardTitle.copyWith(fontSize: 13, color: AppColors.accent)),
                          ],
                        ),
                      )),
                ],

                const SizedBox(height: 12),

                // ---------- Review CTAs ----------
                OutlinedButton(
                  onPressed: _onSeeReviews,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.closed.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, size: 16, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text(rating.count == 0 ? 'No reviews yet' : 'See ${rating.count} Review${rating.count != 1 ? 's' : ''}', style: AppTextStyles.button.copyWith(color: AppColors.dark)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _onWriteReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.edit, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text('Write a Review', style: AppTextStyles.button),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, this.iconColor = AppColors.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final Widget child;
  final String label;

  const _StatColumn({required this.child, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          child,
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.closed)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: AppColors.closed.withOpacity(0.15));
  }
}

// Card showing how crowded the place is right now, based on recent reports (0-2 scale, same as CrowdingBadge)
class _CrowdingCard extends StatelessWidget {
  final String restaurantId;
  final OccupancyStatus status; // only built when status.hasData is true

  const _CrowdingCard({required this.restaurantId, required this.status});

  // "just now", "5 min ago": tells the user how fresh the value is (it can be an older, cached one if offline)
  String get _updatedAgo {
    final minutes = DateTime.now().difference(status.lastReportAt!).inMinutes;
    return minutes < 1 ? 'just now' : '$minutes min ago';
  }

  @override
  Widget build(BuildContext context) {
    final avg = status.level!;
    final reports = status.reports;
    final style = crowdingStyle(avg); // same thresholds as CrowdingBadge (defined only once)
    final label = style.label;
    final color = style.color;

    // Scale the 0-2 average onto a 5-bar indicator for a richer visual
    final litBars = ((avg / 2) * 5).round().clamp(0, 5);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(5, (i) {
                      return Container(
                        margin: const EdgeInsets.only(right: 3),
                        width: 4,
                        height: 6.0 + (i + 1) * 3,
                        decoration: BoxDecoration(
                          color: i < litBars ? color : AppColors.closed.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  Text('$label right now',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                ],
              ),
              CrowdingBadge(restaurantId: restaurantId),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: avg / 2,
                    minHeight: 6,
                    backgroundColor: AppColors.closed.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${reports.length} report${reports.length != 1 ? 's' : ''} · $_updatedAgo',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Shown when a restaurant has no crowding reports yet
class _EmptyCrowdingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.closed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.closed.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.closed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No crowding reports yet. Be the first to help other students!',
              style: TextStyle(fontSize: 12.5, color: AppColors.closed),
            ),
          ),
        ],
      ),
    );
  }
}