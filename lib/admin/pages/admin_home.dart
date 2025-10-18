import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:map_try/admin/admin_services/admin_dashboard_services.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardService _dashboardService = DashboardService();
  bool _isLoading = true;
  DashboardStats? _stats;
  int _selectedDays = 7; // Default to 7 days

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _dashboardService.getDashboardStats(
        days: _selectedDays,
      );
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getChartTitle() {
    switch (_selectedDays) {
      case 1:
        return 'Restaurant Registrations (Last 24 Hours)';
      case 7:
        return 'Restaurant Registrations (Last 7 Days)';
      case 30:
        return 'Restaurant Registrations (Last 30 Days)';
      default:
        return 'Restaurant Registrations';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Total Restaurants',
                            value: _stats?.totalRestaurants.toString() ?? '0',
                            icon: Icons.restaurant,
                            color: Colors.deepOrange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Total Routes',
                            value: _stats?.totalRoutes.toString() ?? '0',
                            icon: Icons.route,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Recent Registrations Graph
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.trending_up,
                                  color: Colors.purple,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _getChartTitle(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // Time period dropdown
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<int>(
                                    value: _selectedDays,
                                    underline: const SizedBox(),
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.purple,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 1,
                                        child: Text('24 Hours'),
                                      ),
                                      DropdownMenuItem(
                                        value: 7,
                                        child: Text('7 Days'),
                                      ),
                                      DropdownMenuItem(
                                        value: 30,
                                        child: Text('30 Days'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedDays = value;
                                        });
                                        _loadStats();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 300,
                              child: _buildRegistrationsChart(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withAlpha(25), color.withAlpha(13)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationsChart() {
    if (_stats == null || _stats!.recentRegistrations.isEmpty) {
      return const Center(
        child: Text(
          'No registration data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final registrations = _stats!.recentRegistrations;
    final labels = registrations.keys.toList();
    final maxY =
        registrations.values.reduce((a, b) => a > b ? a : b).toDouble();
    final adjustedMaxY = maxY < 5 ? 5.0 : maxY + 2;

    // Adjust label interval based on time period
    double labelInterval;
    if (_selectedDays == 1) {
      labelInterval = 3; // Show every 3 hours for 24-hour view
    } else if (_selectedDays == 30) {
      labelInterval = 4; // Show every 4 days for 30-day view
    } else {
      labelInterval = 1; // Show all days for 7-day view
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.shade300, strokeWidth: 1);
          },
          getDrawingVerticalLine: (value) {
            return FlLine(color: Colors.grey.shade300, strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: labelInterval,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value.toInt() >= 0 && value.toInt() < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      labels[value.toInt()],
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 40,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300),
        ),
        minX: 0,
        maxX: (labels.length - 1).toDouble(),
        minY: 0,
        maxY: adjustedMaxY,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              labels.length,
              (index) => FlSpot(
                index.toDouble(),
                registrations[labels[index]]!.toDouble(),
              ),
            ),
            isCurved: true,
            color: Colors.purple,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.purple,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.purple.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
