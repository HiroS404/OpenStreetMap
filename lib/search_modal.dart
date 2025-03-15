import 'package:flutter/material.dart';

class SearchModal extends StatelessWidget {
  const SearchModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🔹 Background Image
        Container(
          height: 300, // Adjust height as needed
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            image: const DecorationImage(
              image: NetworkImage(
                "https://png.pngtree.com/png-vector/20240125/ourmid/pngtree-no-food-3d-illustrations-png-image_11495729.png",
              ),
              fit: BoxFit.contain, // Keeps the image visible without stretching
            ),
          ),
        ),
        const SizedBox(height: 10),
        DraggableScrollableSheet(
          initialChildSize: 0.6, // Default height
          minChildSize: 0.4,
          maxChildSize: 1,
          // Expandable height
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Search Food or Restaurants",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Enter Food/Restaurant Name",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Scrollable List of Restaurant Cards
                  Expanded(
                    child: ListView(
                      controller: scrollController, // Enables smooth scrolling
                      children: const [
                        RestaurantCard(
                          name: "Resto 1",
                          description:
                              "A nice restaurant serving delicious food.",
                        ),
                        RestaurantCard(
                          name: "Resto 2",
                          description:
                              "Famous for its cozy ambiance and great meals.",
                        ),
                        RestaurantCard(
                          name: "Resto 3",
                          description:
                              "Known for quick service and tasty dishes.",
                        ),
                        RestaurantCard(
                          name: "Resto 4",
                          description:
                              "A great spot for family dinners and gatherings.",
                        ),
                        RestaurantCard(
                          name: "Resto 5",
                          description:
                              "Authentic flavors and fresh ingredients.",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// Separate RestaurantCard Widget
class RestaurantCard extends StatelessWidget {
  final String name;
  final String description;

  const RestaurantCard({
    super.key,
    required this.name,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close modal
                  // Add navigation logic to the Directions page here
                },
                icon: const Icon(Icons.directions),
                label: const Text(
                  "Go to Directions",
                  style: TextStyle(color: Colors.black),
                ),

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
