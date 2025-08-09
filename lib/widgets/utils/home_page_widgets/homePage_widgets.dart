import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;


// Category Chip Widget
/// Don't know which part of the code this widget is used. Dk what a category chip is lmao.
Widget categoryChip(String label, [bool isSelected = false]) {
  return Padding(
    padding: const EdgeInsets.only(left: 10),
    child: Chip(
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black54,
        fontWeight: FontWeight.w500,
      ),
      avatar:
          isSelected ? const Icon(Icons.fastfood, color: Colors.white) : null,
      backgroundColor: isSelected ? Colors.deepOrangeAccent : Colors.grey[200],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

// Widget restoCard
/// This widget creates a restaurant card with an image, name, description, and additional features like
/// a gradient overlay, rating badge, favorite icon, and a blurred background for the text section
/// - Autopilot

Widget restoCard({
  required String photoUrl,
  required String name,
  required String description,
}) {
  return Container(
    width: 180,
    margin: const EdgeInsets.only(right: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(5),
      image: DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover),
    ),
    child: Stack(
      children: [
        // Gradient Overlay
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withAlpha(25), Colors.black.withAlpha(128)],
            ),
          ),
        ),

        // Optional: Rating Badge
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.deepOrangeAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.star, size: 12, color: Colors.white),
                SizedBox(width: 2),
                Text(
                  "4.5",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        // Favorite Icon
        Positioned(
          top: 8,
          right: 8,
          child: Icon(Icons.favorite_border, color: Colors.white),
        ),

        // Name and Address
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(1),
                  border: Border.all(
                    color: Colors.white.withAlpha(50),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.deepOrangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// Widget sectionHeader
/// This widget creates a section header with a title and a "See All" button
/// - Autopilot

Widget sectionHeader(String title) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      TextButton(onPressed: () {}, child: const Text("See All")),
    ],
  );
}

