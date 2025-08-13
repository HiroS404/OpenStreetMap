import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;

import 'package:google_fonts/google_fonts.dart';
import 'package:map_try/model/restaurant_model.dart';
import 'package:map_try/pages/owner_logIn/vendor_create_resto_acc.dart';
import 'package:map_try/services/restaurant_service.dart';

/// ---- Brand Color System ----
class AppColors {
  // Gradient stops
  static const Color primary = Color(0xFFD74100); // D74100
  static const Color secondary = Color(0xFFFD6500); // FD6500
  static const Color gradientSoft = Color(0xFFFFCC96); // FFCC96

  // Buttons / CTAs
  static const Color button = Color(0xFFFF8E2E); // FF8E2E

  // System colors
  static const Color sysAccent = Color(0xFFFFA95D); // FFA95D
  static const Color sysBg = Color(0xFFFFCC96); // FFCC96 (also used in gradients)
}

/// Category chip shared widget (unused by header but kept if you need it elsewhere)
Widget categoryChip(String label, [bool isSelected = false]) {
  return Padding(
    padding: const EdgeInsets.only(left: 10),
    child: Chip(
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black54,
        fontWeight: FontWeight.w600,
      ),
      avatar: isSelected ? const Icon(Icons.fastfood, color: Colors.white) : null,
      backgroundColor: isSelected ? AppColors.button : AppColors.sysBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

Widget sectionHeader(String title) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: const Text("See All"),
      ),
    ],
  );
}

