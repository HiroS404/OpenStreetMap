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
    if (doc.exists) {
      setState(() {
        _vendorData = doc.data();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_vendorData == null) {
      return const Center(child: Text('No vendor profile found.'));
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_vendorData!['headerImageUrl'] != '')
              Image.network(_vendorData!['headerImageUrl'], height: 200),
            const SizedBox(height: 16),
            Text(
              'Name: ${_vendorData!['name']}',
              style: const TextStyle(fontSize: 20),
            ),
            Text('Address: ${_vendorData!['address']}'),
            Text('Description: ${_vendorData!['description']}'),
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
    );
  }
}
