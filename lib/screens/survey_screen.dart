import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/profile_data.dart';
import '../models/survey_answers.dart';
import '../widgets/progress_bar.dart';

// Number of steps (pages) of the survey
const _totalSteps = 5;

// Options the user can choose from in each question
const _cuisines = ['Colombian', 'Mediterranean', 'Asian', 'American', 'Mexican', 'Italian', 'Indian', 'Middle Eastern', 'Vegetarian', 'Vegan'];
const _dietary = ['None', 'Vegetarian', 'Vegan', 'Gluten-free', 'Lactose-free', 'Halal', 'Kosher', 'Nut-free'];
const _mealTimes = ['Breakfast', 'Mid-morning snack', 'Lunch', 'Afternoon snack', 'Dinner', 'Late night'];
const _frequencies = ['Daily', '4–5x / week', '2–3x / week', 'Once a week'];
const _priorities = ['Price', 'Speed', 'Nutrition', 'Taste', 'Variety', 'Proximity', 'Sustainability'];
const _maxPriorities = 3;

// Budget options: a record with the label (saved in the profile), a short description and an emoji
const _budgets = [
  (label: 'Under \$8.000', sub: 'Looking for the best deals', emoji: '💸'),
  (label: '\$8.000 – \$15.000', sub: 'Mid-range, good value', emoji: '💵'),
  (label: '\$15.000 – \$25.000', sub: 'Happy to spend a bit more', emoji: '🪙'),
  (label: 'Over \$25.000', sub: 'Quality is top priority', emoji: '💎'),
];

class SurveyScreen extends StatefulWidget {
  // StatefulWidget because the screen remembers the current step and the answers while the user goes through it

  final bool isOnboarding;
  // true when it is the first screen of the app (shows the "Welcome to Campus Eats" header on step 1)
  // false when it is opened again from the profile ("Retake survey" / "Edit")

  final VoidCallback onComplete;
  // What to do after the answers are saved (onboarding: go to the app; retake: go back to the profile)

  const SurveyScreen({super.key, required this.onComplete, this.isOnboarding = false});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  int _step = 0;       // Current step, from 0 to _totalSteps - 1
  bool _done = false;  // true after "Save Preferences" is tapped (shows the "¡Listo!" screen)

  // Starts from the current profile: empty on onboarding, pre-filled when the user retakes the survey
  late SurveyAnswers _answers = userProfile.value;

  // Controllers of the two text fields, initialized with the current answers so retaking shows what was written
  late final _nameController = TextEditingController(text: _answers.name);
  late final _dislikedController = TextEditingController(text: _answers.dislikedFoods);

  @override
  void dispose() {
    // Frees the memory of the text controllers when the screen is destroyed
    _nameController.dispose();
    _dislikedController.dispose();
    super.dispose();
  }

  // Adds the value to the list if it isn't there, or removes it if it already is (used by the multi-select chips)
  List<String> _toggle(List<String> list, String value) {
    return list.contains(value) ? list.where((v) => v != value).toList() : [...list, value];
  }

  void _togglePriority(String value) {
    // Priorities allow at most 3: a new one can only be added if there is room, but any can be removed
    final selected = _answers.priorities;
    if (selected.contains(value) || selected.length < _maxPriorities) {
      setState(() => _answers = _answers.copyWith(priorities: _toggle(selected, value)));
    }
  }

