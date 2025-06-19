import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:map_try/pages/vendor_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.grey.withAlpha((0.1 * 255).toInt()),
              elevation: 0,
              title: const Text(
                "MAPAkaon",
                style: TextStyle(
                  color: Colors.deepOrangeAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VendorRestaurantPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.store, color: Colors.deepOrangeAccent),
                  tooltip: 'Register your Resto',
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  icon: const Icon(Icons.login, color: Colors.deepOrangeAccent),
                  tooltip: 'Login',
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 237, 247, 242),
              Color.fromARGB(255, 250, 254, 255),
              // Color(0xFF7AB2D3),
              // Color(0xFF4A628A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
          children: [
            const Text(
              "Welcome to MAPAkaon",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrangeAccent,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                "https://cdn3d.iconscout.com/3d/free/thumb/free-fast-food-location-3d-icon-download-in-png-blend-fbx-gltf-file-formats--restaurant-store-navigation-placeholder-pack-maps-and-icons-5665167.png?f=webp",
                height: 180,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Your ultimate guide to discovering and navigating restaurants with ease!",
              style: TextStyle(fontSize: 16, color: Colors.deepOrangeAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _section(
              title: "Our Goal",
              description:
                  "MAPAkaon helps you easily discover dining spots with real-time locations, user reviews, and navigation—all in one web app.",
            ),
            _section(
              title: "Benefits of MAPAkaon",
              description:
                  "✔ Find nearby restaurants\n✔ Get live directions\n✔ Save your favorites\n✔ Smooth searching experience",
            ),
            const SizedBox(height: 30),
            const Text(
              "Hungry? Let's Find Your Next Meal!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrangeAccent,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, "/map");
              },
              icon: const Icon(
                Icons.restaurant_menu,
                color: Colors.lightBlueAccent,
              ),
              label: const Text(
                "Start Searching",
                style: TextStyle(color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrangeAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required String description}) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.brown,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(fontSize: 15),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
