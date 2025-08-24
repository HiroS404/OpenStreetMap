import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map_try/pages/MenuManagementPage.dart';
import 'package:map_try/services/cloudinary_service.dart';

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
  bool _isEditMode = false;
  bool _showAllMenuItems = false;
  XFile? _newHeaderImage;
Uint8List? _newHeaderImageBytes;


  /// Small, subtle edit button style with new palette color
  Widget _smallEditButton(VoidCallback onPressed) {
    // Only show edit buttons when in edit mode
    if (!_isEditMode) return const SizedBox.shrink();
    
    return IconButton(
      icon: const Icon(Icons.edit, size: 16, color: Color(0xFFE85205)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: onPressed,
      tooltip: 'Edit',
    );
  }

  





  Future<void> _fetchVendorData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
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

  Future<void> _updateField(String field, dynamic value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(user.uid)
        .update({field: value});

    setState(() {
      _vendorData![field] = value;
    });
  }

  Future<void> _updateMenu(List<dynamic> menu) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(user.uid)
        .update({'menu': menu});

    setState(() {
      _vendorData!['menu'] = menu;
    });
  }

  void _editField(String field, String label) {
    final controller = TextEditingController(text: _vendorData![field] ?? '');
    final isMultilineField = field == 'description' || field == 'address';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFfcfcfc),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          'Edit $label',
          style: const TextStyle(color: Color(0xFFE85205)),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: isMultilineField ? 200 : null,
          child: TextField(
            controller: controller,
            maxLines: isMultilineField ? null : 1,
            minLines: isMultilineField ? null : null,
            expands: isMultilineField,
            decoration: InputDecoration(
              labelText: label,
              hintText: _getHintText(field),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE85205)),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(16),
              alignLabelWithHint: isMultilineField,
            ),
            textInputAction: isMultilineField 
                ? TextInputAction.newline 
                : TextInputAction.done,
            textAlignVertical: isMultilineField 
                ? TextAlignVertical.top 
                : TextAlignVertical.center,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85205),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              _updateField(field, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _getHintText(String field) {
    switch (field) {
      case 'description':
        return 'Tell customers about your restaurant...';
      case 'address':
        return 'Enter your complete restaurant address...';
      default:
        return 'Enter ${_getFieldLabel(field)}';
    }
  }

  Future<void> _editHeaderImage() async {
  try {
    // Let vendor pick an image
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked == null) return; // user canceled

    // Read bytes + compress if not on web
    final bytes = await picked.readAsBytes();
    final compressed = await (kIsWeb
        ? Future.value(bytes)
        : FlutterImageCompress.compressWithList(
            bytes,
            quality: 85,
            minWidth: 800,
            minHeight: 800,
          ));

    setState(() {
      _newHeaderImage = picked;
      _newHeaderImageBytes = compressed;
    });

    // Build FilePickerResult for your Cloudinary service
    final uniqueName = 'header_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePickerResult = kIsWeb
        ? FilePickerResult([
            PlatformFile(
              name: uniqueName,
              size: _newHeaderImageBytes!.length,
              bytes: _newHeaderImageBytes,
            ),
          ])
        : FilePickerResult([
            PlatformFile(
              name: uniqueName,
              path: _newHeaderImage!.path,
              size: await File(_newHeaderImage!.path).length(),
            ),
          ]);

    // Upload to Cloudinary
    String? uploadedUrl = await uploadImageToCloudinary(filePickerResult);

    if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
      // Apply Cloudinary transformations (resize/auto-optimize)
      uploadedUrl = uploadedUrl.replaceFirst(
        '/upload/',
        '/upload/w_800,q_auto:best,f_auto/',
      );

      // Save to Firestore
      await _updateField('headerImageUrl', uploadedUrl);

      setState(() {
        _vendorData!['headerImageUrl'] = uploadedUrl;
        _newHeaderImage = null;
        _newHeaderImageBytes = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Header image updated successfully')),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to update header image: $e')),
    );
  }
}


