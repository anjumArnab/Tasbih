import 'package:flutter/material.dart';
import '../services/db_service.dart';

class TasbihDrawer extends StatefulWidget {
  const TasbihDrawer({super.key});

  @override
  State<TasbihDrawer> createState() => _TasbihDrawerState();
}

class _TasbihDrawerState extends State<TasbihDrawer> {
  int _todayCount = 0;
  int _currentStreak = 0;
  int _totalCount = 0;
  int _completedDhikrs = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      await DbService.init();
      final allDhikrs = DbService.getAllDhikr();

      int todayCount = 0;
      int totalCount = 0;
      int completedDhikrs = 0;

      final today = DateTime.now();

      for (var dhikr in allDhikrs) {
        final currentCount = dhikr.currentCount ?? 0;
        totalCount += currentCount;

        if (currentCount >= dhikr.times) {
          completedDhikrs++;
        }

        if (dhikr.when.day == today.day &&
            dhikr.when.month == today.month &&
            dhikr.when.year == today.year) {
          todayCount += currentCount;
        }
      }

      int streak = await _calculateStreak();

      if (mounted) {
        setState(() {
          _todayCount = todayCount;
          _currentStreak = streak;
          _totalCount = totalCount;
          _completedDhikrs = completedDhikrs;
        });
      }
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  Future<int> _calculateStreak() async {
    final allDhikrs = DbService.getAllDhikr();

    if (allDhikrs.isEmpty) return 0;

    // Get all unique dates when user used the app (had any dhikr activity)
    Set<DateTime> activeDates = {};

    for (var dhikr in allDhikrs) {
      if ((dhikr.currentCount ?? 0) > 0) {
        // Normalize to date only (remove time component)
        final dateOnly = DateTime(
          dhikr.when.year,
          dhikr.when.month,
          dhikr.when.day,
        );
        activeDates.add(dateOnly);
      }
    }

    if (activeDates.isEmpty) return 0;

    // Sort dates in descending order (most recent first)
    List<DateTime> sortedDates =
        activeDates.toList()..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    int streak = 0;
    DateTime checkDate = todayNormalized;

    // Check if user was active today, if not, start from yesterday
    if (!activeDates.contains(todayNormalized)) {
      checkDate = todayNormalized.subtract(const Duration(days: 1));
    }

    // Count consecutive days backwards from today (or yesterday if not active today)
    while (activeDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Simple header
              const Text(
                'Statistics',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 32),

              // Stats
              _buildStatRow('Today', _todayCount.toString()),
              _buildStatRow('Streak', '$_currentStreak days'),
              _buildStatRow('Total', _totalCount.toString()),
              _buildStatRow('Completed', _completedDhikrs.toString()),

              const SizedBox(height: 40),

              // Divider
              Container(height: 1, color: Colors.grey[200]),

              const SizedBox(height: 40),

              // Menu items
              _buildMenuItem('Settings', () {
                Navigator.pop(context);
                // Navigate to settings
              }),

              const SizedBox(height: 16),

              _buildMenuItem('About', () {
                Navigator.pop(context);
                _showAboutDialog(context);
              }),

              const Spacer(),

              // Simple footer
              Text(
                'Tasbih Counter',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('About'),
            content: const Text(
              'A simple tasbih counter for your daily dhikr practice.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
