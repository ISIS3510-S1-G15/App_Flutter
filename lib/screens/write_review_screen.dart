import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/restaurant.dart';
import '../models/review.dart';
import '../models/review_draft.dart';
import '../services/auth_service.dart';
import '../services/review_draft_store.dart';
import '../services/review_service.dart';
import '../widgets/offline_banner.dart';
import '../widgets/back_header.dart';
import '../widgets/multi_select.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/stars.dart';
import '../widgets/success_check.dart';
import 'my_reviews_screen.dart';

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

// WidgetsBindingObserver: to save the draft at once when the app goes to the background (slides 13)
class _WriteReviewScreenState extends State<WriteReviewScreen> with WidgetsBindingObserver {
  ReviewRatings _ratings = const ReviewRatings(); // All categories start at 0 (not rated)
  List<String> _dietary = [];                     // Dietary options the user selected
  final _commentController = TextEditingController();
  bool _submitted = false;                         // true after the review was sent OR queued (shows "¡Gracias!")
  bool _sending = false;                           // true while waiting for the backend (avoids double submits)
  bool _queued = false;                            // true = saved on the phone, posted when back online

  // Draft (local storage, Hive typed box): the answers survive leaving the screen or closing the app
  bool _draftLoaded = false;
  bool _draftRestored = false; // shows "Draft restored from device" + Discard
  Timer? _draftTimer;          // debounce: one disk write 400 ms after the LAST change, not one per letter

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDraft();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // no observer alive after closing the screen
    if (_draftTimer?.isActive == true) {
      _draftTimer!.cancel();
      _saveDraftNow();
    }
    _commentController.dispose(); // Frees the memory of the text controller
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _draftTimer?.cancel();
      _saveDraftNow();
    }
  }

  Future<void> _loadDraft() async {
    final draft = await ReviewDraftStore.load(widget.restaurant.id); // null if none or another account's
    if (!mounted) return;
    if (draft != null) {
      setState(() {
        _ratings = draft.ratings;
        _dietary = [...draft.dietaryOptions];
        _commentController.text = draft.comment;
        _draftRestored = true;
      });
    }
    _draftLoaded = true;
  }

  void _scheduleDraftSave() {
    if (!_draftLoaded || _submitted) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _saveDraftNow);
  }

  void _saveDraftNow() {
    final user = AuthService.currentUser.value;
    if (!_draftLoaded || _submitted || user == null) return;
    ReviewDraftStore.save(ReviewDraft(
      userId: user.id,
      restaurantId: widget.restaurant.id,
      ratings: _ratings,
      dietaryOptions: _dietary,
      comment: _commentController.text, // as typed, so it comes back exactly the same
      savedAt: DateTime.now(),
    ));
  }

  // "Discard": empty form, no banner, and the stored draft is gone (it will not come back)
  void _discardDraft() {
    _draftTimer?.cancel();
    setState(() {
      _ratings = const ReviewRatings();
      _dietary = [];
      _draftRestored = false;
    });
    _commentController.clear();
    ReviewDraftStore.delete(widget.restaurant.id);
  }

  // The review can only be submitted when the 4 categories have at least 1 star
  bool get _allRated => _ratingCategories.every((c) => _ratings.byKey(c.key) > 0);

  void _toggleDiet(String d) {
    // Adds the option if it isn't selected, removes it if it already is
    setState(() => _dietary = _dietary.contains(d) ? _dietary.where((x) => x != d).toList() : [..._dietary, d]);
    _scheduleDraftSave();
  }

  Future<void> _submit() async {
    if (!_allRated || _sending) return;
    _draftTimer?.cancel(); // the answers are about to be sent: no draft write should land after this
    FocusScope.of(context).unfocus(); // Closes the keyboard if the comment field was open
    setState(() => _sending = true);

    try {
      final outcome = await ReviewService.submit(
        restaurantId: widget.restaurant.id,
        ratings: _ratings,
        dietaryOptions: _dietary,
        comment: _commentController.text.trim(),
      );
      await ReviewDraftStore.delete(widget.restaurant.id);
      if (!mounted) return; // the user left the screen while the request was running
      final queued = outcome == ReviewSubmitOutcome.queued;
      if (queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You're offline. Your review will be posted when you reconnect.")),
        );
      }
      setState(() {
        _queued = queued;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send your review. Check your connection and try again.')),
      );
    }
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
                  if (_draftRestored) ...[
                    _DraftRestoredBanner(onDiscard: _discardDraft),
                    const SizedBox(height: 20),
                  ],

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
                          onChanged: (v) {
                            setState(() => _ratings = _ratings.copyWithKey(c.key, v));
                            _scheduleDraftSave();
                          },
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
                        // The controller already keeps the text; this only schedules the (debounced) draft save
                        onChanged: (_) => _scheduleDraftSave(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Submit: disabled (grey) only until the 4 categories are rated, with or without internet.
            // Offline the write is queued on the phone (Hive outbox) and posted by itself on reconnect,
            // so the user never has to come back later to send it (Sprint 3 correction, it used to be network only)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  const OfflineBanner(
                    margin: EdgeInsets.only(bottom: 8),
                    message:
                        "You're offline. You can still submit: your review will be saved on this phone and posted when you're back online.",
                  ),
                  if (!_allRated)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Please rate all 4 categories to submit',
                        style: TextStyle(fontSize: 11, color: AppColors.mutedLight),
                      ),
                    ),
                  AppPrimaryButton(
                    label: _sending ? 'Sending...' : 'Submit Review',
                    // disabled while sending: no duplicates
                    onTap: _allRated && !_sending ? _submit : null,
                  ),
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
                      TextSpan(
                        text: _queued
                            ? " is saved and will be posted when you're back online."
                            : ' has been submitted.',
                      ),
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
                const SizedBox(height: 12),

                // Secondary action: see the review just written among all of the user's reviews (a queued one shows
                // there as "Pending sync"). pushReplacement so "back" from My Reviews returns to the restaurant,
                // not to this thanks screen
                InkWell(
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MyReviewsScreen()),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 48,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.rate_review_outlined, size: 16, color: AppColors.dark),
                        const SizedBox(width: 8),
                        Text(
                          'Go to My Reviews',
                          style: AppTextStyles.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DraftRestoredBanner extends StatelessWidget {
  final VoidCallback onDiscard;

  const _DraftRestoredBanner({required this.onDiscard});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Draft restored from device',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          GestureDetector(
            onTap: onDiscard,
            child: const Text(
              'Discard',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.dark),
            ),
          ),
        ],
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
