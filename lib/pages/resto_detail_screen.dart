import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RestoDetailScreen extends StatelessWidget {
  final String restoId;
  const RestoDetailScreen({super.key, required this.restoId});
  // Extract optionalImages safely from Firestore doc

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Restaurant Details")),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance
                .collection('restaurants')
                .doc(restoId)
                .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Restaurant not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List<String> optionalImages =
              (data['optionalImageUrl'] is List)
                  ? List<String>.from(data['optionalImageUrl'])
                  : [];
          while (optionalImages.length < 3) {
            optionalImages.add(''); // '' will be a blank card
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['headerImageUrl'] is String)
                  Image.network(data['headerImageUrl']),
                const SizedBox(height: 16),

                Text(
                  data['name']?.toString() ?? 'No name',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                if (data['address'] != null)
                  Text(
                    data['address'].toString(),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                const SizedBox(height: 16),

                if (data['description'] != null)
                  Text(data['description'].toString()),
                const SizedBox(height: 20),

                // Menu rendering
                if (data['menu'] is List) ...[
                  const Text(
                    "Menu",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...List<Map<String, dynamic>>.from(data['menu']).map((
                    menuItem,
                  ) {
                    final name = menuItem['name'] ?? '';
                    final category = menuItem['category'] ?? '';
                    final price = menuItem['price']?.toString() ?? '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text("$name ($category) - ₱$price"),
                    );
                  }),
                ],

                // Optional images section
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children:
                        optionalImages.map((optionalImageUrl) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child:
                                    optionalImageUrl.isNotEmpty
                                        ? Image.network(
                                          data['optionalImageUrl'],
                                          fit: BoxFit.cover,
                                          height: 150,
                                        )
                                        : Container(
                                          height: 150,
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
