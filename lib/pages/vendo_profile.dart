import 'package:flutter/material.dart';

class VendorProfileScreen extends StatelessWidget {
  final String name;
  final String description;
  final String photoUrl;
  final double latitude;
  final double longtitude;

  const VendorProfileScreen({
    super.key,
    required this.name,
    required this.description,
    required this.photoUrl,
    required this.latitude,
    required this.longtitude,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vendor Profile"),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.edit))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //logo here resto pic foods
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  "https://media.istockphoto.com/id/2156148971/photo/a-variety-of-delicious-home-cooked-filipino-dishes-displayed-on-a-wooden-dining-table-ready.jpg?s=1024x1024&w=is&k=20&c=5H4Hq40UyVGkjJqBA9ZAICqlkCWRIIKOXpBZEAlkZiQ=",
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            //resto name
            Center(
              child: Text(
                name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),

            //descriptiin
            Text(description, style: const TextStyle(fontSize: 16)),
            //location
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(
                "resto location on OSM \nLat: $latitude, Long: $longtitude",
              ),
            ),
            //operating hours??
            const ListTile(
              leading: Icon(Icons.access_time),
              title: Text("Open or close: 10:00 Am - 8:00 pm"),
            ),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.menu_open_rounded),
              title: Text(
                "Menu: (example)\n•	Adobo\n•	Sinigang\n•	Lumpia\n•	Pancit",
              ),
            ),
            // Center(
            //   child: ElevatedButton.icon(
            //     icon: const Icon(Icons.edit),
            //     onPressed: () {},
            //     label: const Text("Edit Profile"),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
