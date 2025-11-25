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
  bool _isSearching = false;

  void _searchRestaurants(String query) async {
    setState(() => _isSearching = true);

    final lowerQuery = query.toLowerCase();

    try {
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
          _isSearching = false;
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
              if (item.toLowerCase().contains(lowerQuery)) {
                hasMatchingItem = true;
                break;
              }
            }
          }
        }

        final restoName = (data['name'] ?? '').toString().toLowerCase();
        final restoAddress = (data['address'] ?? '').toString().toLowerCase();

        if (restoName.contains(lowerQuery) || restoAddress.contains(lowerQuery)) {
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
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      print('Search error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth >= 1200;

    if (isDesktop) {
      return Center(
        child: Container(
          width: screenWidth * 0.7, // 70% of screen width
          height: screenHeight * 0.8, // 80% of screen height
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: _buildDesktopView(),
        ),
      );
    } else {
      return _buildMobileView();
    }
  }

  // Desktop View
  Widget _buildDesktopView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.search, size: 28, color: Colors.orange),
              const SizedBox(width: 12),
              const Text(
                "Search Food or Restaurants",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search TextField
          TextField(
            controller: _controller,
            autofocus: true,
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
              hintText: "Enter Food/Restaurant Name (or type 'all')",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  setState(() => _results = []);
                },
              )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.orange, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    "No results found",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Try: adobo, fried chicken, cordon bleu\nor type 'all' to see everything",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
                : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final resto = _results[index];
                return _DesktopRestaurantCard(
                  data: resto,
                  destinationNotifier: widget.destinationNotifier,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Mobile View (Original)
  Widget _buildMobileView() {
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
                    child: _isSearching
                        ? const Center(child: CircularProgressIndicator())
                        : _results.isEmpty
                        ? const Center(
                      child: Text(
                        "Tap searchbox, search for your wants \n    Type 'all' to show all restaurants",
                      ),
                    )
                        : ListView.builder(
                      controller: scrollController,
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final resto = _results[index];
                        return RestaurantCard(
                          data: resto,
                          destinationNotifier: widget.destinationNotifier,
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

// Desktop Restaurant Card
class _DesktopRestaurantCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ValueNotifier<LatLng?> destinationNotifier;

  const _DesktopRestaurantCard({
    Key? key,
    required this.data,
    required this.destinationNotifier,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final geoPoint = data['location'] as GeoPoint?;
    final lat = geoPoint?.latitude ?? 0.0;
    final lng = geoPoint?.longitude ?? 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pop(context); // Close search dialog
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestoDetailScreen(
                restoId: data['id'],
                destinationNotifier: destinationNotifier,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Image.network(
                data['headerImageUrl'] ?? '',
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: Icon(Icons.restaurant, size: 48)),
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['address'] ?? 'No address',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          destinationNotifier.value = LatLng(lat, lng);
                          Navigator.pop(context); // Close dialog and go to map
                        },
                        icon: const Icon(Icons.directions, size: 16),
                        label: const Text("Directions"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Mobile Restaurant Card (Original)
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
            builder: (context) => RestoDetailScreen(
              restoId: data['id'],
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
                errorBuilder: (context, error, stackTrace) => Container(
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