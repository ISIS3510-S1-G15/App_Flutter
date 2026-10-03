import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/restaurant.dart';
import '../models/review.dart';
import '../data/reviews_data.dart';
import '../data/profile_data.dart';
import '../widgets/back_header.dart';
import '../widgets/multi_select.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/stars.dart';
import '../widgets/success_check.dart';

// Special diets the reviewer can say the restaurant accommodates
const _dietaryOptions = ['Vegan options', 'Vegetarian options', 'Gluten-free', 'Lactose-free', 'Nut-free', 'Halal', 'Kosher'];

// The 4 categories to rate: (key used in ReviewRatings, label shown on screen)
const _ratingCategories = [
  (key: 'taste', label: 'Taste & Food Quality'),
  (key: 'attention', label: 'Service & Attention'),
  (key: 'price', label: 'Value for Money'),
  (key: 'options', label: 'Dietary Options'),
];

// Word shown next to each category once it is rated (index = number of stars)
const _ratingWords = ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'];

const _maxCommentLength = 300;

class WriteReviewScreen extends StatefulWidget {
  // StatefulWidget because the screen remembers the stars, dietary options and comment while the user fills them in
  final Restaurant restaurant;

  const WriteReviewScreen({super.key, required this.restaurant});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  ReviewRatings _ratings = const ReviewRatings(); // All categories start at 0 (not rated)
  List<String> _dietary = [];                     // Dietary options the user selected
  final _commentController = TextEditingController();
  bool _submitted = false;                         // true after "Submit Review" (shows the "¡Gracias!" screen)

  @override
  void dispose() {
    _commentController.dispose(); // Frees the memory of the text controller
    super.dispose();
  }

  // The review can only be submitted when the 4 categories have at least 1 star
  bool get _allRated => _ratingCategories.every((c) => _ratings.byKey(c.key) > 0);

  void _toggleDiet(String d) {
    // Adds the option if it isn't selected, removes it if it already is
    setState(() => _dietary = _dietary.contains(d) ? _dietary.where((x) => x != d).toList() : [..._dietary, d]);
  }

  void _submit() {
    if (!_allRated) return;
    FocusScope.of(context).unfocus(); // Closes the keyboard if the comment field was open

    final authorName = userProfile.value.name; // Name the user wrote in the survey
    addReview(Review(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Unique enough id for local reviews
      restaurantId: widget.restaurant.id,
      author: authorName.isNotEmpty ? authorName : 'Anonymous',
      date: DateTime.now(),
      ratings: _ratings,
      dietaryOptions: _dietary,
      comment: _commentController.text.trim(),
    ));
    // addReview updates allReviews, so the reviews list redraws with this new review

    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildThanks();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header: back button + "WRITE A REVIEW" + restaurant name
            BackHeader(
              eyebrow: 'Write a Review',
              title: widget.restaurant.name,
              onBack: () => Navigator.of(context).pop(),
            ),

            // Form (scrolls if it doesn't fit, e.g. when the keyboard is open)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  // Star ratings: one row of stars per category
                  _FormCard(
                    title: 'Rate your experience',
                    children: [
                      for (final c in _ratingCategories) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(c.label, style: AppTextStyles.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                            // "Great", "Poor"... appears only once the category has been rated
                            if (_ratings.byKey(c.key) > 0)
                              Text(
                                _ratingWords[_ratings.byKey(c.key)],
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        StarRatingInput(
                          value: _ratings.byKey(c.key),
                          onChanged: (v) => setState(() => _ratings = _ratings.copyWithKey(c.key, v)),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Overall preview: average of the 4 categories, shown once all are rated
                      if (_allRated)
                        Container(
                          padding: const EdgeInsets.only(top: 16),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: AppColors.borderLight)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Overall rating',
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, size: 16, color: AppColors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    _ratings.overall.toStringAsFixed(1),
                                    style: AppTextStyles.headline.copyWith(fontSize: 18),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Dietary options: green toggle chips
                  _FormCard(
                    title: 'Available dietary options',
                    subtitle: 'Which special diets does this restaurant accommodate?',
                    children: [
                      AppMultiSelect(
                        options: _dietaryOptions,
                        selected: _dietary,
                        onToggle: _toggleDiet,
                        activeColor: AppColors.green,
                        inactiveColor: AppColors.background, // Cream chips inside the white card
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Final comments: optional text, max 300 characters (with a "0/300" counter)
                  _FormCard(
                    title: 'Final comments',
                    subtitle: 'Share your experience with other students',
                    children: [
                      AppTextField(
                        controller: _commentController,
                        hint: 'What did you enjoy? What could be better?',
                        maxLines: 4,
                        maxLength: _maxCommentLength,
                        fillColor: AppColors.background,
                        onChanged: (_) {}, // The controller already keeps the text; nothing else to update
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Submit: disabled (grey) until the 4 categories are rated
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  if (!_allRated)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Please rate all 4 categories to submit',
                        style: TextStyle(fontSize: 11, color: AppColors.mutedLight),
                      ),
                    ),
                  AppPrimaryButton(label: 'Submit Review', onTap: _allRated ? _submit : null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // "¡Gracias!" confirmation shown after submitting, with the overall rating the user gave
  Widget _buildThanks() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SuccessCheck(),
                const SizedBox(height: 20),
                Text('¡Gracias!', style: AppTextStyles.headline.copyWith(fontSize: 24)),
                const SizedBox(height: 8),
                // RichText to show the restaurant name in bold inside the sentence
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.muted, height: 1.5),
                    children: [
                      const TextSpan(text: 'Your review of '),
                      TextSpan(
                        text: widget.restaurant.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.dark),
                      ),
                      const TextSpan(text: ' has been submitted.'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // White box with the overall rating
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 24, color: AppColors.amber),
                      const SizedBox(width: 8),
                      Text(_ratings.overall.toStringAsFixed(1), style: AppTextStyles.headline.copyWith(fontSize: 28)),
                      const SizedBox(width: 8),
                      Text('your overall rating', style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppPrimaryButton(
                  label: 'Back to Restaurant',
                  color: AppColors.dark,
                  shadow: false,
                  // Closes this screen and returns to wherever it was opened from (restaurant detail or reviews list)
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Reusable widget: white rounded card with a title, optional subtitle and the form fields below
class _FormCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _FormCard({required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.headline.copyWith(fontSize: 14)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppTextStyles.body.copyWith(fontSize: 11, color: AppColors.muted)),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
