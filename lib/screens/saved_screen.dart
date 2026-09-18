import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/restaurants_data.dart';
import '../models/restaurant.dart';
import '../widgets/crowding_badge.dart';
import 'detail_screen.dart';

// The person's saved dietary preferences (currently hardcoded; in the future, these will come from the onboarding survey or user profile)
const _userDietaryPreferences = ['Vegan', 'Vegetarian'];

class SavedScreen extends StatelessWidget {
  // StatelessWidget because this screen doesn't manage its own changing state (displays saved data)
  const SavedScreen({super.key});

  void _onSelect(BuildContext context, Restaurant r) {
    // Called when the user taps a restaurant card
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(restaurant: r)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filters the full restaurant list into three groups used across this screen
    final saved = restaurants.where((r) => r.saved).toList();
    final openNow = restaurants.where((r) => r.isOpen).take(3).toList();
    final recentlyViewed = restaurants.where((r) => !r.saved).take(4).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // ---------- Header: title + saved count + "add" button ----------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saved', style: AppTextStyles.headline.copyWith(fontSize: 24)),
                    Text('${saved.length} spots saved',
                        style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.closed)),
                  ],
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.closed.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.add, size: 18, color: AppColors.dark),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ---------- Dietary Preferences ----------
            // Plain text only
            Text('Dietary Preferences', style: AppTextStyles.cardTitle.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            if (_userDietaryPreferences.isEmpty)
              // Fallback text shown if the user hasn't set any preferences yet
              Text(
                'No dietary preferences set',
                style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.closed),
              )
            else
              Wrap(
                // Wrap lets the text items flow to a new line automatically if there are many
                spacing: 6,
                runSpacing: 6,
                children: _userDietaryPreferences
                    .map((d) => Text(
                          '${_dietEmoji(d)} $d',
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark,
                          ),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 20),

            // ---------- Open Right Now ----------
            // Dark card highlighting up to 3 currently open restaurants, showing their closing time as a quick reference
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.dark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Open Right Now',
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 13, color: Colors.white)),
                  const SizedBox(height: 12),
                  ...openNow.map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(_categoryEmoji(r.category), style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 8),
                                Text(r.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    )),
                              ],
                            ),
                            Row(
                              children: [
                                // Small green circle indicating "currently open" status
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.open,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  // Splits the times from hours and takes only the closing time
                                  r.hours.split('–').last.trim(),
                                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---------- Your Spots (the actual bookmarked restaurants) ----------
            Text('Your Spots', style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
            const SizedBox(height: 12),
            if (saved.isEmpty)
              // Empty state shown when the user hasn't saved anything yet
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.closed.withOpacity(0.15), blurRadius: 6)],
                      ),
                      child: Icon(Icons.bookmark_border, size: 28, color: AppColors.closed),
                    ),
                    const SizedBox(height: 12),
                    Text('No saved spots yet', style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Bookmark restaurants to find them here',
                        style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.closed)),
                  ],
                ),
              )
            else
              // One big card per saved restaurant, stacked vertically
              ...saved.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SavedCard(
                      restaurant: r,
                      onTap: () => _onSelect(context, r),
                    ),
                  )),
            const SizedBox(height: 20),

            // ---------- Recently Viewed (horizontal scroll of non-saved places) ----------
            Text('Recently Viewed', style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                // Horizontal instead of vertical, unlike "Your Spots" above
                itemCount: recentlyViewed.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final r = recentlyViewed[i];
                  return GestureDetector(
                    onTap: () => _onSelect(context, r),
                    child: Container(
                      width: 120,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.closed.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: Image.asset(
                                  r.image,
                                  height: 80,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 80,
                                    color: AppColors.closed.withOpacity(0.3),
                                  ),
                                ),
                              ),
                              // Small "Open"/"Closed" tag over the photo
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: r.isOpen
                                        ? AppColors.open
                                        : AppColors.dark.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    r.isOpen ? 'Open' : 'Closed',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.name,
                                  style: AppTextStyles.cardTitle.copyWith(fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.star, size: 8, color: AppColors.accent),
                                    const SizedBox(width: 2),
                                    Text('${r.rating}',
                                        style: TextStyle(fontSize: 10, color: AppColors.closed)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Reusable widget: one large card for a saved restaurant ----------
class _SavedCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const _SavedCard({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = restaurant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.closed.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // Full-width photo at the top of the card
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.asset(
                    r.image,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 130,
                      color: AppColors.closed.withOpacity(0.3),
                    ),
                  ),
                ),
                // Name + rating overlaid at the bottom of the photo
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r.name,
                          style: AppTextStyles.headline.copyWith(color: Colors.white, fontSize: 17)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.star, size: 10, color: AppColors.accent),
                            const SizedBox(width: 2),
                            Text('${r.rating}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Bookmark icon in the top-right corner, confirming it's saved
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.bookmark, size: 13, color: AppColors.accent),
                  ),
                ),
              ],
            ),
            // Bottom row: location on the left, status + crowding badge on the right
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r.location,
                      style: AppTextStyles.body.copyWith(fontSize: 11, color: AppColors.closed)),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      const SizedBox(width: 6),
                      const CrowdingBadge(reports: [], small: true),
                    ],
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

// Maps a restaurant category to a matching emoji, used in the "Open Right Now" card
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

// Maps a dietary preference to a matching emoji, used in the Dietary Preferences section
String _dietEmoji(String d) {
  const map = {
    'Vegan': '🌱',
    'Gluten-free': '🌾',
    'Halal': '☪️',
    'Vegetarian': '🥗',
  };
  return map[d] ?? '✓';
}