import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/map_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/profile_screen.dart';
import 'services/saved_service.dart';
import 'services/review_service.dart';
import 'services/occupancy_service.dart';
import 'services/profile_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  int _previousIndex = 0; // Tab that was open before the current one, so Profile's back button can return to it

  // Built as a getter (not a const list) because ProfileScreen needs a callback that references this State
  List<Widget> get _screens => [
        const HomeScreen(),
        const SearchScreen(),
        const MapScreen(),
        const SavedScreen(),
        // The tabs are not routes (there is nothing to pop), so Profile gets a callback that switches tabs instead
        ProfileScreen(onBack: () => _onItemTapped(_previousIndex)),
      ];

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // Tapping the tab that is already open changes nothing
    OccupancyService.loadAll(); // crowding changes minute by minute: one cheap request refreshes every badge
    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    SavedService.load(); // the user's saved restaurants, from the backend
    ProfileService.load(); // the user's survey answers, from the backend
    ReviewService.loadSummaries(); // rating and number of reviews of every restaurant
    OccupancyService.loadAll(); // crowding level of every restaurant (badges)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.dark,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.card.withOpacity(0.5),
        selectedLabelStyle: AppTextStyles.navLabel,
        unselectedLabelStyle: AppTextStyles.navLabel,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Discover'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Saved'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}