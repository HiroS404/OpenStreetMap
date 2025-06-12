import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Welcome to MAPAkaon",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Image.network(
              "https://cdn3d.iconscout.com/3d/free/thumb/free-fast-food-location-3d-icon-download-in-png-blend-fbx-gltf-file-formats--restaurant-store-navigation-placeholder-pack-maps-and-icons-5665167.png?f=webp",
              height: 200,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10),
            const Text(
              "Your ultimate guide to discovering and navigating restaurants with ease!",
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              "Our Goal",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              "MAPAkaon aims to simplify your dining experience by providing real-time restaurant locations, reviews, and navigation features, all in one app.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              "Benefits of MAPAkaon",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              "✔ Easily find nearby restaurants\n✔ Get real-time directions\n✔ Save your favorite dining spots\n✔ Enjoy a seamless search experience",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            const Text(
              "Hungry? Let's Find Your Next Meal!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to the map page // may bug pani paki fix lng
                Navigator.pushNamed(context, "/map");
              },
              icon: const Icon(Icons.map, color: Colors.white),
              label: const Text("Start Searching for Food"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.store),

              label: const Text("Sign In as Resto Owner??"),
              onPressed: () {
                Navigator.pushNamed(context, '/vendor-profile');
              },
            ), // Extra space at the bottom for scrolling
          ],
        ),
      ),
    );
  }
}
