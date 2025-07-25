import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VendorRegistrationPage extends StatefulWidget {
  const VendorRegistrationPage({super.key});

  @override
  VendorRegistrationPageState createState() => VendorRegistrationPageState();
}

class VendorRegistrationPageState extends State<VendorRegistrationPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _menuListController = TextEditingController();

  File? _headerImage;
  XFile? _optionalImage;

  Future<void> _pickHeaderImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _headerImage = File(picked.path);
      });
    }
  }

  Future<void> _pickOptionalImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _optionalImage = picked;
      });
    }
  }

  Future<void> _saveToFirebase() async {
    if (_nameController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter the required fields.',
            style: TextStyle(color: Colors.red),
          ),
          backgroundColor: Colors.white,
        ),
      );
      return;
    }
    try {
      // Check if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to save vendor info.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final userId = user.uid;
      // Show a loading indicator (optional)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Upload header image
      String? headerImageUrl;
      if (_headerImage != null) {
        final fileName =
            'vendors/header_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = await ref.putFile(File(_headerImage!.path));
        headerImageUrl = await uploadTask.ref.getDownloadURL();
      }

      // Upload optional image
      String? optionalImageUrl;
      if (_optionalImage != null) {
        final fileName =
            'vendors/optional_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = await ref.putFile(File(_optionalImage!.path));
        optionalImageUrl = await uploadTask.ref.getDownloadURL();
      }

      final docRef = FirebaseFirestore.instance
          .collection('restaurants')
          .doc(userId);

      await docRef.set({
        'uid': userId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'address': _addressController.text.trim(),
        'menu': _menuListController.text.trim(),
        'headerImageUrl': headerImageUrl ?? '',
        'optionalImageUrl': optionalImageUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      // Close loading indicator
      Navigator.of(context).pop();

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vendor info saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Optionally clear fields
      _nameController.clear();
      _descriptionController.clear();
      _addressController.clear();
      _menuListController.clear();
      setState(() {
        _headerImage = null;
        _optionalImage = null;
      });
    } catch (e) {
      Navigator.of(context).pop(); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Food Vendor Registration")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header Image with upload icon
            Stack(
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    image:
                        _headerImage != null
                            ? DecorationImage(
                              image: FileImage(_headerImage!),
                              fit: BoxFit.cover,
                            )
                            : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      _headerImage == null
                          ? const Center(child: Text("Tap + to add image"))
                          : null,
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.add_a_photo, color: Colors.white),
                      onPressed: _pickHeaderImage,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Name Field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Restaurant Name',
                prefixIcon: Icon(Icons.store),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.deepOrangeAccent,
                    width: 2.0,
                  ),
                ),
                floatingLabelStyle: TextStyle(color: Colors.deepOrangeAccent),
              ),
            ),
            const SizedBox(height: 16),

            // Description Field
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.deepOrangeAccent,
                    width: 2.0,
                  ),
                ),
                floatingLabelStyle: TextStyle(color: Colors.deepOrangeAccent),
              ),
            ),
            const SizedBox(height: 16),

            // Address Field with Map Icon
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.deepOrangeAccent,
                          width: 2.0,
                        ),
                      ),
                      floatingLabelStyle: TextStyle(
                        color: Colors.deepOrangeAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.map),
                  onPressed: () {
                    // TODO: Navigate to map screen
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Menu List Field
            TextField(
              controller: _menuListController,
              maxLines: 3,

              decoration: const InputDecoration(
                labelText: 'Menu List',

                prefixIcon: Icon(Icons.restaurant_menu),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.deepOrangeAccent,
                    width: 2.0,
                  ),
                ),
                floatingLabelStyle: TextStyle(color: Colors.deepOrangeAccent),
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              height: 20,
              child: Text("Upload Images (Optional):"),
            ),
            GestureDetector(
              onTap: _pickOptionalImage,
              child: Container(
                height: 150,
                width: 180,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  image:
                      _optionalImage != null
                          ? DecorationImage(
                            image: FileImage(File(_optionalImage!.path)),
                            fit: BoxFit.cover,
                          )
                          : null,
                ),
                child:
                    _optionalImage == null
                        ? const Center(
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 40,
                          ),
                        )
                        : null,
              ),
            ),
            // Save Button
            ElevatedButton.icon(
              onPressed: _saveToFirebase,
              icon: const Icon(Icons.save),
              label: const Text(
                "Save to Firebase",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.deepOrangeAccent,
                iconColor: Colors.lightGreenAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
