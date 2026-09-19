import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/restaurants_data.dart';
import '../models/restaurant.dart';
import '../widgets/crowding_badge.dart';
import '../widgets/filter_chip.dart';
import 'detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String _filter = 'all'; // 'all' | 'open'
  Restaurant? _selected;

  void _onSelect(Restaurant r) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(restaurant: r)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filter == 'all' ? restaurants : restaurants.where((r) => r.isOpen).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- Header ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Campus Map', style: AppTextStyles.headline.copyWith(fontSize: 22)),
                  const SizedBox(height: 2),
                  Text('Universidad de los Andes — Campus Principal',
                      style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.closed)),
                ],
              ),
            ),

            // ---------- Filter row ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  AppFilterChip(
                    label: 'All Spots',
                    active: _filter == 'all',
                    activeColor: AppColors.dark,
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  AppFilterChip(
                    label: 'Open Now',
                    active: _filter == 'open',
                    activeColor: AppColors.open,
                    onTap: () => setState(() => _filter = 'open'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Map area ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _CampusMapPainter())),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: visible.map((r) {
                              final isSelected = _selected?.id == r.id;
                              final left = constraints.maxWidth * (r.mapX / 100);
                              final top = constraints.maxHeight * (r.mapY / 100);
                              return Positioned(
                                left: left - 16,
                                top: top - 32,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selected = isSelected ? null : r),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSelected)
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(r.name,
                                                  style: AppTextStyles.cardTitle.copyWith(fontSize: 11)),
                                              Text(r.waitTime,
                                                  style: TextStyle(fontSize: 9, color: AppColors.closed)),
                                            ],
                                          ),
                                        ),
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.accent
                                              : (r.isOpen ? AppColors.dark : AppColors.closed),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                                        ),
                                        child: Center(
                                          child: Text(_categoryEmoji(r.category), style: const TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      // Legend
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _LegendRow(color: AppColors.dark, label: 'Open'),
                              const SizedBox(height: 4),
                              _LegendRow(color: AppColors.closed, label: 'Closed'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ---------- Selected restaurant card ----------
            if (_selected != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _SelectedCard(restaurant: _selected!, onTap: () => _onSelect(_selected!)),
              ),

            // ---------- Quick list ----------
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  Text('Nearby — ${visible.length} spots', style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
                  const SizedBox(height: 12),
                  ...visible.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _QuickListItem(
                          restaurant: r,
                          selected: _selected?.id == r.id,
                          onTap: () => setState(() => _selected = r),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// _FilterChip was moved to lib/widgets/filter_chip.dart (AppFilterChip) so HomeScreen can reuse it

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 9, color: AppColors.closed)),
      ],
    );
  }
}

class _SelectedCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const _SelectedCard({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.closed.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                r.image,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  color: AppColors.closed.withOpacity(0.3),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(r.name,
                            style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (r.isOpen ? AppColors.open : AppColors.closed).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          r.isOpen ? 'Open' : 'Closed',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: r.isOpen ? AppColors.open : AppColors.closed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(r.location, style: AppTextStyles.body.copyWith(fontSize: 11, color: AppColors.closed)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 10, color: AppColors.accent),
                      const SizedBox(width: 2),
                      Text('${r.rating}', style: AppTextStyles.cardTitle.copyWith(fontSize: 11)),
                      const SizedBox(width: 8),
                      Text('• ${r.waitTime}', style: TextStyle(fontSize: 11, color: AppColors.closed)),
                      const SizedBox(width: 8),
                      CrowdingBadge(reports: r.crowdingReports, small: true),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.closed.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}

class _QuickListItem extends StatelessWidget {
  final Restaurant restaurant;
  final bool selected;
  final VoidCallback onTap;

  const _QuickListItem({required this.restaurant, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.accent : AppColors.closed.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Text(_categoryEmoji(r.category), style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('${r.waitTime} wait', style: TextStyle(fontSize: 11, color: AppColors.closed)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (r.isOpen ? AppColors.open : AppColors.closed).withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                r.isOpen ? 'Open' : 'Closed',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: r.isOpen ? AppColors.open : AppColors.closed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Maps a restaurant category to a matching emoji, used for map pins and quick list rows
String _categoryEmoji(String cat) {
  const map = {
    'Dining Hall': '🍽',
    'Café': '☕',
    'Asian': '🍜',
    'Burgers': '🍔',
    'Indian': '🍛',
    'Smoothies': '🥤',
  };
  return map[cat] ?? '🍴';
}

// Decorative stylized campus map background (paths, buildings, water) matching the Figma design
class _CampusMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ground
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFD4E8C2));

    // Paths
    final pathPaint = Paint()
      ..color = const Color(0xFFC5D9B2)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path1 = Path()
      ..moveTo(0, h * 0.5)
      ..quadraticBezierTo(w * 0.3, h * 0.47, w * 0.5, h * 0.5)
      ..quadraticBezierTo(w * 0.71, h * 0.53, w, h * 0.48);
    canvas.drawPath(path1, pathPaint..strokeWidth = h * 0.06);

    final path2 = Path()
      ..moveTo(w * 0.5, 0)
      ..quadraticBezierTo(w * 0.51, h * 0.27, w * 0.5, h * 0.5)
      ..quadraticBezierTo(w * 0.49, h * 0.73, w * 0.5, h);
    canvas.drawPath(path2, pathPaint..strokeWidth = h * 0.045);

    final path3 = Path()
      ..moveTo(0, h * 0.27)
      ..quadraticBezierTo(w * 0.23, h * 0.28, w * 0.5, h * 0.27)
      ..quadraticBezierTo(w * 0.74, h * 0.25, w, h * 0.27);
    canvas.drawPath(path3, pathPaint..strokeWidth = h * 0.033);

    // Buildings
    final buildingPaint = Paint()..color = const Color(0xFFA8C4E0).withOpacity(0.8);
    void building(double x, double y, double bw, double bh) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * x, h * y, w * bw, h * bh), const Radius.circular(6)),
        buildingPaint,
      );
    }

    building(0.09, 0.07, 0.17, 0.15);
    building(0.37, 0.10, 0.16, 0.13);
    building(0.66, 0.05, 0.20, 0.17);
    building(0.11, 0.62, 0.14, 0.18);
    building(0.39, 0.67, 0.19, 0.15);
    building(0.69, 0.58, 0.21, 0.20);

    // Water feature
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: w * 0.1, height: h * 0.08),
      Paint()..color = const Color(0xFF7AB8D4).withOpacity(0.6),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
