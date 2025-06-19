import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VendorRestaurantPage extends StatefulWidget {
  const VendorRestaurantPage({super.key});

  @override
  State<VendorRestaurantPage> createState() => _VendorRestaurantPageState();
}

class _VendorRestaurantPageState extends State<VendorRestaurantPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController menuController = TextEditingController();

  final CollectionReference restaurants = FirebaseFirestore.instance.collection(
    'restaurants',
  );

  void addRestaurant() async {
    await restaurants.add({
      'name': nameController.text,
      'description': descriptionController.text,
      'address': addressController.text,
      'menu': menuController.text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    clearForm();
  }

  void updateRestaurant(String id) async {
    await restaurants.doc(id).update({
      'name': nameController.text,
      'description': descriptionController.text,
      'address': addressController.text,
      'menu': menuController.text,
    });
    clearForm();
  }

  void deleteRestaurant(String id) async {
    await restaurants.doc(id).delete();
  }

  void fillForm(Map<String, dynamic> data) {
    nameController.text = data['name'] ?? '';
    descriptionController.text = data['description'] ?? '';
    addressController.text = data['address'] ?? '';
    menuController.text = data['menu'] ?? '';
  }

  void clearForm() {
    nameController.clear();
    descriptionController.clear();
    addressController.clear();
    menuController.clear();
  }

  void showUpdateDialog(String id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                children: [
                  const Text(
                    'Update Restaurant',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildInputField(
                    Icons.restaurant,
                    'Restaurant Name',
                    nameController,
                  ),
                  _buildInputField(
                    Icons.description,
                    'Short Description',
                    descriptionController,
                  ),
                  _buildInputField(
                    Icons.location_on,
                    'Address',
                    addressController,
                  ),
                  _buildInputField(Icons.menu_book, 'Menu', menuController),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.pop(context),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          updateRestaurant(id);
                          Navigator.pop(context);
                        },
                        child: const Text('Update'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildInputField(
    IconData icon,
    String hint,
    TextEditingController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          hintText: hint,
          filled: true,
          fillColor: Colors.white.withAlpha((0.9 * 255).toInt()),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Restaurant overview'),
        backgroundColor: Colors.white.withAlpha((0.1 * 255).toInt()),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 237, 247, 242),
              Color.fromARGB(255, 250, 254, 255),
              // Color(0xFF7AB2D3),
              // Color(0xFF4A628A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
          child: Column(
            children: [
              _buildInputField(
                Icons.restaurant,
                'Restaurant Name',
                nameController,
              ),
              _buildInputField(
                Icons.description,
                'Short Description',
                descriptionController,
              ),
              _buildInputField(Icons.location_on, 'Address', addressController),
              _buildInputField(
                Icons.menu_book,
                'Menu (comma-separated)',
                menuController,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: addRestaurant,
                icon: const Icon(Icons.add),
                label: const Text(
                  "Add Restaurant",
                  style: TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Divider(thickness: 1),
              const SizedBox(height: 5),
              const Text(
                "Restaurants overview",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      restaurants
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text("Restaurants not registered yet."),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final id = docs[index].id;

                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text(data['name'] ?? 'No name'),
                            subtitle: Text(data['description'] ?? ''),
                            trailing: Wrap(
                              spacing: 0,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    fillForm(data);
                                    showUpdateDialog(id);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => deleteRestaurant(id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
