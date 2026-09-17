import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/restaurants_data.dart'; 
import '../models/restaurant.dart';     
import '../widgets/crowding_badge.dart'; 

// Fixed lists of sample data (not yet sourced from an actual database)
const _recentNames = ['Starbucks', 'Kai Sushi', 'Cosechas'];
const _popularTags = ['Vegan options', 'Halal', 'Open late', 'Quick pickup', 'Coffee'];

class SearchScreen extends StatefulWidget {
  // “StatefulWidget” because this screen does change as the user interacts with it (types in the search bar, taps a tag, etc.). It needs to remember that state
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
  // The logic and current state of this screen are stored in _SearchScreenState
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  // Controls the text the user enters in the search field (allows you to read, clear, or change)

  final FocusNode _focusNode = FocusNode();
  // Detects whether the search field has focus (the user is typing in it). Used to change the border color when the user taps the input field

  String _query = '';       // What the user has typed so far
  bool _focused = false;    // Whether the input is currently focused or not

  @override
  void initState() {
    // Runs ONLY once, when the screen is first created
    super.initState();
    _focusNode.addListener(() {
      // Every time the focus changes (the user taps or exits the input field)...
      setState(() => _focused = _focusNode.hasFocus);
      // ...updates “_focused” and tells Flutter to redraw the screen
    });
  }

  @override
  void dispose() {
    // Runs when the screen is destroyed (the user navigates to another screen)
    _controller.dispose(); // frees up the text controller's memory
    _focusNode.dispose();  // frees the memory of the focus node
    super.dispose();
  }

