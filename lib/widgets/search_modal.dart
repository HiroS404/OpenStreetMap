import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_try/pages/resto_detail_screen.dart';

class SearchModal extends StatefulWidget {
  final ValueNotifier<LatLng?> destinationNotifier;
  const SearchModal({super.key, required this.destinationNotifier});

  @override
  State<SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<SearchModal> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  // ignore: unused_field
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};

  void _searchRestaurants(String query) async {
    final lowerQuery = query.toLowerCase();

    // ✅ If user types "all" → get ALL restaurants
    if (lowerQuery == "all") {
      final allSnapshot =
          await FirebaseFirestore.instance.collection('restaurants').get();

      final List<Map<String, dynamic>> fetchedResults =
          allSnapshot.docs.map((doc) {
            final data = doc.data();
            final geoPoint = data['location'] as GeoPoint?;
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'route': data['route'] ?? '',
              'address': data['address'] ?? '',
              'headerImageUrl': data['headerImageUrl'] ?? '',
              'location': geoPoint,
            };
          }).toList();

      setState(() {
        _results = fetchedResults;
      });
      return;
    }

    final allSnapshot =
        await FirebaseFirestore.instance.collection('restaurants').get();

    final List<Map<String, dynamic>> fetchedResults = [];

    for (final doc in allSnapshot.docs) {
      final data = doc.data();
      final geoPoint = data['location'] as GeoPoint?;
      bool hasMatchingItem = false;

      // Check menu items
      if (data['menu'] is List) {
        final menuList = data['menu'] as List;
        for (final item in menuList) {
          if (item is Map<String, dynamic>) {
            final itemName = (item['name'] ?? '').toString().toLowerCase();
            final itemCategory =
                (item['category'] ?? '').toString().toLowerCase();

            if (itemName.contains(lowerQuery) ||
                itemCategory.contains(lowerQuery)) {
              hasMatchingItem = true;
              break;
            }
          }
        }
      }

      // Check drinks if no menu match found
      if (!hasMatchingItem && data['drinks'] is List) {
        final drinksList = data['drinks'] as List;
        for (final item in drinksList) {
          if (item is Map<String, dynamic>) {
            final itemName = (item['name'] ?? '').toString().toLowerCase();
            final itemCategory =
                (item['category'] ?? '').toString().toLowerCase();

            if (itemName.contains(lowerQuery) ||
                itemCategory.contains(lowerQuery)) {
              hasMatchingItem = true;
              break;
            }
          } else if (item is String) {
            // Handle case where drinks might be stored as strings
            if (item.toLowerCase().contains(lowerQuery)) {
              hasMatchingItem = true;
              break;
            }
          }
        }
      }

      // Also check restaurant name
      final restoName = (data['name'] ?? '').toString().toLowerCase();
      if (restoName.contains(lowerQuery)) {
        hasMatchingItem = true;
      }

      if (hasMatchingItem) {
        fetchedResults.add({
          'id': doc.id,
          'name': data['name'] ?? '',
          'route': data['route'] ?? '',
          'address': data['address'] ?? '',
          'headerImageUrl': data['headerImageUrl'] ?? '',
          'location': geoPoint,
        });
      }
    }

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
                            ? const Center(
                              child: Text(
                                "No results found. \n \nFOR DEMO: try adobo, fried chicken, cordon bleu, hedang pantat.....\n or try type 'all' ",
                              ),
                            )
                            : ListView.builder(
                              controller: scrollController,
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final resto = _results[index];
                                return RestaurantCard(
                                  data: resto,
                                  destinationNotifier:
                                      widget.destinationNotifier,
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

class RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ValueNotifier<LatLng?> destinationNotifier;

  const RestaurantCard({
    super.key,
    required this.data,
    required this.destinationNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final geoPoint = data['location'] as GeoPoint?;
    final lat = geoPoint?.latitude ?? 0.0;
    final lng = geoPoint?.longitude ?? 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => RestoDetailScreen(
                  restoId: data['id'], // doc id
                  destinationNotifier: destinationNotifier,
                ),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                data['headerImageUrl'] ?? '',
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
                    data['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    data['address'] ?? 'No address',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        destinationNotifier.value = LatLng(lat, lng);
                        Navigator.pop(context);
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
      ),
    );
  }
}
