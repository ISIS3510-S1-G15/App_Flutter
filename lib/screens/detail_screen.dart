import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/restaurant.dart';
import '../widgets/crowding_badge.dart';
import '../services/occupancy_service.dart';
import '../widgets/occupancy_survey.dart';

class DetailScreen extends StatefulWidget {
  final Restaurant restaurant;

  const DetailScreen({super.key, required this.restaurant});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late bool _saved = widget.restaurant.saved;
  int _activeMenu = 0;
  List<int> _liveReports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final reports = await OccupancyService.getReports(widget.restaurant.id);
    if (mounted) {
      setState(() => _liveReports = reports);
    }
  }

  void _onWriteReview() {
    // TODO: Navigator.push a WriteReviewScreen(widget.restaurant)
  }

  void _onSeeReviews() {
    // TODO: Navigator.push a ReviewsListScreen(widget.restaurant)
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final crowdAvg = _liveReports.isEmpty
        ? null
        : _liveReports.reduce((a, b) => a + b) / _liveReports.length;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                        onTap: () => setState(() => _saved = !_saved),
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
                        color: r.isOpen ? AppColors.open : AppColors.closed,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        r.isOpen ? 'OPEN NOW' : 'CLOSED',
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
                                Text('${r.rating}',
                                    style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
                              ],
                            ),
                            label: '${r.reviews} reviews',
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
                if (crowdAvg != null)
                  _CrowdingCard(avg: crowdAvg, reports: _liveReports)
                else
                  _EmptyCrowdingCard(),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await OccupancySurvey.show(context, r.id, r.name);
                    _loadReports(); // refresh the card right after reporting
                  },
                  icon: const Icon(Icons.people_outline, size: 16),
                  label: const Text('Report crowding level'),
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
                      Text('See ${r.reviews} Reviews', style: AppTextStyles.button.copyWith(color: AppColors.dark)),
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
  final double avg;
  final List<int> reports;

  const _CrowdingCard({required this.avg, required this.reports});

  @override
  Widget build(BuildContext context) {
    late String label;
    late Color color;
    if (avg < 0.7) {
      label = 'Not crowded';
      color = AppColors.open;
    } else if (avg < 1.4) {
      label = 'Moderate';
      color = AppColors.accent;
    } else {
      label = 'Busy';
      color = AppColors.closed;
    }

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
              CrowdingBadge(reports: reports),
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
                '${avg.toStringAsFixed(1)} / 2 · ${reports.length} report${reports.length != 1 ? 's' : ''}',
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