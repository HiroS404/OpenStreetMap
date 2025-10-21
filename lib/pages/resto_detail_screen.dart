import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_try/main.dart';

class RestoDetailScreen extends StatelessWidget {
  final String restoId;
  final ValueNotifier<LatLng?> destinationNotifier;
  const RestoDetailScreen({
    super.key,
    required this.restoId,
    required this.destinationNotifier,
  });

  static const _brand = Color(0xFFE85205);
  static const _bg = Color(0xFFfcfcfc);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900; // 💻 threshold for desktop layout

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brand,
        title: const Text(
          'Restaurant Details',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          tooltip: 'Back to Home',
          onPressed: () {
            bottomNavIndexNotifier.value = 0;
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      backgroundColor: _bg,
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance
                .collection('restaurants')
                .doc(restoId)
                .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Restaurant not found.'));
          }

          final data = (snapshot.data!.data() as Map<String, dynamic>?) ?? {};
          final headerUrl = (data['headerImageUrl'] ?? '').toString();
          final name = (data['name'] ?? '').toString();
          final tags = (data['tags'] ?? '').toString();
          final description = (data['description'] ?? '').toString();
          final phone = (data['phoneNumber'] ?? '').toString();
          final address = (data['address'] ?? '').toString();
          final hours = (data['hours'] ?? 'N/A').toString();
          final List menuList =
              (data['menu'] is List) ? (data['menu'] as List) : const [];

          // Handle optional images
          List<String> optionalUrls = [];
          if (data['optionalImageUrl'] is List) {
            optionalUrls = List<String>.from(
              (data['optionalImageUrl'] as List).map(
                (e) => e?.toString() ?? '',
              ),
            );
          } else {
            optionalUrls = [
              (data['optionalImageUrl1'] ?? data['optionalImage1'] ?? '')
                  .toString(),
              (data['optionalImageUrl2'] ?? data['optionalImage2'] ?? '')
                  .toString(),
              (data['optionalImageUrl3'] ?? data['optionalImage3'] ?? '')
                  .toString(),
            ];
          }
          while (optionalUrls.length < 3) optionalUrls.add('');
          if (optionalUrls.length > 3)
            optionalUrls = optionalUrls.take(3).toList();

          // ✅ Mobile View Layout
          if (!isDesktop) {
            return SingleChildScrollView(
              child: _buildMobileLayout(
                context,
                headerUrl,
                name,
                tags,
                description,
                phone,
                address,
                hours,
                menuList,
                optionalUrls,
                data,
              ),
            );
          }

          // Desktop View Layout (Two Columns)

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT COLUMN — Info, Header, About, Directions
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (headerUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            headerUrl,
                            width: double.infinity,
                            height: 250,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        name,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          color: _brand,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tags,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8c8c8c),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'About',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      ExpandableText(
                        description,
                        trimLength: 200,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8C8C8C),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _infoRow(icon: Icons.phone, text: phone),
                      _infoRow(icon: Icons.location_on, text: address),
                      _infoRow(icon: Icons.access_time, text: hours),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _brand),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.directions, color: _brand),
                          label: const Text(
                            'Go to directionszzz',
                            style: TextStyle(color: _brand),
                          ),
                          onPressed: () {
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ), // Customize color
                              strokeWidth: 4.0, // Customize thickness
                            );
                            final GeoPoint location = data['location'];
                            final LatLng restoLatLng = LatLng(
                              location.latitude,
                              location.longitude,
                            );
                            destinationNotifier.value = restoLatLng;
                            Navigator.pop(context);
                            bottomNavIndexNotifier.value = 1;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 🧭 SUBTLE SEPARATOR
              Container(
                width: 1,
                height: double.infinity,
                color: Colors.grey.withAlpha(30),
                margin: const EdgeInsets.symmetric(vertical: 24),
              ),

              // RIGHT COLUMN — Menu & Optional Images
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Menu',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      buildMenuList(menuList),
                      const SizedBox(height: 30),
                      const Text(
                        'Gallery',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (int i = 0; i < 3; i++) ...[
                            Expanded(
                              child: _optionalImageCard(
                                context,
                                optionalUrls[i],
                              ),
                            ),
                            if (i < 2) const SizedBox(width: 10),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds the mobile view (your original layout)
  Widget _buildMobileLayout(
    BuildContext context,
    String headerUrl,
    String name,
    String tags,
    String description,
    String phone,
    String address,
    String hours,
    List menuList,
    List<String> optionalUrls,
    Map<String, dynamic> data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (headerUrl.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: Image.network(
              headerUrl,
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                  color: _brand,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tags,
                style: const TextStyle(fontSize: 14, color: Color(0xFF8c8c8c)),
              ),
              const SizedBox(height: 12),
              const Text(
                'About',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              ExpandableText(
                description,
                trimLength: 120,
                style: const TextStyle(fontSize: 14, color: Color(0xFF8C8C8C)),
              ),
              const SizedBox(height: 14),
              _infoRow(icon: Icons.phone, text: phone),
              _infoRow(icon: Icons.location_on, text: address),
              _infoRow(icon: Icons.access_time, text: hours),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _brand),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.directions, color: _brand),
                  label: const Text(
                    'Go to directions',
                    style: TextStyle(color: _brand),
                  ),
                  onPressed: () {
                    final GeoPoint location = data['location'];
                    final LatLng restoLatLng = LatLng(
                      location.latitude,
                      location.longitude,
                    );
                    destinationNotifier.value = restoLatLng;
                    Navigator.pop(context);
                    bottomNavIndexNotifier.value = 1;
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Menu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              buildMenuList(menuList),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < 3; i++) ...[
                Expanded(child: _optionalImageCard(context, optionalUrls[i])),
                if (i < 2) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget buildMenuList(List menuList) {
    final groupedMenu = groupMenuByCategory(menuList);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          groupedMenu.entries.map((entry) {
            final category = entry.key;
            final items = entry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category title
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Horizontal gallery of items
                SizedBox(
                  height: 80, // adjust card height
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (context, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final itemName = (item['name'] ?? '').toString();
                      final price = (item['price'] ?? '').toString();

                      return Container(
                        width: 140, // card width
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _brand, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item name
                            Text(
                              itemName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            // Price
                            Text(
                              price.isEmpty ? '' : '₱$price',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _brand,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }

  static Widget _infoRow({required IconData icon, required String text}) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _brand, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF8C8C8C)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _optionalImageCard(BuildContext context, String url) {
    if (url.isEmpty) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[200],
          ),
          child: const Icon(Icons.image, size: 40, color: Colors.grey),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openFullScreen(context, url),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 120,
          child: Image.network(url, fit: BoxFit.cover),
        ),
      ),
    );
  }

  static void _openFullScreen(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => Scaffold(
              backgroundColor: Colors.black,
              body: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Center(
                  child: InteractiveViewer(
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  /// Groups the menu list by category.
  /// Each key = category name, value = list of menu items under that category.
  Map<String, List<Map<String, dynamic>>> groupMenuByCategory(
    List<dynamic> menuList,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var item in menuList) {
      if (item is Map<String, dynamic>) {
        final category = (item['category'] ?? 'Uncategorized').toString();

        if (!grouped.containsKey(category)) {
          grouped[category] = [];
        }
        grouped[category]!.add(item);
      }
    }

    return grouped;
  }
}

/// Simple expandable text (copied from your dashboard style)
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
    final shouldTrim = widget.text.length > widget.trimLength;
    final displayText =
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
                  color: RestoDetailScreen._brand,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
