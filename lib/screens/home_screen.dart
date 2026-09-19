import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/restaurants_data.dart';
import '../data/profile_data.dart';
import '../models/restaurant.dart';
import '../models/survey_answers.dart';
import '../widgets/crowding_badge.dart';
import '../widgets/filter_chip.dart';
import 'detail_screen.dart';
import 'profile_screen.dart';

// Category pills shown under "Today's Pick". 'All' shows every restaurant
const _categories = ['All', 'Dining Hall', 'Café', 'Asian', 'Burgers', 'Indian', 'Smoothies'];

class HomeScreen extends StatefulWidget {
  // StatefulWidget because the screen changes when the user taps a category chip (it needs to remember which one is active)
  final SurveyAnswers profile;

  // Defaults to the shared mock profile (lib/data/profile_data.dart) until the survey produces a real one
  const HomeScreen({super.key, this.profile = mockProfile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _activeCategory = 'All'; // Which category pill is currently selected

  List<Restaurant> get _filtered {
    // Restaurants that belong to the active category (or all of them if 'All' is selected)
    if (_activeCategory == 'All') return restaurants;
    return restaurants.where((r) => r.category == _activeCategory).toList();
  }

  void _onSelect(Restaurant r) {
    // Called when the user taps the featured card or a restaurant card
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(restaurant: r)),
    );
  }

  void _onOpenProfile() {
    // Called when the user taps the avatar in the header. Pushes the profile on top so its back button returns here
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(profile: widget.profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final filtered = _filtered;
    final featured = restaurants.first; // "Today's Pick" is always the first restaurant of the list

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ---------- Header: university label + greeting/title + avatar button ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UNIVERSIDAD DE LOS ANDES',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        // Greets the user by name if the survey has one; otherwise shows the app name
                        profile.name.isNotEmpty ? 'Hola, ${profile.name} 👋' : 'Campus Eats',
                        style: AppTextStyles.headline.copyWith(fontSize: 26, height: 1.2),
                      ),
                    ],
                  ),
                  // Dark round button: user's initials if there is a name, otherwise a person icon
                  InkWell(
                    onTap: _onOpenProfile,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: AppColors.dark, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: profile.name.isNotEmpty
                          ? Text(
                              profile.name.substring(0, 2).toUpperCase(),
                              style: AppTextStyles.headline.copyWith(fontSize: 13, color: Colors.white),
                            )
                          : const Icon(Icons.person, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // ---------- Today's Pick: big featured card (only when no category filter is active) ----------
            if (_activeCategory == 'All') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Today's Pick", style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
                    Text(
                      'See all',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _FeaturedCard(restaurant: featured, onTap: () => _onSelect(featured)),
              ),
              const SizedBox(height: 20),
            ],

            // ---------- Categories: horizontally scrollable row of pills ----------
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                // Horizontal so the pills that don't fit can be scrolled sideways
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  return AppFilterChip(
                    label: cat,
                    active: _activeCategory == cat,
                    // Tapping a pill changes the filter and Flutter redraws the list below
                    onTap: () => setState(() => _activeCategory = cat),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // ---------- List header: "N Spots Near You" + Filter ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    // e.g. "4 Spots Near You" or "1 Café Near You" depending on the active category
                    '${filtered.length} ${_activeCategory == 'All' ? 'Spots' : _activeCategory} Near You',
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.filter_list, size: 14, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Filter',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Restaurant list: one card per filtered restaurant ----------
            ...filtered.map((r) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _RestaurantCard(restaurant: r, onTap: () => _onSelect(r)),
                )),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ---------- Reusable widget: large "Today's Pick" card with photo, gradient and info overlay ----------
class _FeaturedCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const _FeaturedCard({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = restaurant;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          // Soft shadow so the card looks lifted from the background
          boxShadow: [BoxShadow(color: AppColors.dark.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          // Clips the photo and gradient to the rounded corners
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                r.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AppColors.closed.withOpacity(0.3)),
              ),
              // Dark gradient from the bottom so the white text stays legible over the photo
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppColors.dark, AppColors.dark.withOpacity(0.3), Colors.transparent],
                  ),
                ),
              ),
              // Info block pinned to the bottom of the card
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Pill(label: 'FEATURED', background: AppColors.accent),
                        const SizedBox(width: 8),
                        _Pill(
                          label: r.isOpen ? 'OPEN' : 'CLOSED',
                          background: r.isOpen ? AppColors.open : AppColors.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.name,
                      style: AppTextStyles.headline.copyWith(fontSize: 20, color: Colors.white, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 12, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text('${r.rating}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        const SizedBox(width: 12),
                        Text(r.location, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                        const SizedBox(width: 12),
                        Text('• ${r.waitTime}', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Reusable widget: small solid pill with uppercase white text (FEATURED / OPEN / CLOSED) ----------
class _Pill extends StatelessWidget {
  final String label;
  final Color background;

  const _Pill({required this.label, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
      ),
    );
  }
}

// ---------- Reusable widget: horizontal restaurant card (photo on the left, info on the right) ----------
class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const _RestaurantCard({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final statusColor = r.isOpen ? AppColors.open : AppColors.muted;

    return InkWell(
      onTap: onTap, // Makes the entire card tappable (with a "ripple" effect when tapped)
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: ClipRRect(
          // Clips the photo to the card's rounded corners
          borderRadius: BorderRadius.circular(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo (or a gray box if the image fails to load) with a bookmark badge if the restaurant is saved
              SizedBox(
                width: 100,
                height: 90,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      r.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: AppColors.closed.withOpacity(0.3)),
                    ),
                    if (r.saved)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.bookmark, size: 12, color: AppColors.accent),
                        ),
                      ),
                  ],
                ),
              ),

              // Restaurant info: name + status, location, rating/price/wait time, tags + crowding
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              r.name,
                              style: AppTextStyles.cardTitle.copyWith(fontSize: 14, height: 1.2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis, // Cuts long names with "..."
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Open/Closed pill: soft tinted background with the same color for the text
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              r.isOpen ? 'OPEN' : 'CLOSED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.location,
                        style: AppTextStyles.body.copyWith(fontSize: 11, color: AppColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Meta row: ★ rating (reviews) · price · ⏱ wait time
                      Wrap(
                        // Wrap instead of Row so it moves to a second line instead of overflowing on narrow screens
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 11, color: AppColors.accent),
                              const SizedBox(width: 2),
                              Text('${r.rating}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.dark)),
                            ],
                          ),
                          Text('(${r.reviews})', style: const TextStyle(fontSize: 11, color: AppColors.mutedLight)),
                          const Text('·', style: TextStyle(fontSize: 11, color: AppColors.mutedLight)),
                          Text(r.price,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.muted)),
                          const Text('·', style: TextStyle(fontSize: 11, color: AppColors.mutedLight)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule, size: 10, color: AppColors.muted),
                              const SizedBox(width: 3),
                              Text(r.waitTime, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Tags row: first two tags + crowding badge (hidden by CrowdingBadge itself if there are no reports)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...r.tags.take(2).map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(tag, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                              )),
                          CrowdingBadge(reports: r.crowdingReports, small: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
