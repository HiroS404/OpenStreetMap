import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchModal extends StatefulWidget {
  const SearchModal({super.key});

  @override
  State<SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<SearchModal> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];

  void _searchRestaurants(String query) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('restaurants')
            .where('menu', arrayContains: query.toLowerCase())
            .get();

    final List<Map<String, dynamic>> fetchedResults =
        snapshot.docs.map((doc) {
          return doc.data();
        }).toList();

    setState(() {
      _results = fetchedResults;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            image: const DecorationImage(
              image: NetworkImage(
                "https://png.pngtree.com/png-vector/20240125/ourmid/pngtree-no-food-3d-illustrations-png-image_11495729.png",
              ),
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 10),
        DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 1,
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
                    controller: _controller,
                    onChanged: (value) {
                      if (value.length > 2) {
                        _searchRestaurants(value.trim().toLowerCase());
                      } else {
                        setState(() {
                          _results = [];
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: "Enter Food/Restaurant Name",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child:
                        _results.isEmpty
                            ? const Center(child: Text("No results found."))
                            : ListView.builder(
                              controller: scrollController,
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final resto = _results[index];
                                return RestaurantCard(
                                  name: resto['name'],
                                  description:
                                      "${resto['address']} • Route: ${resto['route']}",
                                  photoUrl:
                                      resto['photoUrl'] ??
                                      '', // fallback if null
                                );
                              },
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
  final String photoUrl;

  const RestaurantCard({
    super.key,
    required this.name,
    required this.description,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              photoUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) => Container(
                    height: 160,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                      // Add navigation logic to Directions page
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
        ],
      ),
    );
  }
}
