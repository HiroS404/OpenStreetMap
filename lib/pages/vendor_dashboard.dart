import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:map_try/main.dart';
import 'package:map_try/pages/menuManagementPage.dart';
import 'package:map_try/pages/resto%20AddressMap/pick_address_map.dart';

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
  bool _isEditing = false;

  /// Small, subtle edit button style with new palette color
  Widget _smallEditButton(VoidCallback onPressed) {
    return IconButton(
      icon: const Icon(Icons.edit, size: 16, color: Color(0xFFE85205)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: onPressed,
      tooltip: 'Edit',
    );
  }

  Future<void> _editAddressWithMap() async {
    // Navigate to map picker
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PickAddressMapScreen(), // your picker screen
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final newAddress = result['address'] ?? '';
      final lat = result['lat'];
      final lng = result['lng'];

      if (newAddress.isNotEmpty && lat != null && lng != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(user.uid)
            .update({
              'address': newAddress,
              'location': GeoPoint(lat, lng), // ✅ Firestore GeoPoint
            });

        setState(() {
          _vendorData!['address'] = newAddress;
          _vendorData!['location'] = GeoPoint(lat, lng);
        });
      }
    }
  }

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
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFFfcfcfc),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              'Edit $label',
              style: const TextStyle(color: Color(0xFFE85205)),
            ),
            content: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: label,
                alignLabelWithHint: true,
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE85205)),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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

  void _editMenuItem(int index) {
    final item = List<Map<String, dynamic>>.from(_vendorData!['menu'])[index];
    final nameController = TextEditingController(text: item['name']);
    final categoryController = TextEditingController(text: item['category']);
    final priceController = TextEditingController(
      text: item['price'].toString(),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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

  //optional image card
  Widget buildOptionalImagesRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _buildImageCardSafe(
            _vendorData?['optionalImageUrl1']?.toString() ?? '',
            'optionalImageUrl1',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildImageCardSafe(
            _vendorData?['optionalImageUrl2']?.toString() ?? '',
            'optionalImageUrl2',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildImageCardSafe(
            _vendorData?['optionalImageUrl3']?.toString() ?? '',
            'optionalImageUrl3',
          ),
        ),
      ],
    );
  }

  Widget _buildImageCardSafe(String imageUrl, String tag) {
    if (imageUrl.isEmpty) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          height: 120,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              color: Colors.grey,
              size: 40,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => Scaffold(
                  backgroundColor: Colors.black,
                  body: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Center(
                      child: Hero(
                        tag: tag,
                        child: InteractiveViewer(
                          child: Image.network(imageUrl, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                ),
          ),
        );
      },
      child: Hero(
        tag: tag,
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 120,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
                  ),
            ),
          ),
        ),
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
      builder:
          (context) => AlertDialog(
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
      builder:
          (ctx) => AlertDialog(
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

    if (confirmed != true) return; // User cancelled

    // Proceed with deletion
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900; // 💻 Desktop threshold
    const brandColor = Color(0xFFE85205);
    const bgColor = Color(0xFFfcfcfc);

    // HEADER IMAGE
    final headerSection = Stack(
      children: [
        if ((_vendorData!['headerImageUrl'] as String?)?.isNotEmpty ?? false)
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
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 250,
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 250,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
          )
        else
          Container(
            height: 250,
            color: Colors.grey[100],
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_not_supported,
              color: Colors.grey,
              size: 40,
            ),
          ),

        if (_isEditing)
          Positioned(
            right: 16,
            bottom: 16,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.image, color: Colors.white),
              label: const Text(
                "Change Image",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                // TODO: implement picker logic
              },
            ),
          ),
      ],
    );

    // LEFT COLUMN (General Info)
    final leftColumn = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerSection, // ✅ always show header here (for both desktop & mobile)
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Text(
                  _vendorData!['name'] ?? '',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 25,
                    color: brandColor,
                  ),
                ),
              ),
              if (_isEditing)
                _smallEditButton(() => _editField('name', 'Name')),
            ],
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              Expanded(
                child: Text(
                  (_vendorData!['tags'] as String?)?.trim().isNotEmpty == true
                      ? _vendorData!['tags']
                      : 'Put your tagline here',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8c8c8c),
                  ),
                ),
              ),
              if (_isEditing)
                _smallEditButton(() => _editField('tags', 'Tags')),
            ],
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'About',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              if (_isEditing)
                _smallEditButton(
                  () => _editField('description', 'Description'),
                ),
            ],
          ),
          ExpandableText(
            _vendorData!['description'] ?? '',
            trimLength: 120,
            style: const TextStyle(fontSize: 14, color: Color(0xFF8C8C8C)),
          ),
          const SizedBox(height: 14),

          _expandableInfoRow(
            Icons.phone,
            _vendorData!['phoneNumber'] ?? '',
            'phoneNumber',
          ),

          Row(
            children: [
              const Icon(Icons.location_on, color: brandColor, size: 20),
              const SizedBox(width: 10),
              Flexible(
                fit: FlexFit.loose,
                child: ExpandableText(
                  _vendorData!['address'] ?? '',
                  trimLength: 50,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8C8C8C),
                  ),
                ),
              ),
              const Spacer(),
              if (_isEditing)
                _smallEditButton(() {
                  _editAddressWithMap();
                }),
            ],
          ),

          _expandableInfoRow(
            Icons.access_time,
            _vendorData!['hours'] ?? '12:00 PM – 12:00 AM',
            'hours',
          ),
          const SizedBox(height: 18),
        ],
      ),
    );

    // RIGHT COLUMN (Menu + Gallery)
    final rightColumn = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Menu (Top 4 Best Seller)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              if (_isEditing)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => MenuManagementPage(
                              vendorData: _vendorData!,
                              onMenuUpdated: (updatedMenu) {
                                setState(() {
                                  _vendorData!['menu'] = updatedMenu;
                                });
                              },
                            ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Add Menu"),
                ),
            ],
          ),
          const SizedBox(height: 8),

          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
              double aspectRatio = constraints.maxWidth > 800 ? 6.5 : 5.5;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount:
                    (_vendorData!['menu'] as List).length > 4
                        ? 4
                        : (_vendorData!['menu'] as List).length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: aspectRatio,
                ),
                itemBuilder: (context, index) {
                  final item = (_vendorData!['menu'] as List)[index];
                  return GestureDetector(
                    onTap: () => _editMenuItem(index),
                    child: Card(
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
                            Text(
                              '|',
                              style: TextStyle(color: Colors.grey[700]),
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
                            Text(
                              '|',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '₱${item['price']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: brandColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 20),
          const Text(
            'Gallery',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          buildOptionalImagesRow(),
          const SizedBox(height: 10),
        ],
      ),
    );

    // ✅ FINAL LAYOUT
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: brandColor,
        title: const Text(
          'Your Restaurant Profile',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            bottomNavIndexNotifier.value = 0;
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.check : Icons.edit,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _isEditing = !_isEditing),
            tooltip: _isEditing ? 'Done Editing' : 'Edit Profile',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: _confirmAndDeleteVendorData,
            tooltip: 'Delete Profile',
          ),
        ],
      ),
      backgroundColor: bgColor,
      body:
          isDesktop
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24, right: 12),
                      child: leftColumn,
                    ),
                  ),
                  Container(
                    width: 1,
                    color: Colors.grey.withAlpha(25),
                    margin: const EdgeInsets.symmetric(vertical: 24),
                  ),
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24, left: 12),
                      child: rightColumn,
                    ),
                  ),
                ],
              )
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [leftColumn, rightColumn],
                ),
              ),
    );
  }

  // Add this helper widget for expandable text
  Widget _expandableInfoRow(IconData icon, String text, String fieldKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFE85205), size: 20),
          const SizedBox(width: 10),

          // Let text expand fully
          Expanded(
            child: ExpandableText(
              text,
              trimLength: 50,
              style: const TextStyle(fontSize: 14, color: Color(0xFF8C8C8C)),
            ),
          ),

          // Edit button always far right
          if (_isEditing)
            _smallEditButton(() {
              if (fieldKey == 'address') {
                _editAddressWithMap(); // special case for address
              } else {
                _editField(fieldKey, _getFieldLabel(fieldKey));
              }
            }),
        ],
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
