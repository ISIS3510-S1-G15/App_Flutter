import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/survey_answers.dart';
import '../data/profile_data.dart';
import '../widgets/progress_bar.dart';
import '../utils/text_utils.dart';
import '../widgets/app_chip.dart';
import '../widgets/circle_button.dart';
import 'survey_screen.dart';
import 'auth_gate.dart';
import '../services/auth_service.dart';

// Number of survey fields counted towards "Profile completeness"
const _totalFields = 6;

class ProfileScreen extends StatelessWidget {
  // StatelessWidget because this screen only displays the profile saved by the survey (no state of its own)

  // What the back button does. MainNavigation passes a callback thatswitches back to the previous tab.
  // If this screen is pushed as a route instead, the back button pops the route.
  final VoidCallback? onBack;

  const ProfileScreen({super.key, this.onBack});

  void _onRetakeSurvey(BuildContext context) {
    // Opens the survey again (pre-filled with the current answers). When it is saved, userProfile changes,
    // this screen redraws with the new data, and the survey closes itself returning here
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SurveyScreen(onComplete: () => Navigator.of(context).pop()),
      ),
    );
  }

  void _handleBack(BuildContext context) {
    // Uses the parent's callback if it gave one (tab mode); otherwise pops this route (pushed mode)
    if (onBack != null) {
      onBack!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listens to the profile saved by the survey: every time it changes, the builder runs again with the new answers
    return ValueListenableBuilder<SurveyAnswers>(
      valueListenable: userProfile,
      builder: (context, profile, _) => _buildContent(context, profile),
    );
  }

  Widget _buildContent(BuildContext context, SurveyAnswers profile) {
    // First two letters of the name shown in the avatar; "ME" if there is no name yet
    final initials = initialsOf(profile.name, fallback: 'ME');

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
            // Top bar: back button + title + "Edit"
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppCircleButton(
                    icon: Icons.arrow_back_ios_new,
                    onTap: () => _handleBack(context),
                  ),
                  Text('My Profile', style: AppTextStyles.headline.copyWith(fontSize: 17)),
                  GestureDetector(
                    onTap: () => _onRetakeSurvey(context),
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

            // Hero card: avatar, name, university and completeness bar
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
                  AppProgressBar(progress: progress, trackColor: Colors.white.withOpacity(0.1)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats row: three equal-width tiles
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

            // Dietary Restrictions (green chips) 
            // Each section below is only shown if the user answered that question
            if (profile.dietaryRestrictions.isNotEmpty)
              _Section(
                title: 'Dietary Restrictions',
                emoji: '🌿',
                child: Wrap(
                  // Wrap lets the chips flow to a new line automatically if there are many
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.dietaryRestrictions.map((d) => AppChip.diet(diet: d)).toList(),
                ),
              ),

            // Cuisine Preferences (white chips)
            if (profile.cuisines.isNotEmpty)
              _Section(
                title: 'Cuisine Preferences',
                emoji: '🌍',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.cuisines
                      .map((c) => AppChip(
                            label: c,
                            background: AppColors.card,
                            textColor: AppColors.dark,
                            borderColor: AppColors.border,
                          ))
                      .toList(),
                ),
              ),

            // Usual Meal Times (one row per time, with an orange dot)
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

            // Top Priorities (one row per priority, numbered by rank)
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
                            border: Border.all(color: AppColors.border),
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

            // Foods to Avoid (free text written in the survey)
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
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(profile.dislikedFoods, style: AppTextStyles.body.copyWith(fontSize: 13)),
                ),
              ),

            // Actions: retake the survey
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: InkWell(
                onTap: () => _onRetakeSurvey(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
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

            // Session: logged-in email + "Log out" (closes the session and goes back to the login screen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                children: [
                  if (AuthService.currentUser.value != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Logged in as ${AuthService.currentUser.value!.email}',
                        style: AppTextStyles.body.copyWith(fontSize: 11, color: AppColors.muted),
                      ),
                    ),
                  InkWell(
                    onTap: () => AuthGate.logout(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout, size: 16, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text(
                            'Log out',
                            style: AppTextStyles.body.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
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

// Reusable widget: one tile of the stats row (emoji, value, label)
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
        border: Border.all(color: AppColors.borderLight),
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
          Text(label, style: AppTextStyles.body.copyWith(fontSize: 10, color: AppColors.muted)),
        ],
      ),
    );
  }
}

// Reusable widget: section with an emoji + title header and any content below
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

// Reusable widget: white row with a leading widget and a label (meal times and priorities)
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
        border: Border.all(color: AppColors.borderLight),
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