/// Safe resto card (handles empty photoUrl)
Widget restoCard({
  required String photoUrl,
  required String name,
  required String address,
}) {
  final bool hasImage = photoUrl.isNotEmpty;
  return Container(
    width: 180,
    margin: const EdgeInsets.only(right: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: hasImage ? null : Colors.grey[300],
      image: hasImage
          ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
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
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(25),
                Colors.black.withAlpha(128),
              ],
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
            child: const Row(
              children: [
                Icon(Icons.star, size: 12, color: Colors.white),
                SizedBox(width: 2),
                Text("4.5", style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ),

        // Favorite Icon
        const Positioned(
          top: 8,
          right: 8,
          child: Icon(Icons.favorite_border, color: Colors.white),
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
                padding: const EdgeInsets.all(6),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                      maxLines: 1,
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

/// Blank placeholder card for non-"Meals" categories
Widget blankCard() {
  return Container(
    width: 180,
    margin: const EdgeInsets.only(right: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.gradientSoft,
          AppColors.sysAccent,
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.sysAccent.withAlpha(30),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
  );
}

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
                _buildCategoryChip("Nearby"),
                _buildCategoryChip("Meals"),
                _buildCategoryChip("Drinks"),
                _buildCategoryChip("Fast Food"),
                _buildCategoryChip("Snacks"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
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
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 60;

  @override
  double get minExtent => 60;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _hotDealsController = ScrollController();
  final ScrollController _mostBoughtController = ScrollController();
  List<Restaurant> _restaurants = [];
  bool _isLoading = true;

  Timer? _autoScrollTimer;
  bool _userInteracting = false;

  /// Default to a non-"Meals" category so cards appear ONLY when Meals is pressed
  String _selectedCategory = "Nearby";

  @override
  void initState() {
    super.initState();
    _startAutoScroll(_hotDealsController);
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

  void _startAutoScroll(ScrollController controller) {
    const duration = Duration(milliseconds: 100);
    const step = 1.0; // scroll step in pixels
    _autoScrollTimer = Timer.periodic(duration, (_) {
      if (!_userInteracting && controller.hasClients) {
        if (controller.offset < controller.position.maxScrollExtent) {
          controller.jumpTo(controller.offset + step);
        } else {
          controller.jumpTo(0); // restart
        }
      }
    });
  }

  void _onUserInteraction() {
    _userInteracting = true;
    _autoScrollTimer?.cancel();
    Future.delayed(const Duration(seconds: 3), () {
      _userInteracting = false;
      _startAutoScroll(_hotDealsController);
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _hotDealsController.dispose();
    _mostBoughtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_restaurants.isEmpty) return const Center(child: Text("No restaurants available."));

    return Scaffold(
      backgroundColor: Colors.white, // keep content surfaces crisp
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
                final percent = ((constraints.maxHeight - kToolbarHeight) / (260 - kToolbarHeight)).clamp(0.0, 1.0);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background image
                    Opacity(
                      opacity: 0.6,
                      child: Container(
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('Assets/route_pics/imageiloilo.png'),
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
                          colors: [
                            Colors.transparent,
                            AppColors.gradientSoft.withAlpha(60),
                            AppColors.secondary.withAlpha(60),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // Top Row (menu, icons)
                    Positioned(
                      top: 10 + 10 * percent,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Create Resto (CTA style icon chip)
                          Container(
                            decoration: const BoxDecoration(
                              color: AppColors.button,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.restaurant, color: Colors.white, size: 22),
                              onPressed: () async {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CreateRestoAccPage()),
                                );
                              },
                              tooltip: 'Register your Resto',
                            ),
                          ),

                          Row(
                            children: [
                              badges.Badge(
                                position: badges.BadgePosition.topEnd(top: -1, end: -1),
                                badgeStyle: const badges.BadgeStyle(
                                  padding: EdgeInsets.all(5),
                                  badgeColor: AppColors.button,
                                ),
                                badgeContent: const Text(
                                  '0',
                                  style: TextStyle(color: Colors.white, fontSize: 10),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.notifications_none, color: Colors.white),
                                  onPressed: () {},
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.sysAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.sysAccent.withAlpha(40),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.person_outline_rounded, color: Colors.white),
                                  onPressed: () {},
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
                                  Icon(Icons.location_on, color: AppColors.primary, size: 20),
                                  SizedBox(width: 6),
                                  Text(
                                    'Iloilo City, Philippines',
                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              SizedBox(height: 15 * percent),

                              // Brand title chip with gradient
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 11 * percent, vertical: 4 * percent),
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
                                  borderRadius: BorderRadius.circular(8 * percent),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                        borderRadius: BorderRadius.circular(30),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text.rich(
                                        TextSpan(
                                          text: 'Hungry? We’ll lead the ',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          children: [
                                            WidgetSpan(
                                              child: Stack(
                                                children: [
                                                  // Outline
                                                  Text(
                                                    'Way',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.w900,
                                                      foreground: Paint()
                                                        ..style = PaintingStyle.stroke
                                                        ..strokeWidth = 2
                                                        ..color = Colors.black,
                                                    ),
                                                  ),
                                                  // Fill
                                                  Text(
                                                    'Way',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.w900,
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
                                    const Text(
                                      'Mapanamkon nga pagkaon, makita mo dayon!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
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
                      bottom:12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.sysAccent.withAlpha(70)),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sysAccent.withAlpha(30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const TextField(
                          decoration: InputDecoration(
                            icon: Icon(Icons.search, color: AppColors.button),
                            hintText: "Let's find the food you like",
                            border: InputBorder.none,
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
                                        foreground: Paint()
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
                                        foreground: Paint()
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

          // Category chips with selection + callback
          SliverPersistentHeader(
            pinned: true,
            delegate: CategoryChipsHeader(
              selectedCategory: _selectedCategory,
              onCategorySelected: (category) {
                setState(() => _selectedCategory = category);
              },
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Hot Deals 🔥 Section
                  sectionHeader("Hot Deals 🔥"),
                  const SizedBox(height: 8),

                  // Shows real cards for Meals, blank placeholders otherwise
                  SizedBox(
                    height: 250,
                    child: Listener(
                      onPointerDown: (_) => _onUserInteraction(),
                      child: ListView.builder(
                        controller: _hotDealsController,
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedCategory == "Meals" ? _restaurants.length : 6,
                        itemBuilder: (context, index) {
                          if (_selectedCategory != "Meals") {
                            return blankCard();
                          }
                          final resto = _restaurants[index];
                          return restoCard(
                            photoUrl: resto.photoUrl,
                            name: resto.name,
                            address: resto.address ?? '',
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Most Bought Section
                  sectionHeader("Most bought 🔥"),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 250,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        restoCard(
                          photoUrl: '',
                          name: 'Ted’s Batchoy',
                          address: 'Jaro Plaza',
                        ),
                        restoCard(
                          photoUrl: '',
                          name: 'Mang Inasal',
                          address: 'Diversion Road',
                        ),
                        restoCard(
                          photoUrl: '',
                          name: 'Deco’s Batchoy',
                          address: 'City Proper',
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
