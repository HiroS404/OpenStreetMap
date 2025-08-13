import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VendorProfilePage extends StatefulWidget {
  final Map<String, dynamic>? restaurantData;
  final User user;
  const VendorProfilePage({
    super.key,
    required this.restaurantData,
    required this.user,
  });

  @override
  State<VendorProfilePage> createState() => _VendorProfilePageState();
}

class _VendorProfilePageState extends State<VendorProfilePage> {
  Map<String, dynamic>? _vendorData;
  bool _isLoading = true;

  Future<void> _fetchVendorData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(user.uid)
            .get();

    setState(() {
      _vendorData = doc.exists ? doc.data() : null;
      _isLoading = false;
    });
  }

  Future<void> _deleteVendorData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(user.uid)
        .delete();

    setState(() {
      _vendorData = null;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile deleted successfully'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchVendorData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_vendorData == null) {
      return const Scaffold(
        body: Center(child: Text('No vendor profile found.')),
      );
    }

    List<String?> optionalImages = [
      _vendorData!['optionalImageUrl'],
      _vendorData!['optionalImageUrl2'],
      _vendorData!['optionalImageUrl3'],
    ];

    // If some images are missing, pad with nulls so total is 3
    while (optionalImages.length < 3) {
      optionalImages.add(null);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Restaurant Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteVendorData,
            tooltip: 'Delete Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full-width header image
            if (_vendorData!['headerImageUrl'] != '')
              Image.network(
                _vendorData!['headerImageUrl'],
                width: double.infinity,
                height: 200,
                fit: BoxFit.contain, //bug need to test dif images
              ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _vendorData!['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _vendorData!['address'] ?? '',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _vendorData!['description'] ?? '',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Menu:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ...(_vendorData!['menu'] as List).map(
                    (item) => ListTile(
                      title: Text(item['name']),
                      subtitle: Text('${item['category']} - ₱${item['price']}'),
                    ),
                  ),
                ],
              ),
            ),

            // Build a list of image URLs (only non-empty)

            // Display row of 3 cards
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:
                    optionalImages.map((imageUrl) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child:
                                imageUrl != null && imageUrl.isNotEmpty
                                    ? Image.network(
                                      imageUrl,
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
      ),
    );
  }
}
