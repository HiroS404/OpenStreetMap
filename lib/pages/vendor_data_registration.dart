import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:map_try/pages/resto%20AddressMap/pick_address_map.dart';
import 'package:map_try/pages/vendor_dashboard.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:map_try/services/cloudinary_service.dart';

class VendorRegistrationPage extends StatefulWidget {
  final User user;
  const VendorRegistrationPage({super.key, required this.user});

  @override
  VendorRegistrationPageState createState() => VendorRegistrationPageState();
}

class VendorRegistrationPageState extends State<VendorRegistrationPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final List<Map<String, dynamic>> _menuItems = [];

  final TextEditingController _menuNameController = TextEditingController();
  final TextEditingController _menuPriceController = TextEditingController();
  final TextEditingController _menuCategoryController = TextEditingController();

  // For mobile (non-web)
  File? _headerImage;
  XFile? _optionalImage;
  XFile? _optionalImage2;
  XFile? _optionalImage3;

  Uint8List? _headerImageBytes;
  Uint8List? _optionalImageBytes;
  Uint8List? _optionalImage2Bytes;
  Uint8List? _optionalImage3Bytes;
  double? selectedLat;
  double? selectedLng;

  // Helper to compress for Web/Mobile
  Future<Uint8List> _compressImage(Uint8List data, {int quality = 85}) async {
    return await FlutterImageCompress.compressWithList(
      data,
      quality: quality, // Reduce quality to save bandwidth
      minWidth: 800, // Resize width
      minHeight: 800, // Resize height
    );
  }

  Future<void> _pickHeaderImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        final compressed = await _compressImage(bytes);
        setState(() {
          _headerImageBytes = compressed;
        });
      } else {
        final file = File(picked.path);
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          quality: 85,
          minWidth: 800,
          minHeight: 800,
        );
        setState(() {
          _headerImageBytes = compressedBytes; // store compressed
          _headerImage = file; // keep original if needed
        });
      }
    }
  }

  Future<void> _pickOptionalImage(int index) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      if (kIsWeb) {
        // Works for both desktop web and mobile web
        final bytes = await picked.readAsBytes();
        setState(() {
          if (index == 1) {
            _optionalImage = picked;
            _optionalImageBytes = bytes;
          } else if (index == 2) {
            _optionalImage2 = picked;
            _optionalImage2Bytes = bytes;
          } else if (index == 3) {
            _optionalImage3 = picked;
            _optionalImage3Bytes = bytes;
          }
        });
      } else {
        // Native mobile (Android/iOS)
        setState(() {
          if (index == 1) _optionalImage = picked;
          if (index == 2) _optionalImage2 = picked;
          if (index == 3) _optionalImage3 = picked;
        });
      }
    }
  }

  Widget buildOptionalImagePicker({
    required int index,
    XFile? imageFile,
    Uint8List? imageBytes,
  }) {
    return GestureDetector(
      onTap: () => _pickOptionalImage(index),
      child: Container(
        height: 150,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
          image:
              (imageBytes != null || (imageFile != null && !kIsWeb))
                  ? DecorationImage(
                    image:
                        kIsWeb
                            ? MemoryImage(imageBytes!)
                            : FileImage(File(imageFile!.path)) as ImageProvider,
                    fit: BoxFit.cover,
                  )
                  : null,
        ),
        child:
            (imageBytes == null && (imageFile == null || kIsWeb))
                ? const Center(
                  child: Icon(Icons.add_photo_alternate_outlined, size: 40),
                )
                : Container(
                  alignment: Alignment.center,
                  color: Colors.black45, // overlay
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        "Change Image",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.edit, color: Colors.white, size: 15),
                    ],
                  ),
                ),
      ),
    );
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

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Upload header image to Cloudinary
      String? headerImageUrl;
      if (_headerImage != null || _headerImageBytes != null) {
        final filePickerResult =
            kIsWeb
                ? FilePickerResult([
                  PlatformFile(
                    name: 'header.jpg',
                    size: _headerImageBytes!.length,
                    bytes: _headerImageBytes,
                  ),
                ])
                : FilePickerResult([
                  PlatformFile(
                    name: 'header.jpg',
                    path: _headerImage!.path,
                    size: await File(_headerImage!.path).length(),
                  ),
                ]);

        headerImageUrl = await uploadImageToCloudinary(filePickerResult);

        // Use Cloudinary transformation for homepage/search thumbnails
        if (headerImageUrl != null) {
          headerImageUrl = headerImageUrl.replaceFirst(
            '/upload/',
            '/upload/w_800,q_auto:best,f_auto/', // Limit size & auto-optimize
          );
        }
      }

      // Upload optional image 1
      String? optionalImageUrl1;
      if (_optionalImage != null || _optionalImageBytes != null) {
        final filePickerResult =
            kIsWeb
                ? FilePickerResult([
                  PlatformFile(
                    name: 'optional1.jpg',
                    size: _optionalImageBytes!.length,
                    bytes: _optionalImageBytes,
                  ),
                ])
                : FilePickerResult([
                  PlatformFile(
                    name: 'optional1.jpg',
                    path: _optionalImage!.path,
                    size: await File(_optionalImage!.path).length(),
                  ),
                ]);

        optionalImageUrl1 = await uploadImageToCloudinary(filePickerResult);

        if (optionalImageUrl1 != null) {
          optionalImageUrl1 = optionalImageUrl1.replaceFirst(
            '/upload/',
            '/upload/w_300,q_auto:best,f_auto/',
          );
        }
      }

      // Upload optional image 2
      String? optionalImageUrl2;
      if (_optionalImage2 != null || _optionalImage2Bytes != null) {
        final filePickerResult =
            kIsWeb
                ? FilePickerResult([
                  PlatformFile(
                    name: 'optional2.jpg',
                    size: _optionalImage2Bytes!.length,
                    bytes: _optionalImage2Bytes,
                  ),
                ])
                : FilePickerResult([
                  PlatformFile(
                    name: 'optional2.jpg',
                    path: _optionalImage2!.path,
                    size: await File(_optionalImage2!.path).length(),
                  ),
                ]);

        optionalImageUrl2 = await uploadImageToCloudinary(filePickerResult);

        if (optionalImageUrl2 != null) {
          optionalImageUrl2 = optionalImageUrl2.replaceFirst(
            '/upload/',
            '/upload/w_300,q_auto:best,f_auto/',
          );
        }
      }

      // Upload optional image 3
      String? optionalImageUrl3;
      if (_optionalImage3 != null || _optionalImage3Bytes != null) {
        final filePickerResult =
            kIsWeb
                ? FilePickerResult([
                  PlatformFile(
                    name: 'optional3.jpg',
                    size: _optionalImage3Bytes!.length,
                    bytes: _optionalImage3Bytes,
                  ),
                ])
                : FilePickerResult([
                  PlatformFile(
                    name: 'optional3.jpg',
                    path: _optionalImage3!.path,
                    size: await File(_optionalImage3!.path).length(),
                  ),
                ]);

        optionalImageUrl3 = await uploadImageToCloudinary(filePickerResult);

        if (optionalImageUrl3 != null) {
          optionalImageUrl3 = optionalImageUrl3.replaceFirst(
            '/upload/',
            '/upload/w_300,q_auto:best,f_auto/',
          );
        }
      }

      // Save vendor data to Firestore
      final docRef = FirebaseFirestore.instance
          .collection('restaurants')
          .doc(userId);

      await docRef.set({
        'uid': userId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'address': _addressController.text.trim(),
        'menu': _menuItems,
        'headerImageUrl': headerImageUrl ?? '',
        'optionalImageUrl1': optionalImageUrl1 ?? '',
        'optionalImageUrl2': optionalImageUrl2 ?? '',
        'optionalImageUrl3': optionalImageUrl3 ?? '',
        'location':
            selectedLat != null && selectedLng != null
                ? GeoPoint(selectedLat!, selectedLng!)
                : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vendor info saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Redirect to Vendor Profile
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => VendorProfilePage(
                restaurantData: {},
                user: FirebaseAuth.instance.currentUser!,
              ),
        ),
      );

      // Reset form
      _nameController.clear();
      _descriptionController.clear();
      _addressController.clear();
      _menuItems.clear();
      setState(() {
        _headerImage = null;
        _optionalImage = null;
      });
    } catch (e) {
      Navigator.of(context).pop(); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addMenuItem() {
    final name = _menuNameController.text.trim();
    final priceText = _menuPriceController.text.trim();
    final category = _menuCategoryController.text.trim();

    if (name.isEmpty || priceText.isEmpty || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all menu fields')),
      );
      return;
    }

    final price = double.tryParse(priceText);
    if (price == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Price must be a number')));
      return;
    }

    setState(() {
      _menuItems.add({'name': name, 'price': price, 'category': category});
    });

    _menuNameController.clear();
    _menuPriceController.clear();
    _menuCategoryController.clear();
  }

  void _removeMenuItem(int index) {
    setState(() {
      _menuItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Food Vendor Registration")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(
              children: [
                // Background container with image preview
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    image:
                        _headerImageBytes != null
                            ? DecorationImage(
                              image: MemoryImage(
                                _headerImageBytes!,
                              ), // Web preview
                              fit: BoxFit.cover,
                            )
                            : _headerImage != null
                            ? DecorationImage(
                              image: FileImage(_headerImage!), // Mobile preview
                              fit: BoxFit.cover,
                            )
                            : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      _headerImage == null && _headerImageBytes == null
                          ? const Center(child: Text("Tap + to add image"))
                          : null,
                ),

                // Fade overlay when preview exists
                if (_headerImageBytes != null || _headerImage != null)
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(76), //
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                // "Change Image" text overlay
                if (_headerImageBytes != null || _headerImage != null)
                  const Center(
                    child: Text(
                      "Change Image",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black54,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Pick image button
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
                  icon: const Icon(Icons.map_rounded, color: Colors.deepOrange),
                  onPressed: () async {
                    final selectedLocation = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                PickAddressMapScreen(), // the map picker screen
                      ),
                    );

                    if (selectedLocation != null) {
                      setState(() {
                        _addressController.text = selectedLocation['address'];
                        // You can also store coordinates for later use
                        // _selectedLat = selectedLocation['lat'];
                        // _selectedLng = selectedLocation['lng'];
                        selectedLat = selectedLocation['lat'];
                        selectedLng = selectedLocation['lng'];
                        print(
                          'Selected Location: ${selectedLocation['lat']}, ${selectedLocation['lng']}',
                        );
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Menu List Field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Add Menu Item",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _menuNameController,
                  decoration: const InputDecoration(
                    labelText: 'Menu Name',
                    prefixIcon: Icon(Icons.fastfood),
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
                const SizedBox(height: 8),

                //price field
                TextField(
                  controller: _menuPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    prefixIcon: Icon(Icons.attach_money),
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
                const SizedBox(height: 8),

                // Category field
                TextField(
                  controller: _menuCategoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
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

                const SizedBox(height: 8),

                //add button
                ElevatedButton.icon(
                  onPressed: _addMenuItem,
                  label: const Text("Add Menu List"),
                  icon: const Icon(Icons.add),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrangeAccent,
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),

                const SizedBox(height: 16),
                //show added menu items
                const Text(
                  "Current Menu: Added Menu Items",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: _menuItems.length,
                  itemBuilder: (context, index) {
                    final item = _menuItems[index];
                    return ListTile(
                      leading: const Icon(Icons.restaurant_menu),
                      title: Text('${item['name']} - \$${item['price']}'),
                      subtitle: Text('${item['category']} '),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeMenuItem(index),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),
            const SizedBox(
              height: 20,
              child: Text("Upload Images (Optional):"),
            ),

            Row(
              children: [
                Expanded(
                  child: buildOptionalImagePicker(
                    index: 1,
                    imageFile: _optionalImage,
                    imageBytes: _optionalImageBytes,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: buildOptionalImagePicker(
                    index: 2,
                    imageFile: _optionalImage2,
                    imageBytes: _optionalImage2Bytes,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: buildOptionalImagePicker(
                    index: 3,
                    imageFile: _optionalImage3,
                    imageBytes: _optionalImage3Bytes,
                  ),
                ),
              ],
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
