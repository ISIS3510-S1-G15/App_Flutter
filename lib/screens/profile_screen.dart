import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/survey_answers.dart';

// Colors used only in this screen (everything else comes from AppColors)
const _border = Color(0xFFE8E0D4);      // border of white cards and chips
const _borderLight = Color(0xFFF0E8DE); // softer border for list rows and stat tiles
const _muted = Color(0xFF7A6D5F);       // secondary text under stat tiles
const _greenBg = Color(0xFFE8F5EB);     // dietary restriction chip background
const _greenText = Color(0xFF3A8C4F);   // dietary restriction chip text
const _greenBorder = Color(0xFFC5E0CB); // dietary restriction chip border

// Number of survey fields counted towards "Profile completeness"
const _totalFields = 6;

// The person's survey answers (currently hardcoded; in the future, these will come from the onboarding survey)
const _mockProfile = SurveyAnswers(
  cuisines: ['Mexican', 'Vegetarian'],
  dietaryRestrictions: ['Lactose-free', 'Halal'],
  mealFrequency: 'Daily',
  mealTimes: ['Dinner'],
  budget: '\$8.000 – \$15.000',
  priorities: ['Sustainability', 'Proximity', 'Variety'],
);

class ProfileScreen extends StatelessWidget {
  // StatelessWidget because this screen only displays the profile it receives (no state of its own)
  final SurveyAnswers profile;

  const ProfileScreen({super.key, this.profile = _mockProfile});

  void _onRetakeSurvey() {
    // TODO: Navigator.push a SurveyScreen so the user can answer the survey again
  }

  @override
  Widget build(BuildContext context) {
    // First two letters of the name shown in the avatar; "ME" if there is no name yet
    final initials = profile.name.isNotEmpty ? profile.name.substring(0, 2).toUpperCase() : 'ME';

    // Counts how many of the survey fields have been answered, to fill the progress bar
    final completeness = [
      profile.cuisines.isNotEmpty,
      profile.dietaryRestrictions.isNotEmpty,
      profile.mealFrequency.isNotEmpty,
      profile.mealTimes.isNotEmpty,
      profile.budget.isNotEmpty,
      profile.priorities.isNotEmpty,
    ].where((filled) => filled).length;
    final progress = completeness / _totalFields; // 0.0 – 1.0

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ---------- Top bar: back button + title + "Edit" ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleButton(
                    icon: Icons.arrow_back_ios_new,
                    // maybePop: goes back only if there is a screen to go back to (the tab itself has none)
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  Text('My Profile', style: AppTextStyles.headline.copyWith(fontSize: 17)),
                  GestureDetector(
                    onTap: _onRetakeSurvey,
                    child: Text(
                      'Edit',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---------- Hero card: avatar, name, university and completeness bar ----------
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.dark,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Orange square avatar with the user's initials
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: AppTextStyles.headline.copyWith(fontSize: 22, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            // Fallback name when the survey has no name yet
                            profile.name.isNotEmpty ? profile.name : 'Uniandino',
                            style: AppTextStyles.headline.copyWith(fontSize: 20, color: Colors.white, height: 1.2),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Universidad de los Andes',
                            style: AppTextStyles.body.copyWith(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Thin divider line between the name block and the progress bar
                  Divider(height: 1, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Profile completeness',
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 11, color: Colors.white.withOpacity(0.6)),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Progress bar: grey track with an orange fill whose width is the completeness percentage
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 6,
                      color: Colors.white.withOpacity(0.1),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(color: AppColors.accent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---------- Stats row: three equal-width tiles ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      emoji: '🌍',
                      value: profile.cuisines.isEmpty ? '—' : '${profile.cuisines.length}',
                      label: 'Cuisines',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(
                      emoji: '🕐',
                      value: profile.mealFrequency.isEmpty ? '—' : profile.mealFrequency,
                      label: 'Frequency',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(
                      emoji: '💰',
                      value: profile.budget.isEmpty ? '—' : profile.budget,
                      label: 'Budget',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---------- Dietary Restrictions (green chips) ----------
            // Each section below is only shown if the user answered that question
            if (profile.dietaryRestrictions.isNotEmpty)
              _Section(
                title: 'Dietary Restrictions',
                emoji: '🌿',
                child: Wrap(
                  // Wrap lets the chips flow to a new line automatically if there are many
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.dietaryRestrictions
                      .map((d) => _Chip(
                            label: '✓ $d',
                            background: _greenBg,
                            textColor: _greenText,
                            borderColor: _greenBorder,
                          ))
                      .toList(),
                ),
              ),

            // ---------- Cuisine Preferences (white chips) ----------
            if (profile.cuisines.isNotEmpty)
              _Section(
                title: 'Cuisine Preferences',
                emoji: '🌍',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.cuisines
                      .map((c) => _Chip(
                            label: c,
                            background: AppColors.card,
                            textColor: AppColors.dark,
                            borderColor: _border,
                          ))
                      .toList(),
                ),
              ),

            // ---------- Usual Meal Times (one row per time, with an orange dot) ----------
            if (profile.mealTimes.isNotEmpty)
              _Section(
                title: 'Usual Meal Times',
                emoji: '⏰',
                child: Column(
                  children: profile.mealTimes
                      .map((t) => _ListRow(
                            leading: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            label: t,
                          ))
                      .toList(),
                ),
              ),

            // ---------- Top Priorities (one row per priority, numbered by rank) ----------
            if (profile.priorities.isNotEmpty)
              _Section(
                title: 'Top Priorities',
                emoji: '⭐',
                child: Column(
                  children: [
                    for (int i = 0; i < profile.priorities.length; i++)
                      _ListRow(
                        leading: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            shape: BoxShape.circle,
                            border: Border.all(color: _border),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: AppTextStyles.body.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        label: profile.priorities[i],
                      ),
                  ],
                ),
              ),

            // ---------- Foods to Avoid (free text written in the survey) ----------
            if (profile.dislikedFoods.isNotEmpty)
              _Section(
                title: 'Foods to Avoid',
                emoji: '🚫',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderLight),
                  ),
                  child: Text(profile.dislikedFoods, style: AppTextStyles.body.copyWith(fontSize: 13)),
                ),
              ),

            // ---------- Actions: retake the survey ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: InkWell(
                onTap: _onRetakeSurvey,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bookmark_border, size: 16, color: AppColors.dark),
                      const SizedBox(width: 8),
                      Text(
                        'Retake Food Preferences Survey',
                        style: AppTextStyles.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Reusable widget: round white button with an icon (used for "back") ----------
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: _border),
        ),
        child: Icon(icon, size: 16, color: AppColors.dark),
      ),
    );
  }
}

// ---------- Reusable widget: one tile of the stats row (emoji, value, label) ----------
class _StatTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _StatTile({required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: AppTextStyles.cardTitle.copyWith(fontSize: 11, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.body.copyWith(fontSize: 10, color: _muted)),
        ],
      ),
    );
  }
}

// ---------- Reusable widget: section with an emoji + title header and any content below ----------
class _Section extends StatelessWidget {
  final String title;
  final String emoji;
  final Widget child;

  const _Section({required this.title, required this.emoji, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.cardTitle.copyWith(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ---------- Reusable widget: rounded pill chip (dietary restrictions and cuisines) ----------
class _Chip extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;
  final Color borderColor;

  const _Chip({
    required this.label,
    required this.background,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: AppTextStyles.body.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }
}

// ---------- Reusable widget: white row with a leading widget and a label (meal times and priorities) ----------
class _ListRow extends StatelessWidget {
  final Widget leading;
  final String label;

  const _ListRow({required this.leading, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.bodyMedium.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}
