import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_try/model/restaurant_model.dart';
import 'package:map_try/pages/owner_logIn/vendor_create_resto_acc.dart';
import 'package:map_try/pages/resto_detail_screen.dart';
import 'package:map_try/services/restaurant_service.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:map_try/widgets/search_modal.dart';

import '../main.dart';

class AppColors {
  // Gradient stops
  static const Color primary = Color(0xFFD74100); // D74100
  static const Color secondary = Color(0xFFFD6500); // FD6500
  static const Color gradientSoft = Color(0xFFFFCC96); // FFCC96

  // Buttons / CTAs
  static const Color button = Color(0xFFFF8E2E); // FF8E2E

  // System colors
  static const Color sysAccent = Color(0xFFFFA95D); // FFA95D
  static const Color sysBg = Color(
    0xFFFFCC96,
  ); // FFCC96 (also used in gradients)
}

/// Responsive breakpoints
class ResponsiveBreakpoints {
  static const double mobile = 768;
  static const double tablet = 1024;
  static const double desktop = 1200;
}

/// Helper to determine device type
enum DeviceType { mobile, tablet, desktop }

DeviceType getDeviceType(double width) {
  if (width < ResponsiveBreakpoints.mobile) return DeviceType.mobile;
  if (width < ResponsiveBreakpoints.desktop) return DeviceType.tablet;
  return DeviceType.desktop;
}

Widget categoryChip(String label, [bool isSelected = false]) {
  return Padding(
    padding: const EdgeInsets.only(left: 10),
    child: Chip(
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black54,
        fontWeight: FontWeight.w600,
      ),
      avatar:
          isSelected ? const Icon(Icons.fastfood, color: Colors.white) : null,
      backgroundColor: isSelected ? AppColors.button : AppColors.sysBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

// Desktop Header
class DesktopSidebar extends StatefulWidget {
  final String selectedNav;
  final ValueChanged<String> onNavSelected;
  final ValueNotifier<LatLng?> destinationNotifier; // pass this to search

  const DesktopSidebar({
    Key? key,
    required this.selectedNav,
    required this.onNavSelected,
    required this.destinationNotifier, // new
  }) : super(key: key);

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Logo
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 40),
          _buildNavItem(Icons.home_rounded, 'home', 'Home'),
          const SizedBox(height: 30),
          _buildNavItem(Icons.explore_rounded, 'explore', 'Explore'),
          const SizedBox(height: 30),
          _buildNavItem(Icons.settings_rounded, 'settings', 'Settings'),
          const SizedBox(height: 30),
          _buildNavItem(Icons.search_rounded, 'search', 'Search'),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String value, String tooltip) {
    final isSelected = widget.selectedNav == value;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          widget.onNavSelected(value);

          if (value == 'home') {
            bottomNavIndexNotifier.value = 0;
          } else if (value == 'explore') {
            bottomNavIndexNotifier.value = 1;
          } else if (value == 'settings') {
            bottomNavIndexNotifier.value = 3;
          } else if (value == 'search') {
            // ✅ Show SearchModal
            showDialog(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(16),
                child: SearchModal(destinationNotifier: widget.destinationNotifier),
              ),
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.white.withAlpha(70),
            size: 24,
          ),
        ),
      ),
    );
  }
}


Widget buildDesktopRestaurantCard({
  required Restaurant restaurant,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Restaurant Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
              image:
                  restaurant.headerImageUrl.isNotEmpty
                      ? DecorationImage(
                        image: NetworkImage(restaurant.headerImageUrl),
                        fit: BoxFit.cover,
                      )
                      : null,
            ),
            child:
                restaurant.headerImageUrl.isEmpty
                    ? Icon(Icons.restaurant, color: Colors.grey[400], size: 40)
                    : null,
          ),
          const SizedBox(width: 16),
          // Restaurant Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  restaurant.address ?? 'No address provided',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.button,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.star, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            '4.5',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
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

