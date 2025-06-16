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
    nameController.text = data['name'];
    descriptionController.text = data['description'];
    addressController.text = data['address'];
    menuController.text = data['menu'];
  }

  void clearForm() {
    nameController.clear();
    descriptionController.clear();
    addressController.clear();
    menuController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant Registration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Restaurant Name'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Short Description'),
            ),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            TextField(
              controller: menuController,
              decoration: const InputDecoration(
                labelText: 'Menu (comma-separated)',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: addRestaurant,
              child: const Text('Add Restaurant'),
            ),
            const Divider(),
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
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final id = docs[index].id;
                      return Card(
                        child: ListTile(
                          title: Text(data['name'] ?? 'No name'),
                          subtitle: Text(data['description'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  fillForm(data);
                                  showDialog(
                                    context: context,
                                    builder:
                                        (_) => AlertDialog(
                                          title: const Text(
                                            'Update Restaurant',
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                controller: nameController,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          'Restaurant Name',
                                                    ),
                                              ),
                                              TextField(
                                                controller:
                                                    descriptionController,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          'Short Description',
                                                    ),
                                              ),
                                              TextField(
                                                controller: addressController,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Address',
                                                    ),
                                              ),
                                              TextField(
                                                controller: menuController,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Menu',
                                                    ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                updateRestaurant(id);
                                                Navigator.pop(context);
                                              },
                                              child: const Text('Update'),
                                            ),
                                          ],
                                        ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
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
    );
  }
}