  void _next() {
    // "Continue" goes to the next step; on the last step "Save Preferences" saves the profile
    FocusScope.of(context).unfocus(); // Closes the keyboard if a text field was open
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _save();
    }
  }

  void _back() {
    // Goes to the previous step (the back button is only shown from step 2 onwards)
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _save() async {
    // Saves the answers as the user's profile. Every screen listening to userProfile (Home, Profile) redraws
    userProfile.value = _answers.copyWith(name: _answers.name.trim(), dislikedFoods: _answers.dislikedFoods.trim());
    setState(() => _done = true);

    // Shows the "¡Listo!" confirmation for a moment before moving on
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) widget.onComplete(); // "mounted" checks the screen still exists after the wait
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildDone();

    return PopScope(
      // Android back gesture/button: goes to the previous step instead of closing the survey
      // (it only leaves the screen when the user is already on the first step)
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Header: title + progress (fixed at the top, does not scroll)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: _buildHeader(),
              ),

              // Content of the current step (scrolls if it doesn't fit, e.g. when the keyboard is open)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: _buildStep(),
                ),
              ),

              // Navigation: back button (from step 2) + Continue / Save Preferences
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      GestureDetector(
                        onTap: _back,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.dark),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: GestureDetector(
                        onTap: _next,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _step < _totalSteps - 1 ? 'Continue' : 'Save Preferences',
                                style: AppTextStyles.button.copyWith(fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
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

  // Title (welcome message on the first onboarding step, "Survey" otherwise) + progress bar + step dots
  Widget _buildHeader() {
    final showWelcome = widget.isOnboarding && _step == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showWelcome) ...[
          Text('UNIVERSIDAD DE LOS ANDES', style: _eyebrowStyle),
          Text('Welcome to\nCampus Eats 👋', style: AppTextStyles.headline.copyWith(fontSize: 26, height: 1.2)),
          const SizedBox(height: 4),
          Text(
            'Tell us a bit about yourself so we can personalize your experience.',
            style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Text('FOOD PREFERENCES', style: _eyebrowStyle),
          const SizedBox(height: 2),
          Text('Survey', style: AppTextStyles.headline.copyWith(fontSize: 22)),
          const SizedBox(height: 12),
        ],

        // Progress bar + "1 / 5" counter
        Row(
          children: [
            Expanded(
              child: AppProgressBar(progress: (_step + 1) / _totalSteps, trackColor: AppColors.border),
            ),
            const SizedBox(width: 12),
            Text(
              '${_step + 1} / $_totalSteps',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Step dots: completed steps are orange, the current one is stretched into a long bar
        Row(
          children: [
            for (int i = 0; i < _totalSteps; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              if (i == _step) Expanded(child: _StepDot(active: true)) else SizedBox(width: 16, child: _StepDot(active: i < _step)),
            ],
          ],
        ),
      ],
    );
  }

  // Small orange uppercase label used above the titles (same style as the Home header)
  TextStyle get _eyebrowStyle => AppTextStyles.body.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.accent,
        letterSpacing: 1.5,
      );

  // Returns the questions of the current step
  Widget _buildStep() {
    switch (_step) {
      // Step 1: name + favorite cuisines
      case 0:
        return _StepCard(
          icon: '👤',
          title: 'What should we call you?',
          subtitle: 'Just your first name is fine',
          children: [
            _SurveyTextField(
              controller: _nameController,
              hint: 'Your name...',
              onChanged: (v) => setState(() => _answers = _answers.copyWith(name: v)),
            ),
            const SizedBox(height: 20),
            _QuestionLabel('What cuisines do you love?'),
            _MultiSelect(
              options: _cuisines,
              selected: _answers.cuisines,
              activeColor: AppColors.accent,
              onToggle: (v) => setState(() => _answers = _answers.copyWith(cuisines: _toggle(_answers.cuisines, v))),
            ),
          ],
        );

      // Step 2: dietary restrictions
      case 1:
        return _StepCard(
          icon: '🌿',
          title: 'Any dietary restrictions?',
          subtitle: "We'll filter out what doesn't work for you",
          children: [
            _MultiSelect(
              options: _dietary,
              selected: _answers.dietaryRestrictions,
              activeColor: AppColors.green,
              onToggle: (v) => setState(() => _answers =
                  _answers.copyWith(dietaryRestrictions: _toggle(_answers.dietaryRestrictions, v))),
            ),
          ],
        );

      // Step 3: meal times + how often the user eats on campus
      case 2:
        return _StepCard(
          icon: '🕐',
          title: 'When do you eat on campus?',
          subtitle: 'Select your typical meal times',
          children: [
            _MultiSelect(
              options: _mealTimes,
              selected: _answers.mealTimes,
              activeColor: AppColors.amber,
              activeTextColor: AppColors.dark, // Dark text because white is hard to read on amber
              onToggle: (v) => setState(() => _answers = _answers.copyWith(mealTimes: _toggle(_answers.mealTimes, v))),
            ),
            const SizedBox(height: 20),
            _QuestionLabel('How often?'),
            // 2-column grid of single-choice buttons (only one frequency can be selected)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true, // Takes only the height it needs (it is inside a scroll view)
              physics: const NeverScrollableScrollPhysics(), // The outer scroll view handles scrolling
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.4,
              children: _frequencies.map((opt) {
                final selected = _answers.mealFrequency == opt;
                return GestureDetector(
                  onTap: () => setState(() => _answers = _answers.copyWith(mealFrequency: opt)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.dark : AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? AppColors.dark : AppColors.border),
                    ),
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.dark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );

      // Step 4: budget per meal (single choice)
      case 3:
        return _StepCard(
          icon: '💰',
          title: "What's your typical meal budget?",
          subtitle: 'Per meal, in Colombian pesos',
          children: [
            for (final b in _budgets)
              _BudgetOption(
                label: b.label,
                sub: b.sub,
                emoji: b.emoji,
                selected: _answers.budget == b.label,
                onTap: () => setState(() => _answers = _answers.copyWith(budget: b.label)),
              ),
          ],
        );

      // Step 5: top priorities (max 3) + foods to avoid
      default:
        return _StepCard(
          icon: '⭐',
          title: 'What matters most?',
          subtitle: 'Pick up to 3 priorities when choosing where to eat',
          children: [
            _MultiSelect(
              options: _priorities,
              selected: _answers.priorities,
              activeColor: AppColors.accent,
              onToggle: _togglePriority,
              // Warning shown once the limit is reached
              maxLabel: _answers.priorities.length >= _maxPriorities ? 'Max 3 selected' : null,
            ),
            const SizedBox(height: 20),
            _QuestionLabel('Foods you want to avoid?'),
            _SurveyTextField(
              controller: _dislikedController,
              hint: 'e.g. spicy food, seafood, mushrooms...',
              maxLines: 3,
              onChanged: (v) => setState(() => _answers = _answers.copyWith(dislikedFoods: v)),
            ),
          ],
        );
    }
  }

  // Confirmation screen shown for a moment after saving
  Widget _buildDone() {
    final name = userProfile.value.name;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Orange circle with a check mark
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: const Icon(Icons.check_rounded, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                // "¡Listo, Juan!" if the user wrote a name, "¡Listo!" otherwise
                name.isNotEmpty ? '¡Listo, $name!' : '¡Listo!',
                textAlign: TextAlign.center,
                style: AppTextStyles.headline.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 8),
              Text(
                'Your profile is set up. Discovering the best campus spots for you…',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable widget: one of the step dots under the progress bar
class _StepDot extends StatelessWidget {
  final bool active;

  const _StepDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 4,
      decoration: BoxDecoration(
        color: active ? AppColors.accent : AppColors.border,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

// Reusable widget: header of each step (emoji in a white box + title + subtitle) with the questions below
class _StepCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _StepCard({required this.icon, required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: AppColors.dark.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Text(icon, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.headline.copyWith(fontSize: 17, height: 1.2)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.body.copyWith(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

// Reusable widget: bold label above a secondary question ("What cuisines do you love?", "How often?", ...)
class _QuestionLabel extends StatelessWidget {
  final String text;

  const _QuestionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: AppTextStyles.cardTitle.copyWith(fontSize: 13)),
    );
  }
}

// Reusable widget: white text field with an orange border when focused (name and foods to avoid)
class _SurveyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _SurveyTextField({required this.controller, required this.hint, required this.onChanged, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    // Same rounded shape for both states; only the border color changes
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      textCapitalization: maxLines == 1 ? TextCapitalization.words : TextCapitalization.sentences,
      style: AppTextStyles.body.copyWith(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.mutedLight, fontSize: 14),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.accent),
      ),
    );
  }
}

// Reusable widget: group of toggle chips where several options can be selected at once
class _MultiSelect extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final Color activeColor;      // Background of the selected chips (orange, green or amber depending on the question)
  final Color activeTextColor;  // Text color of the selected chips
  final String? maxLabel;       // Optional warning shown above the chips (e.g. "Max 3 selected")

  const _MultiSelect({
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.activeColor,
    this.activeTextColor = Colors.white,
    this.maxLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (maxLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  maxLabel!,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),
                ),
              ],
            ),
          ),
        Wrap(
          // Wrap lets the chips flow to a new line automatically if there are many
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return GestureDetector(
              onTap: () => onToggle(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? activeColor : AppColors.border),
                ),
                child: Text(
                  // Selected chips show a check mark before the text
                  isSelected ? '✓  $opt' : opt,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? activeTextColor : AppColors.dark,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// Reusable widget: one large budget option (emoji + label + description, turns orange when selected)
class _BudgetOption extends StatelessWidget {
  final String label;
  final String sub;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _BudgetOption({
    required this.label,
    required this.sub,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.cardTitle.copyWith(
                      fontSize: 13,
                      color: selected ? Colors.white : AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.white.withOpacity(0.8) : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            // Small check circle on the right, only on the selected option
            if (selected)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