Future<void> _pickAndUploadImage(String fieldKey) async {
  try {
    // Let vendor pick an image
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked == null) return; // user canceled

    // Read bytes + compress if not on web
    final bytes = await picked.readAsBytes();
    final compressed = await (kIsWeb
        ? Future.value(bytes)
        : FlutterImageCompress.compressWithList(
            bytes,
            quality: 85,
            minWidth: 800,
            minHeight: 800,
          ));

    // Build unique file name
    final uniqueName = '${fieldKey}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Build FilePickerResult for your Cloudinary service
    final filePickerResult = kIsWeb
        ? FilePickerResult([
            PlatformFile(
              name: uniqueName,
              size: compressed.length,
              bytes: compressed,
            ),
          ])
        : FilePickerResult([
            PlatformFile(
              name: uniqueName,
              path: picked.path,
              size: await File(picked.path).length(),
            ),
          ]);

    // Upload to Cloudinary
    String? uploadedUrl = await uploadImageToCloudinary(filePickerResult);

    if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
      // Apply Cloudinary transformations
      uploadedUrl = uploadedUrl.replaceFirst(
        '/upload/',
        '/upload/w_800,q_auto:best,f_auto/',
      );

      // Save to Firestore
      await _updateField(fieldKey, uploadedUrl);

      setState(() {
        _vendorData![fieldKey] = uploadedUrl;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$fieldKey updated successfully')),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to update $fieldKey: $e')),
    );
  }
}



  void _addMenuItem() {
    final currentMenu = List<Map<String, dynamic>>.from(_vendorData!['menu'] ?? []);
    
    if (currentMenu.length >= 4) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MenuManagementPage(
            vendorData: _vendorData!,
            onMenuUpdated: (updatedMenu) {
              setState(() {
                _vendorData!['menu'] = updatedMenu;
              });
            },
          ),
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFfcfcfc),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'Add Menu Item',
          style: TextStyle(color: Color(0xFFE85205)),
        ),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _styledTextField(nameController, 'Name'),
              const SizedBox(height: 8),
              _styledTextField(categoryController, 'Category'),
              const SizedBox(height: 8),
              _styledTextField(
                priceController,
                'Price',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85205),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final updatedMenu = List<Map<String, dynamic>>.from(
                _vendorData!['menu'] ?? [],
              );
              updatedMenu.add({
                'name': nameController.text.trim(),
                'category': categoryController.text.trim(),
                'price': double.tryParse(priceController.text.trim()) ?? 0,
              });
              _updateMenu(updatedMenu);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget buildMenuSection() {
    final currentMenu = List<Map<String, dynamic>>.from(_vendorData!['menu'] ?? []);
    final isAtLimit = currentMenu.length >= 4;
    final hasMoreThanFour = currentMenu.length > 4;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Menu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAtLimit ? Colors.orange : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _showAllMenuItems 
                        ? '${currentMenu.length}' 
                        : '${math.min(currentMenu.length, 4)}/4',
                    style: TextStyle(
                      fontSize: 10,
                      color: isAtLimit ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (hasMoreThanFour)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showAllMenuItems = !_showAllMenuItems;
                      });
                    },
                    icon: Icon(
                      _showAllMenuItems ? Icons.visibility_off : Icons.visibility,
                      size: 16,
                      color: const Color(0xFFE85205),
                    ),
                    label: Text(
                      _showAllMenuItems ? 'Hide' : 'View All',
                      style: const TextStyle(
                        color: Color(0xFFE85205),
                        fontSize: 12,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (_isEditMode)
                  IconButton(
                    icon: Icon(
                      isAtLimit ? Icons.edit : Icons.add_circle,
                      color: const Color(0xFFE85205),
                      size: 24,
                    ),
                    onPressed: () => _addMenuItem(),
                    tooltip: isAtLimit ? 'Manage Menu' : 'Add Menu Item',
                  ),
              ],
            ),
          ],
        ),
        if (isAtLimit && _isEditMode && !_showAllMenuItems)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'Menu limit reached. Tap the edit icon to manage all items.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _editMenuItem(int index) {
    final item = List<Map<String, dynamic>>.from(_vendorData!['menu'])[index];
    final nameController = TextEditingController(text: item['name']);
    final categoryController = TextEditingController(text: item['category']);
    final priceController = TextEditingController(
      text: item['price'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFfcfcfc),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'Edit Menu Item',
          style: TextStyle(color: Color(0xFFE85205)),
        ),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _styledTextField(nameController, 'Name'),
              const SizedBox(height: 8),
              _styledTextField(categoryController, 'Category'),
              const SizedBox(height: 8),
              _styledTextField(
                priceController,
                'Price',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85205),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final updatedMenu = List<Map<String, dynamic>>.from(
                _vendorData!['menu'],
              );
              updatedMenu[index] = {
                'name': nameController.text.trim(),
                'category': categoryController.text.trim(),
                'price': double.tryParse(priceController.text.trim()) ?? 0,
              };
              _updateMenu(updatedMenu);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteMenuItem(index);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(String? imageUrl, String fieldKey) {
  final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;

  return GestureDetector(
    onTap: () {
      if (!_isEditMode && hasImage) {
        // Open full screen view
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              body: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Center(
                  child: InteractiveViewer(
                    child: Image.network(imageUrl),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    },
    child: Stack(
      children: [
        Card(
          elevation: hasImage ? 4 : 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: hasImage ? null : Colors.grey[200],
              image: hasImage
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: hasImage
                ? null
                : const Center(
                    child: Icon(Icons.image, size: 40, color: Colors.grey),
                  ),
          ),
        ),

        // Edit/Add button when in edit mode
        if (_isEditMode)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(60),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  hasImage ? Icons.edit : Icons.add,
                  color: Colors.white,
                  size: 16,
                ),
                onPressed: () => _pickAndUploadImage(fieldKey), // 👈 new flow
                tooltip: hasImage ? 'Change Image' : 'Add Image',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ),
          ),

        // Delete button when in edit mode & image exists
        if (_isEditMode && hasImage)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(60),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                onPressed: () => _updateField(fieldKey, ''), // remove image
                tooltip: 'Remove Image',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ),
          ),
      ],
    ),
  );
}


  Widget _styledTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE85205)),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _confirmDeleteMenuItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFfcfcfc),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'Delete Menu Item',
          style: TextStyle(color: Color(0xFFE85205)),
        ),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final updatedMenu = List<Map<String, dynamic>>.from(
                _vendorData!['menu'],
              );
              updatedMenu.removeAt(index);
              _updateMenu(updatedMenu);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDeleteVendorData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text(
          "Are you sure you want to permanently delete your profile? "
          "This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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

  Widget _expandableInfoRow(IconData icon, String text, String fieldKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFE85205), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: ExpandableText(
              text,
              trimLength: 50,
              style: const TextStyle(fontSize: 14, color: Color(0xFF8C8C8C)),
            ),
          ),
          const SizedBox(width: 6),
          _smallEditButton(
            () => _editField(fieldKey, _getFieldLabel(fieldKey)),
          ),
        ],
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

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFE85205),
        title: const Text(
          'Your Restaurant Profile',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditMode ? Icons.check : Icons.edit,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isEditMode = !_isEditMode;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isEditMode ? 'Edit mode enabled' : 'Edit mode disabled',
                  ),
                  duration: const Duration(seconds: 1),
                  backgroundColor: const Color(0xFFE85205),
                ),
              );
            },
            tooltip: _isEditMode ? 'Exit Edit Mode' : 'Enter Edit Mode',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: _confirmAndDeleteVendorData,
            tooltip: 'Delete Profile',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFfcfcfc),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image with Edit Option
            Stack(
              children: [
                if (_vendorData!['headerImageUrl'] != '')
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    child: Image.network(
                      _vendorData!['headerImageUrl'],
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (_vendorData!['headerImageUrl'] == '' || _vendorData!['headerImageUrl'] == null)
                  Container(
                    width: double.infinity,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.image, size: 60, color: Colors.grey),
                    ),
                  ),
                if (_isEditMode)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(60),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                        onPressed: () => _editHeaderImage(),
                        tooltip: 'Edit Header Image',
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _vendorData!['name'] ?? '',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 25,
                            color: const Color(0xFFE85205),
                          ),
                        ),
                      ),
                      _smallEditButton(() => _editField('name', 'Name')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _vendorData!['tags'] ?? 'dapat • dynamic na dre• hahaha',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8c8c8c),
                    ),
                  ),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      const Text(
                        'About',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      _smallEditButton(
                        () => _editField('description', 'Description'),
                      ),
                    ],
                  ),
                  ExpandableText(
                    _vendorData!['description'] ?? '',
                    trimLength: 120,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8C8C8C),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _expandableInfoRow(
                    Icons.phone,
                    _vendorData!['phoneNumber'] ?? '',
                    'phoneNumber',
                  ),
                  _expandableInfoRow(
                    Icons.location_on,
                    _vendorData!['address'] ?? '',
                    'address',
                  ),
                  _expandableInfoRow(
                    Icons.access_time,
                    _vendorData!['hours'] ?? '12:00 PM – 12:00 AM',
                    'hours',
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE85205)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.directions,
                        color: Color(0xFFE85205),
                      ),
                      label: const Text(
                        'Go to directions',
                        style: TextStyle(color: Color(0xFFE85205)),
                      ),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Menu Section with Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Menu',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),

                     _isEditMode 
  ? IconButton(
      icon: const Icon(Icons.add_circle, color: Color(0xFFE85205), size: 24),
      onPressed: () => _addMenuItem(),
      tooltip: 'Add Menu Item',
      style: IconButton.styleFrom(
        backgroundColor: Colors.orange,
      ),
    )
  : FloatingActionButton.extended(
      onPressed: () => _addMenuItem(),
      icon: const Icon(Icons.menu, color: Colors.white, size: 24),
      label: const Text('See All Menu', style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.deepOrange,
    ),

                        
                    ],
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
                      double aspectRatio =
                          constraints.maxWidth > 800 ? 6.5 : 5.5;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _showAllMenuItems 
                ? (_vendorData!['menu'] as List).length 
                : math.min((_vendorData!['menu'] as List).length, 4), // Show all or limit to 4
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: aspectRatio,
            ),
            itemBuilder: (context, index) {
              final item = (_vendorData!['menu'] as List)[index];
              return GestureDetector(
                onTap: _isEditMode ? () => _editMenuItem(index) : null,
                child: Stack(
                  children: [
                    Card(
                      color: const Color(0xFFecc39e),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                item['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Center(
                              child: Text(
                                '|',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item['category'] ?? '',
                                style: const TextStyle(
                                  color: Color(0xFF8c8c8c),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Center(
                              child: Text(
                                '|',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '₱${item['price']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE85205),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
          // Menu Item Edit Indicator
          if (_isEditMode)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE85205),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      //optional image card
                      _buildImageCard(_vendorData!['optionalImage1'], 'galleryImageUrl'),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            }
              
          }




class ExpandableText extends StatefulWidget {
  final String text;
  final int trimLength;
  final TextStyle? style;

  const ExpandableText(
    this.text, {
    super.key,
    this.trimLength = 100,
    this.style,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bool shouldTrim = widget.text.length > widget.trimLength;
    final String displayText =
        shouldTrim && !isExpanded
            ? '${widget.text.substring(0, widget.trimLength)}...'
            : widget.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          style:
              widget.style ??
              const TextStyle(fontSize: 14, color: Color(0xFF8C8C8C)),
        ),
        if (shouldTrim)
          GestureDetector(
            onTap: () => setState(() => isExpanded = !isExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                isExpanded ? 'See less' : 'See more',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFE85205),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _getFieldLabel(String key) {
  switch (key) {
    case 'phoneNumber':
      return 'Phone Number';
    case 'address':
      return 'Address';
    case 'hours':
      return 'Business Hours';
    default:
      return 'Field';
  }
}