/// Desktop Category Pills
class DesktopCategoryPills extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const DesktopCategoryPills({
    Key? key,
    required this.selectedCategory,
    required this.onCategorySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final categories = ["All", "Meals", "Drinks", "Fast Food", "Snacks"];

    final hiddenCategories = [
      "Vegan",
      "Desserts",
      "Seafood",
      "Breakfast",
      "Buffet",
      "Street Food",
      "Healthy",
      "International",
      "Local",
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        // main category chips
        for (final category in categories)
          GestureDetector(
            onTap: () => onCategorySelected(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: selectedCategory == category
                    ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                )
                    : null,
                color: selectedCategory == category ? null : AppColors.sysBg,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: selectedCategory == category
                      ? Colors.white
                      : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

        // 🟠 "More" button
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text("More Categories"),
                  content: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: hiddenCategories.map((label) {
                        final bool isSelected = selectedCategory == label;
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          selectedColor: AppColors.button,
                          onSelected: (_) {
                            onCategorySelected(label);
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                  ],
                );
              },
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.sysBg,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: AppColors.sysAccent, width: 1),
            ),
            child: const Text(
              "More",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}






Widget sectionHeader(String title, {bool isDesktop = false}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: isDesktop ? 24 : 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      Container(
        margin: const EdgeInsets.only(right: 8),
        child: TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            backgroundColor: AppColors.button,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 16 : 12,
              vertical: isDesktop ? 6 : 3,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            "← Swipe",
            style: TextStyle(fontSize: isDesktop ? 14 : 12),
          ),
        ),
      ),
    ],
  );
}

/// Responsive resto card
Widget restoCard({
  required String headerImageUrl,
  required String name,
  required String address,
  bool isDesktop = false,
}) {
  final bool hasImage = headerImageUrl.isNotEmpty;
  final double cardWidth = isDesktop ? 280 : 180;
  final double cardHeight = isDesktop ? 320 : 280;

  return Container(
    width: cardWidth,
    height: cardHeight,
    margin: const EdgeInsets.only(right: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: hasImage ? null : Colors.grey[300],
      image:
          hasImage
              ? DecorationImage(
                image: NetworkImage(headerImageUrl),
                fit: BoxFit.cover,
              )
              : null,
      boxShadow: [
        BoxShadow(
          color: AppColors.sysAccent.withAlpha(30),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Stack(
      children: [
        // Gradient overlay to improve text contrast
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withAlpha(25), Colors.black.withAlpha(128)],
            ),
          ),
        ),

        // Rating badge
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.button,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withAlpha(40),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star,
                  size: isDesktop ? 14 : 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 2),
                Text(
                  "0",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDesktop ? 14 : 12,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Favorite Icon
        Positioned(
          top: 8,
          right: 8,
          child: Icon(
            Icons.favorite_border,
            color: Colors.white,
            size: isDesktop ? 26 : 24,
          ),
        ),

        // Name and Address
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  border: Border.all(
                    color: Colors.white.withAlpha(50),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 22 : 19,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: isDesktop ? 15 : 13.5,
                      ),
                      maxLines: isDesktop ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Desktop Grid View for restaurants
Widget buildDesktopGrid(
  List<Restaurant> restaurants,
  ValueNotifier<LatLng?> destinationNotifier,
) {
  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.85,
    ),
    itemCount: restaurants.length,
    itemBuilder: (context, index) {
      final resto = restaurants[index];
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => RestoDetailScreen(
                    restoId: resto.id,
                    destinationNotifier: destinationNotifier,
                  ),
            ),
          );
        },
        child: restoCard(
          headerImageUrl: resto.headerImageUrl,
          name: resto.name,
          address: resto.address ?? '',
          isDesktop: true,
        ),
      );
    },
  );
}

