import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardStats {
  final int totalRestaurants;
  final int totalRoutes;
  final Map<String, int> recentRegistrations; // date -> count

  DashboardStats({
    required this.totalRestaurants,
    required this.totalRoutes,
    required this.recentRegistrations,
  });
}

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get total restaurant count
  Future<int> getTotalRestaurants() async {
    final snapshot = await _firestore.collection('restaurants').get();
    return snapshot.docs.length;
  }

  // Get total routes count
  Future<int> getTotalRoutes() async {
    final snapshot = await _firestore.collection('routes').get();
    return snapshot.docs.length;
  }

  // Get restaurant registrations based on time period
  Future<Map<String, int>> getRecentRegistrations({int days = 7}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(Duration(days: days - 1));

    // Initialize map based on the time period
    final Map<String, int> registrationsByPeriod = {};

    if (days == 1) {
      // For 24 hours, use hourly intervals
      for (int i = 0; i < 24; i++) {
        final hour = now.subtract(Duration(hours: 23 - i));
        final hourKey = '${hour.hour}:00';
        registrationsByPeriod[hourKey] = 0;
      }
    } else {
      // For 7 and 30 days, use daily intervals
      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dateKey = '${date.month}/${date.day}';
        registrationsByPeriod[dateKey] = 0;
      }
    }

    try {
      DateTime queryStartDate;
      if (days == 1) {
        // For 24 hours, go back 24 hours from now
        queryStartDate = now.subtract(const Duration(hours: 24));
      } else {
        queryStartDate = startDate;
      }

      final snapshot =
          await _firestore
              .collection('restaurants')
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(queryStartDate),
              )
              .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['createdAt'] != null) {
          final createdDate = (data['createdAt'] as Timestamp).toDate();

          if (days == 1) {
            // For 24 hours, group by hour
            final hourKey = '${createdDate.hour}:00';
            if (registrationsByPeriod.containsKey(hourKey)) {
              registrationsByPeriod[hourKey] =
                  registrationsByPeriod[hourKey]! + 1;
            }
          } else {
            // For 7 and 30 days, group by day
            final normalizedDate = DateTime(
              createdDate.year,
              createdDate.month,
              createdDate.day,
            );
            final dateKey = '${normalizedDate.month}/${normalizedDate.day}';

            if (registrationsByPeriod.containsKey(dateKey)) {
              registrationsByPeriod[dateKey] =
                  registrationsByPeriod[dateKey]! + 1;
            }
          }
        }
      }
    } catch (e) {
      // If createdAt field doesn't exist or query fails, return empty data
      print('Error fetching recent registrations: $e');
    }

    return registrationsByPeriod;
  }

  // Get all dashboard stats at once
  Future<DashboardStats> getDashboardStats({int days = 7}) async {
    final results = await Future.wait([
      getTotalRestaurants(),
      getTotalRoutes(),
      getRecentRegistrations(days: days),
    ]);

    return DashboardStats(
      totalRestaurants: results[0] as int,
      totalRoutes: results[1] as int,
      recentRegistrations: results[2] as Map<String, int>,
    );
  }

  // Stream version for real-time updates
  Stream<DashboardStats> getDashboardStatsStream({int days = 7}) async* {
    while (true) {
      yield await getDashboardStats(days: days);
      await Future.delayed(
        const Duration(seconds: 30),
      ); // Refresh every 30 seconds
    }
  }
}
