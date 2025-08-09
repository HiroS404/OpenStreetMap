import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;

import 'package:google_fonts/google_fonts.dart';
import 'package:map_try/model/restaurant_model.dart';
import 'package:map_try/pages/owner_logIn/vendor_create_resto_acc.dart';
import 'package:map_try/services/restaurant_service.dart';
import 'package:map_try/widgets/utils/home_page_widgets/homePage_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}





class CategoryChipsHeader extends SliverPersistentHeaderDelegate {
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: SizedBox(
        height: maxExtent, // ensure exact height match
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              categoryChip("Nearby", true),
              categoryChip("Meals"),
              categoryChip("Drinks"),
              categoryChip("Fast Food"),
              categoryChip("Snacks"),
            ],
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
      false;
}



// To edit and refactor to make the whole _homePageState class more readable and especially dynamic.
// To seperate the logic from the UI and whatnot - M
class _HomePageState extends State<HomePage> {
  final ScrollController _hotDealsController = ScrollController();
  final ScrollController _mostBoughtController = ScrollController();
  List<Restaurant> _restaurants = [];
  bool _isLoading = true;

  Timer? _autoScrollTimer;
  bool _userInteracting = false;

  @override
  void initState() {
    super.initState();
    _startAutoScroll(_hotDealsController);
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      final data = await RestaurantService.fetchRestaurants();

      if (!mounted) return; // Safe to call setState and use context now

      setState(() {
        _restaurants = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load restaurants. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _startAutoScroll(ScrollController controller) {
    const duration = Duration(milliseconds: 100);
    const step = 1.0; //scroll step in pixels edit later for easy debug lol

    _autoScrollTimer = Timer.periodic(duration, (_) {
      if (!_userInteracting && controller.hasClients) {
        if (controller.offset < controller.position.maxScrollExtent) {
          controller.jumpTo(controller.offset + step);
        } else {
          controller.jumpTo(0); // restart from beginning
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_restaurants.isEmpty) {
      return const Center(child: Text("No restaurants available."));
    }
    return Scaffold(
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
                    Container(
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('Assets/route_pics/ilonggo.png'),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(34),
                          bottomRight: Radius.circular(34),
                        ),
                      ),
                    ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(34),
                          bottomRight: Radius.circular(34),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.lightGreenAccent.withAlpha(100),
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
                          // Create Resto IconButton
                          IconButton(
                            icon: const Icon(
                              Icons.restaurant,
                              color: Colors.white,
                              size: 28,
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

                          Row(
                            children: [
                              badges.Badge(
                                position: badges.BadgePosition.topEnd(
                                  top: -1,
                                  end: -1,
                                ),
                                badgeStyle: const badges.BadgeStyle(
                                  padding: EdgeInsets.all(5),
                                  badgeColor: Colors.redAccent,
                                ),
                                badgeContent: const Text(
                                  '0',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.notifications_none,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    // function here
                                  },
                                ),
                              ),

                              // Login IconButton
                              IconButton(
                                icon: const Icon(
                                  Icons.person_outline_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  //function here
                                },
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
                                    color: Colors.deepOrangeAccent,
                                    size: 20,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Iloilo City, Philippines',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16 * percent),
                              Text(
                                'MapaKaon',
                                style: GoogleFonts.poppins(
                                  fontSize: 32 * percent,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: Colors.white,
                                ),
                              ),
                              if (percent > 0.5)
                                Column(
                                  children: [
                                    Text.rich(
                                      // Stroke (Outline)
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
                                                    fontWeight: FontWeight.bold,
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
                                                  'Way',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Colors.deepOrangeAccent,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 4),
                                    const Text(
                                      'Mapanamkon nga pagkaon, makita mo dayon!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w400,
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
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const TextField(
                          decoration: InputDecoration(
                            icon: Icon(Icons.search),
                            hintText: "Let's find the food you like",
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    // Collapsed Title "MapaKaon" fading in at the very top
                    Positioned(
                      top: 10,
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
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        foreground:
                                            Paint()
                                              ..style = PaintingStyle.stroke
                                              ..strokeWidth = 2
                                              ..color =
                                                  Colors
                                                      .black, // No stroke for "Mapa"
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Kaon',
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        foreground:
                                            Paint()
                                              ..style = PaintingStyle.stroke
                                              ..strokeWidth = 2
                                              ..color =
                                                  Colors.black, // Outline color
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
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Kaon',
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        color: Colors.deepOrangeAccent,
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
          SliverPersistentHeader(pinned: true, delegate: CategoryChipsHeader()),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Hot Deals 🔥 Section
                  sectionHeader("Hot Deals 🔥"),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 250,
                    child: Listener(
                      onPointerDown: (_) => _onUserInteraction(),
                      child: ListView.builder(
                        controller: _hotDealsController,
                        scrollDirection: Axis.horizontal,
                        itemCount: _restaurants.length,
                        itemBuilder: (context, index) {
                          final resto = _restaurants[index];
                          return restoCard(
                            photoUrl: resto.photoUrl,
                            name: resto.name,
                            description: resto.description,
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
                          description: 'Jaro Plaza',
                        ),
                        restoCard(
                          photoUrl: '',
                          name: 'Mang Inasal',
                          description: 'Diversion Road',
                        ),
                        restoCard(
                          photoUrl: '',
                          name: 'Deco’s Batchoy',
                          description: 'City Proper',
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