  List<Restaurant> get _results {
    // Calculates, in real time, which restaurants match what the user typed
    if (_query.trim().isEmpty) return [];
    // If nothing has been entered, there are no results to display (another view is displayed instead)

    final q = _query.toLowerCase();
    // Converts the search to lowercase so that “starbucks” matches "Starbucks"
    return restaurants.where((r) {
      // Filters the complete list of restaurants, keeping only those that match by name, category, location, or any of their tags
      return r.name.toLowerCase().contains(q) ||
          r.category.toLowerCase().contains(q) ||
          r.location.toLowerCase().contains(q) ||
          r.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  void _onSelect(Restaurant r) {
    // Called when the user taps a restaurant in the list
    // TODO: Navigator.push a DetailScreen(r)
  }

  @override
  Widget build(BuildContext context) {
    // This method redraws the ENTIRE screen. It runs every time something changes (e.g., the user types another character into the search bar)

    final results = _results; // The restaurants that match the current search
    final showEmpty = _query.trim().isNotEmpty && results.isEmpty;
    // True if the user entered something but there are no results (to display “no results”)

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // Prevents the content from appearing below the phone's status bar (time, battery, etc.)
        child: Column(
          children: [
            // ---------- HEADER: “Search” title + search box ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Search', style: AppTextStyles.headline.copyWith(fontSize: 24)),
                  const SizedBox(height: 16),

                  // Search input box (magnifying glass icon + text field + “x” button)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        // The border turns orange if the input field has focus
                        color: _focused ? AppColors.accent : AppColors.closed.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search,
                            size: 18,
                            color: _focused ? AppColors.accent : AppColors.closed),
                        const SizedBox(width: 10),
                        Expanded(
                          // The actual text field where the user types
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            onChanged: (v) => setState(() => _query = v),
                            // Every time the text changes, update “_query,” and Flutter will automatically recalculate the results
                            style: AppTextStyles.body.copyWith(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Restaurant name, cuisine, location...',
                              hintStyle: TextStyle(color: AppColors.closed, fontSize: 14),
                              border: InputBorder.none, 
                              isDense: true,
                            ),
                          ),
                        ),
                        // “x” button to clear the search — appears only if text has been entered
                        if (_query.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.closed.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, size: 12, color: AppColors.closed),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ---------- BODY: changes if there is an active search or not ----------
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  // Case 1: The user searched for something but there are no results
                  if (showEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          const Text('🍽', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('No results for "$_query"',
                              style: AppTextStyles.cardTitle.copyWith(fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('Try a different name or cuisine',
                              style: AppTextStyles.body.copyWith(
                                fontSize: 13,
                                color: AppColors.closed,
                              )),
                        ],
                      ),
                    ),

                  // Case 2: There are results that match the search
                  if (results.isNotEmpty) ...[
                                        // “...” (spread operator) inserts several individual widgets into the list, rather than placing them inside an extra container widget
                    Text(
                      '${results.length} result${results.length != 1 ? 's' : ''}',
                      // Shows "1 result" or "3 results" 
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.closed,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Draws one row (_SearchResultRow) for each restaurant found
                    ...results.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _SearchResultRow(
                            restaurant: r,
                            query: _query, // used to highlight matching text in yellow
                            onTap: () => _onSelect(r),
                          ),
                        )),
                  ],

                  // Case 3: The user hasn't typed anything yet, so recent searches, popular tags, and all restaurants are displayed
                  if (_query.isEmpty) ...[
                    // --- Recent Searches ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent Searches', style: AppTextStyles.cardTitle.copyWith(fontSize: 13)),
                        Text('Clear',
                            style: AppTextStyles.body.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._recentNames.map((name) {
                      // For each name in _recentNames, find the corresponding actual restaurant
                      final match = restaurants.where((r) => r.name == name);
                      final r = match.isNotEmpty ? match.first : null;
                      // If it can't find it (for example, the name isn't in the list), r is set to null

                      return InkWell(
                        onTap: r != null ? () => _onSelect(r) : null,
                        // Only allow the row to be edited if the restaurant was found
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.closed.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.search, size: 14, color: AppColors.closed),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(name, style: AppTextStyles.body.copyWith(fontSize: 14)),
                              ),
                              Icon(Icons.north_east, size: 14, color: AppColors.closed.withOpacity(0.6)),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // --- Browse by Tag ---
                    Text('Browse by Tag', style: AppTextStyles.cardTitle.copyWith(fontSize: 13)),
                    const SizedBox(height: 10),
                    Wrap(
                      // “Wrap” arranges the elements in rows and automatically moves to the next line when they no longer fit (like text that wraps to the next line)
                      spacing: 8,
                      runSpacing: 8,
                      children: _popularTags.map((tag) {
                        return GestureDetector(
                          onTap: () {
                            // When a tag is tapped, it displays it as if the user had typed it
                            _controller.text = tag;
                            setState(() => _query = tag);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.closed.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('#', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 2),
                                Text(tag, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // --- All Restaurants ---
                    Text('All Restaurants', style: AppTextStyles.cardTitle.copyWith(fontSize: 13)),
                    const SizedBox(height: 10),
                    ...restaurants.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SearchResultRow(
                            restaurant: r,
                            query: '', 
                            onTap: () => _onSelect(r),
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Widget: a single row of search results ----------
class _SearchResultRow extends StatelessWidget {
  // The “_” at the beginning of the name means that this class is “private”: it can only be used within this file, not from other files.

  final Restaurant restaurant;
  final String query; // Used to determine which part of the text to highlight
  final VoidCallback onTap; // What to do when the user taps this row

  const _SearchResultRow({
    required this.restaurant,
    required this.query,
    required this.onTap,
  });

  Widget _highlight(String text, TextStyle style) {
    // Highlights the part of the text that matches the search term in yellow (e.g., if you search for "sushi" it highlights 'Sushi' within "Yamato Sushi")
    if (query.isEmpty) return Text(text, style: style, overflow: TextOverflow.ellipsis);
    final idx = text.toLowerCase().indexOf(query.toLowerCase());
    if (idx == -1) return Text(text, style: style, overflow: TextOverflow.ellipsis);
    // If no match is found, display the text normally without highlighting it

    return RichText(
      // RichText allows you to display the same text in several different styles (normal text + highlighted text)
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, idx)),           // Text before the match
          TextSpan(
            text: text.substring(idx, idx + query.length), // The part that matches
            style: style.copyWith(
              backgroundColor: AppColors.accent.withOpacity(0.25), // soft yellow/orange background
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(idx + query.length)), // The text after the match
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = restaurant;

    return InkWell(
      onTap: onTap, // Makes the entire row tappable (with a “ripple” effect when tapped)
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.closed.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Photo of the restaurant (or a gray box if the image doesn't exist or fails to load)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
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

            // Información del restaurante: nombre, ubicación, rating, categoría, estado
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _highlight(r.name, AppTextStyles.cardTitle.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  _highlight(r.location, AppTextStyles.body.copyWith(fontSize: 11, color: AppColors.closed)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 10, color: AppColors.accent),
                      const SizedBox(width: 2),
                      Text('${r.rating}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Text('·', style: TextStyle(color: AppColors.closed)),
                      const SizedBox(width: 4),
                      Text(r.category, style: TextStyle(fontSize: 11, color: AppColors.closed)),
                      const SizedBox(width: 4),
                      Text('·', style: TextStyle(color: AppColors.closed)),
                      const SizedBox(width: 4),
                      Text(
                        r.isOpen ? 'Open' : 'Closed',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: r.isOpen ? AppColors.open : AppColors.closed,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const CrowdingBadge(reports: [], small: true),
                      // No actual reports yet, so nothing is displayed
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: AppColors.closed.withOpacity(0.6)),
            // “>” arrow indicating that the row is tappable / leads to another screen
          ],
        ),
      ),
    );
  }
}