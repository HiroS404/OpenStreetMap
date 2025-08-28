// ignore: file_names
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MenuManagementPage extends StatefulWidget {
  final Map<String, dynamic> vendorData;
  final Function(List<Map<String, dynamic>>) onMenuUpdated;

  const MenuManagementPage({
    super.key,
    required this.vendorData,
    required this.onMenuUpdated,
  });

  @override
  State<MenuManagementPage> createState() => _MenuManagementPageState();
}

class _MenuManagementPageState extends State<MenuManagementPage> {
  final TextEditingController _menuNameController = TextEditingController();
  final TextEditingController _menuPriceController = TextEditingController();

  final List<String> _categories = [];
  String? _selectedCategory;

  // Group menu items by category
  final Map<String, List<Map<String, dynamic>>> _menuByCategory = {};

  @override
  void initState() {
    super.initState();
    _initializeMenu();
  }

  void _initializeMenu() {
    final currentMenu = List<Map<String, dynamic>>.from(
      widget.vendorData['menu'] ?? [],
    );

    // Group existing menu items by category
    for (var item in currentMenu) {
      final category = item['category'] ?? 'Uncategorized';
      if (!_menuByCategory.containsKey(category)) {
        _menuByCategory[category] = [];
        if (!_categories.contains(category)) {
          _categories.add(category);
        }
      }
      _menuByCategory[category]!.add(item);
    }

    // Set default category if none selected
    if (_selectedCategory == null && _categories.isNotEmpty) {
      _selectedCategory = _categories.first;
    }
  }

  void _addMenuItem() {
    if (_menuNameController.text.isEmpty ||
        _menuPriceController.text.isEmpty ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newItem = {
      'name': _menuNameController.text.trim(),
      'category': _selectedCategory!,
      'price': double.tryParse(_menuPriceController.text.trim()) ?? 0.0,
    };

    setState(() {
      if (!_menuByCategory.containsKey(_selectedCategory!)) {
        _menuByCategory[_selectedCategory!] = [];
      }
      _menuByCategory[_selectedCategory!]!.add(newItem);
    });

    // Clear controllers
    _menuNameController.clear();
    _menuPriceController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menu item added successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeMenuItem(String category, int index) {
    setState(() {
      _menuByCategory[category]!.removeAt(index);
      if (_menuByCategory[category]!.isEmpty) {
        _menuByCategory.remove(category);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menu item removed'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showAddCategoryDialog() {
    final TextEditingController newCategoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFfcfcfc),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            "Add New Category",
            style: TextStyle(color: Color(0xFFE85205)),
          ),
          content: TextField(
            controller: newCategoryController,
            decoration: const InputDecoration(
              labelText: "Category Name",
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE85205)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final newCategory = newCategoryController.text.trim();
                if (newCategory.isNotEmpty &&
                    !_categories.contains(newCategory)) {
                  setState(() {
                    _categories.add(newCategory);
                    _selectedCategory = newCategory;
                  });
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE85205),
              ),
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Flatten the categorized menu back to a simple list
    List<Map<String, dynamic>> flattenedMenu = [];
    _menuByCategory.forEach((category, items) {
      flattenedMenu.addAll(items);
    });

    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(user.uid)
          .update({'menu': flattenedMenu});

      // Update parent widget
      widget.onMenuUpdated(flattenedMenu);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menu saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context); // Return to profile page
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving menu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _menuNameController.dispose();
    _menuPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFE85205),
        title: const Text('Manage Menu', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFfcfcfc),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add Menu Item Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Add Menu Item",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFFE85205),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      items: [
                        ..._categories.map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        ),
                        const DropdownMenuItem(
                          value: 'add_new',
                          child: Row(
                            children: [
                              Icon(Icons.add, color: Color(0xFFE85205)),
                              SizedBox(width: 8),
                              Text("Add New Category"),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == 'add_new') {
                          _showAddCategoryDialog();
                        } else {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFFE85205),
                            width: 2.0,
                          ),
                        ),
                        floatingLabelStyle: TextStyle(color: Color(0xFFE85205)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Name field
                    TextField(
                      controller: _menuNameController,
                      decoration: const InputDecoration(
                        labelText: 'Menu Name',
                        prefixIcon: Icon(Icons.fastfood),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFFE85205),
                            width: 2.0,
                          ),
                        ),
                        floatingLabelStyle: TextStyle(color: Color(0xFFE85205)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Price field
                    TextField(
                      controller: _menuPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFFE85205),
                            width: 2.0,
                          ),
                        ),
                        floatingLabelStyle: TextStyle(color: Color(0xFFE85205)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Add button
                    ElevatedButton.icon(
                      onPressed: _addMenuItem,
                      label: const Text("Add Menu Item"),
                      icon: const Icon(Icons.add),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE85205),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Current Menu Display
            const Text(
              "Current Menu Items",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFFE85205),
              ),
            ),
            const SizedBox(height: 12),

            // Menu items grouped by category
            if (_menuByCategory.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'No menu items yet. Add your first item above!',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              )
            else
              ..._menuByCategory.entries.map((entry) {
                final category = entry.key;
                final items = entry.value;

                final showAsDropdown = items.length > 3;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category header
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.restaurant_menu,
                            color: Color(0xFFE85205),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            category,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFFE85205),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ If more than 3 items → ExpansionTile
                    if (showAsDropdown)
                      ExpansionTile(
                        tilePadding: const EdgeInsets.only(left: 8.0),
                        title: const Text(
                          "Tap to View items",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        children:
                            items.asMap().entries.map((e) {
                              final index = e.key;
                              final item = e.value;

                              return _buildMenuRow(category, index, item);
                            }).toList(),
                      )
                    else
                      // ✅ Otherwise show items directly
                      ...items.asMap().entries.map((e) {
                        final index = e.key;
                        final item = e.value;

                        return _buildMenuRow(category, index, item);
                      }),

                    const Divider(), // divider between categories
                  ],
                );
              }),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton.icon(
              onPressed: _saveToFirebase,
              icon: const Icon(Icons.save),
              label: const Text("Save Menu Changes"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(55),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(String category, int index, Map<String, dynamic> item) {
    final TextEditingController nameController = TextEditingController(
      text: item['name'],
    );
    final TextEditingController priceController = TextEditingController(
      text: item['price'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Menu Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Menu Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedName = nameController.text.trim();
                final updatedPrice =
                    double.tryParse(priceController.text.trim()) ?? 0.0;

                if (updatedName.isEmpty) return;

                setState(() {
                  _menuByCategory[category]![index] = {
                    'name': updatedName,
                    'price': updatedPrice,
                    'category': category,
                  };
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Menu item updated successfully!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuRow(String category, int index, Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Name + Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['name'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Text(
                '₱${item['price']}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),

          // Edit + Delete buttons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _showEditDialog(category, index, item),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeMenuItem(category, index),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