/// Desktop Category Chips Header
class DesktopCategoryChipsHeader extends SliverPersistentHeaderDelegate {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  DesktopCategoryChipsHeader({
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: Container(
        height: maxExtent,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCategoryChip("All"),
            _buildCategoryChip("Meals"),
            _buildCategoryChip("Drinks"),
            _buildCategoryChip("Fast Food"),
            _buildCategoryChip("Snacks"),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    final bool isSelected = selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: TextButton(
        onPressed: () => onCategorySelected(label),
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? AppColors.button : AppColors.sysBg,
          foregroundColor: isSelected ? Colors.white : Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(
              color: isSelected ? AppColors.button : AppColors.sysAccent,
              width: 1,
            ),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 80;

  @override
  double get minExtent => 80;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

/// Mobile Category Chips Header (unchanged)
class CategoryChipsHeader extends SliverPersistentHeaderDelegate {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  CategoryChipsHeader({
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
      ) {
    final screenWidth = MediaQuery.of(context).size.width;

    // ✅ Main categories always visible
    final mainCategories = ["All", "Meals", "Drinks", "Fast Food", "Snacks"];

    // ✅ Hidden categories for the popup
    final hiddenCategories = [
      "Vegan",
      "Desserts",
      "Seafood",
      "Breakfast",
      "Buffet",
      "Street Food",
      "Healthy",
      "International",
      "Local",
    ];

    return Container(
      color: Colors.white,
      child: SizedBox(
        height: maxExtent,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: screenWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🟢 Visible category chips
                for (final category in mainCategories)
                  _buildCategoryChip(context, category),

                // 🟠 “More” button chip
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: () {
                      // 🧩 Bottom popup for more categories
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        builder: (context) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "More Categories",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: hiddenCategories.map((label) {
                                    final bool isSelected =
                                        selectedCategory == label;
                                    return ChoiceChip(
                                      label: Text(label),
                                      selected: isSelected,
                                      selectedColor: AppColors.button,
                                      onSelected: (_) {
                                        onCategorySelected(label);
                                        Navigator.pop(context);
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.sysBg,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(
                          color: AppColors.sysAccent,
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Text(
                      "More",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
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

  // 🧩 Updated helper to handle context (needed for bottom sheet)
  Widget _buildCategoryChip(BuildContext context, String label) {
    final bool isSelected = selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: () => onCategorySelected(label),
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? AppColors.button : AppColors.sysBg,
          foregroundColor: isSelected ? Colors.white : Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(
              color: isSelected ? AppColors.button : AppColors.sysAccent,
              width: 1,
            ),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 60;

  @override
  double get minExtent => 60;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}


class HomePage extends StatefulWidget {
  final ValueNotifier<LatLng?> destinationNotifier;

  const HomePage({super.key, required this.destinationNotifier});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _hotDealsPageController = PageController(
    viewportFraction: 1,
  );
  final PageController _mostBoughtPageController = PageController(
    viewportFraction: 1,
  );
  final TextEditingController _searchController = TextEditingController();

  List<Restaurant> _restaurants = [];
  bool _isLoading = true;
  String _selectedCategory = "All";
  String _searchQuery = "";
  String _selectedNav = "home";

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      final data = await RestaurantService.fetchRestaurants();
      if (!mounted) return;
      setState(() {
        _restaurants = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load restaurants. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _hotDealsPageController.dispose();
    _mostBoughtPageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_restaurants.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No restaurants available.")),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType = getDeviceType(constraints.maxWidth);
        final isDesktop = deviceType == DeviceType.desktop;

        if (isDesktop) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left Sidebar
        DesktopSidebar(
        selectedNav: 'home',
        onNavSelected: (value) {
          // handle nav selection
        },
        destinationNotifier: destinationNotifier, // ✅ pass this
        ),

          // Main Content Area
          Expanded(
            child: Row(
              children: [
                // Left Content Panel
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MapaKaon',
                              style: GoogleFonts.poppins(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              'Hungry? We\'ll lead the way',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // Search Section
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(50),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(
                                () => _searchQuery = value.toLowerCase(),
                              );
                            },
                            decoration: InputDecoration(
                              hintText: 'What would you like to eat?',
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 16,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey[500],
                                size: 20,
                              ),
                              suffixIcon:
                                  _searchQuery.isNotEmpty
                                      ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          setState(() {
                                            _searchController.clear();
                                            _searchQuery = "";
                                          });
                                        },
                                      )
                                      : null,
                              filled: true,
                              fillColor: const Color(0xFFFAFAFA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: const BorderSide(
                                  color: AppColors.secondary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Category Pills
                        DesktopCategoryPills(
                          selectedCategory: _selectedCategory,
                          onCategorySelected: (category) {
                            setState(() => _selectedCategory = category);
                          },
                        ),
                        const SizedBox(height: 40),

                        // Section Title
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Search Results'
                              : (_selectedCategory == 'All'
                                  ? 'Hot Deals'
                                  : _selectedCategory),
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Restaurant List
                        Expanded(child: _buildRestaurantList()),
                      ],
                    ),
                  ),
                ),
                // Right Food Image Panel
                Container(
                  width: 400,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('Assets/route_pics/imageiloilo.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withAlpha(10),
                          Colors.transparent,
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
    );
  }

  Widget _buildRestaurantList() {
    final filteredRestaurants =
        _restaurants.where((resto) {
          if (_searchQuery.isNotEmpty) {
            return resto.menu.any((item) {
              final menuName = (item['name'] as String).toLowerCase();
              final category = (item['category'] as String).toLowerCase();
              return menuName.contains(_searchQuery) ||
                  category.contains(_searchQuery);
            });
          } else {
            return _selectedCategory == "All"
                ? true
                : resto.menu.any(
                  (item) =>
                      (item['category'] as String).toLowerCase() ==
                      _selectedCategory.toLowerCase(),
                );
          }
        }).toList();

    if (filteredRestaurants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching for something else'
                  : 'No restaurants in this category',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredRestaurants.length,
      itemBuilder: (context, index) {
        final restaurant = filteredRestaurants[index];
        return buildDesktopRestaurantCard(
          restaurant: restaurant,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => RestoDetailScreen(
                      restoId: restaurant.id,
                      destinationNotifier: widget.destinationNotifier,
                    ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            collapsedHeight: 120,
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final percent = ((constraints.maxHeight - kToolbarHeight) /
                        (260 - kToolbarHeight))
                    .clamp(0.0, 1.0);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background image
                    Opacity(
                      opacity: 0.6,
                      child: Container(
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(
                              'Assets/route_pics/imageiloilo.png',
                            ),
                            fit: BoxFit.cover,
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(34),
                            bottomRight: Radius.circular(34),
                          ),
                        ),
                      ),
                    ),
                    // Gradient overlay (brand colors)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(34),
                          bottomRight: Radius.circular(34),
                        ),
                        gradient: LinearGradient(
                          colors:
                              const [
                                Colors.transparent,
                                AppColors.gradientSoft,
                                AppColors.secondary,
                              ].map((c) => c.withAlpha(80)).toList(),
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // Top Row (registration, icons)
                    Positioned(
                      top: 10 + 10 * percent,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Create Resto (CTA style icon chip)
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Colors.deepOrange,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.restaurant,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () async {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreateRestoAccPage(),
                                  ),
                                );
                              },
                              tooltip: 'Register your Resto',
                            ),
                          ),
                          Row(
                            children: [
                              badges.Badge(
                                position: badges.BadgePosition.topEnd(
                                  top: -1,
                                  end: -1,
                                ),
                                badgeStyle: const badges.BadgeStyle(
                                  padding: EdgeInsets.all(0),
                                  badgeColor: AppColors.button,
                                ),
                                badgeContent: const Text(
                                  '0',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.notifications_none,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.sysAccent.withAlpha(40),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Location, Title, Subtitle (only visible when header is expanded)
                    if (percent > 0.5)
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 10 + 40 * percent,
                        child: Opacity(
                          opacity: percent,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.location_on,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Iloilo City, Philippines',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 15 * percent),

                              // Brand title chip with gradient
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 11 * percent,
                                  vertical: 4 * percent,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.secondary,
                                      AppColors.gradientSoft,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    8 * percent,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.secondary.withAlpha(50),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'MapaKaon',
                                  style: GoogleFonts.poppins(
                                    fontSize: 31 * percent,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              SizedBox(height: 7 * percent),

                              if (percent > 0.5)
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            AppColors.primary,
                                            AppColors.secondary,
                                            AppColors.gradientSoft,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withAlpha(
                                              30,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text.rich(
                                        TextSpan(
                                          text: 'Hungry? We\'ll lead the ',
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                          children: [
                                            WidgetSpan(
                                              alignment:
                                                  PlaceholderAlignment.baseline,
                                              baseline: TextBaseline.alphabetic,
                                              child: Stack(
                                                children: [
                                                  // Outline
                                                  Text(
                                                    'way',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      foreground:
                                                          Paint()
                                                            ..style =
                                                                PaintingStyle
                                                                    .stroke
                                                            ..strokeWidth = 2
                                                            ..color =
                                                                Colors.black,
                                                    ),
                                                  ),
                                                  // Fill
                                                  Text(
                                                    'way',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                ),
                              SizedBox(height: 16 * percent),
                            ],
                          ),
                        ),
                      ),

                    // Search Bar (always visible)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      height: 50,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: AppColors.sysAccent.withAlpha(70),
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sysAccent.withAlpha(30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: "Let's find food you want...",
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon:
                                _searchQuery.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          _searchQuery = "";
                                        });
                                      },
                                    )
                                    : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Collapsed Title "MapaKaon" fading in at the very top
                    Positioned(
                      top: 15,
                      left: 0,
                      right: 0,
                      child: Opacity(
                        opacity: percent < 0.5 ? 1 : 0,
                        child: Center(
                          child: Stack(
                            children: [
                              // Stroke (Outline)
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Mapa',
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                        foreground:
                                            Paint()
                                              ..style = PaintingStyle.stroke
                                              ..strokeWidth = 2
                                              ..color = Colors.black,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Kaon',
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                        foreground:
                                            Paint()
                                              ..style = PaintingStyle.stroke
                                              ..strokeWidth = 2
                                              ..color = Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Fill
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Mapa',
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Kaon',
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                        color: AppColors.button,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          SliverPersistentHeader(
            pinned: true,
            delegate: CategoryChipsHeader(
              selectedCategory: _selectedCategory,
              onCategorySelected: (category) {
                setState(() => _selectedCategory = category);
              },
            ),
          ),

          // Mobile Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 1, bottom: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

                  // Hot Deals Carousel
                  sectionHeader(
                    _searchQuery.isNotEmpty
                        ? "${_searchQuery[0].toUpperCase()}${_searchQuery.substring(1)} Results"
                        : (_selectedCategory == "All"
                            ? "Hot Deals"
                            : "$_selectedCategory"),
                  ),

                  const SizedBox(height: 8),
                  SizedBox(
                    height: 280,
                    child: Builder(
                      builder: (context) {
                        final filteredRestaurants =
                            _restaurants.where((resto) {
                              if (_searchQuery.isNotEmpty) {
                                return resto.menu.any((item) {
                                  final menuName =
                                      (item['name'] as String).toLowerCase();
                                  final category =
                                      (item['category'] as String)
                                          .toLowerCase();

                                  return menuName.contains(_searchQuery) ||
                                      category.contains(_searchQuery);
                                });
                              } else {
                                return _selectedCategory == "All"
                                    ? true
                                    : resto.menu.any(
                                      (item) =>
                                          (item['category'] as String)
                                              .toLowerCase() ==
                                          _selectedCategory.toLowerCase(),
                                    );
                              }
                            }).toList();

                        if (filteredRestaurants.isEmpty) {
                          return Center(
                            child: Text(
                              "No results found for '${_searchQuery.isNotEmpty ? _searchQuery : _selectedCategory}'",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            Expanded(
                              child: ScrollConfiguration(
                                behavior: const MaterialScrollBehavior()
                                    .copyWith(
                                      dragDevices: {
                                        PointerDeviceKind.touch,
                                        PointerDeviceKind.mouse,
                                      },
                                    ),
                                child: PageView.builder(
                                  controller: _hotDealsPageController,
                                  itemCount: filteredRestaurants.length,
                                  padEnds: false,
                                  physics: const BouncingScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    final resto = filteredRestaurants[index];
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => RestoDetailScreen(
                                                  restoId: resto.id,
                                                  destinationNotifier:
                                                      widget
                                                          .destinationNotifier,
                                                ),
                                          ),
                                        );
                                      },
                                      child: restoCard(
                                        headerImageUrl: resto.headerImageUrl,
                                        name: resto.name,
                                        address: resto.address ?? '',
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SmoothPageIndicator(
                              controller: _hotDealsPageController,
                              count: filteredRestaurants.length,
                              effect: const WormEffect(
                                activeDotColor: AppColors.button,
                                dotColor: Colors.grey,
                                dotHeight: 10,
                                dotWidth: 10,
                                spacing: 8,
                              ),
                              onDotClicked: (index) {
                                _hotDealsPageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Most Bought Carousel (placeholder for mobile)
                  sectionHeader("Most Bought"),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 280,
                    child: Column(
                      children: [
                        Expanded(
                          child: ScrollConfiguration(
                            behavior: const MaterialScrollBehavior().copyWith(
                              dragDevices: {
                                PointerDeviceKind.touch,
                                PointerDeviceKind.mouse,
                              },
                            ),
                            child: PageView(
                              controller: _mostBoughtPageController,
                              padEnds: false,
                              physics: const BouncingScrollPhysics(),
                              children: [
                                restoCard(
                                  headerImageUrl: '',
                                  name: '-------------',
                                  address: '-------------',
                                ),
                                restoCard(
                                  headerImageUrl: '',
                                  name: '-------------',
                                  address: '-------------',
                                ),
                                restoCard(
                                  headerImageUrl: '',
                                  name: '-------------',
                                  address: '-------------',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SmoothPageIndicator(
                          controller: _mostBoughtPageController,
                          count: 3,
                          effect: const WormEffect(
                            activeDotColor: AppColors.button,
                            dotColor: Colors.grey,
                            dotHeight: 10,
                            dotWidth: 10,
                            spacing: 8,
                          ),
                          onDotClicked: (index) {
                            _mostBoughtPageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
