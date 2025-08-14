import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RestoDetailScreen extends StatelessWidget {
  final String restoId;
  const RestoDetailScreen({super.key, required this.restoId});

  static const _brand = Color(0xFFE85205);
  static const _bg = Color(0xFFfcfcfc);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brand,
        title: const Text(
          'Restaurant Details',
          style: TextStyle(color: Colors.white, fontSize: 15),
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
          final tags = (data['tags'] ?? 'Bar • Brewery • Gastropub').toString();
          final description = (data['description'] ?? '').toString();
          final phone = (data['phoneNumber'] ?? '').toString();
          final address = (data['address'] ?? '').toString();
          final hours = (data['hours'] ?? '12:00 PM – 12:00 AM').toString();

          // Menu (List<Map<String, dynamic>> expected, but we’ll be defensive)
          final List menuList =
              (data['menu'] is List) ? (data['menu'] as List) : const [];

          // Optional images: support either list field `optionalImageUrl` or individual fields `optionalImageUrl1/2/3`
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
          // Ensure exactly 3 slots
          while (optionalUrls.length < 3) {
            optionalUrls.add('');
          }
          if (optionalUrls.length > 3) {
            optionalUrls = optionalUrls.take(3).toList();
          }

          return SingleChildScrollView(
            child: Column(
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
                      // Name
                      Text(
                        name,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 25,
                          color: _brand,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Tags
                      Text(
                        tags,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8c8c8c),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // About (expandable)
                      const Text(
                        'About',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      ExpandableText(
                        description,
                        trimLength: 120,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8C8C8C),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Info rows (no edit buttons)
                      _infoRow(icon: Icons.phone, text: phone),
                      _infoRow(icon: Icons.location_on, text: address),
                      _infoRow(icon: Icons.access_time, text: hours),

                      const SizedBox(height: 18),

                      // Directions button (no logic, just UI)
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
                          onPressed: () {}, // read-only layout
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Menu header
                      const Text(
                        'Menu',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Menu Grid in the same visual style as owner dashboard
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 800;
                          final crossAxisCount = isWide ? 2 : 1;
                          final aspectRatio = isWide ? 6.5 : 5.5;

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: menuList.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: aspectRatio,
                                ),
                            itemBuilder: (context, index) {
                              final item = menuList[index];
                              final itemName =
                                  (item is Map && item['name'] != null)
                                      ? item['name'].toString()
                                      : (item?.toString() ?? '');
                              final category =
                                  (item is Map && item['category'] != null)
                                      ? item['category'].toString()
                                      : '';
                              final price =
                                  (item is Map && item['price'] != null)
                                      ? item['price'].toString()
                                      : '';

                              return Card(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          itemName,
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
                                          category,
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
                                          price.isEmpty ? '' : '₱$price',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _brand,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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

                // Optional images row (modern elevated cards, tap -> fullscreen)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _optionalImageCard(context, optionalUrls[0]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _optionalImageCard(context, optionalUrls[1]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _optionalImageCard(context, optionalUrls[2]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
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
