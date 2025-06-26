// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DhikrAchievementsPage extends StatefulWidget {
  const DhikrAchievementsPage({super.key});

  @override
  State<DhikrAchievementsPage> createState() => _DhikrAchievementsPageState();
}

class _DhikrAchievementsPageState extends State<DhikrAchievementsPage> {
  late PageController _pageController;
  int _currentPage = 0;

  // Sample data for the activity grid (365 days)
  final List<int> activityData = List.generate(365, (index) {
    // Generate random activity levels (0-4) for demonstration
    return (index % 7 == 0 || index % 11 == 0)
        ? 0
        : (index % 3 == 0)
        ? 3
        : (index % 2 == 0)
        ? 2
        : 1;
  });

  static const Color primaryColor = Color(0xFF0F4C75);
  static const Color secondaryColor = Color(0xFF3282B8);
  static const Color backgroundColor = Color(0xFFF8FBFF);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Achievements',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, secondaryColor],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Activity Grid Section with embedded streaks
              _buildActivityGridSection(),
              const SizedBox(height: 30),

              // Achievements Section
              _buildAchievementsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Achievements',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '5 of 15 unlocked',
          style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
        ),
        const SizedBox(height: 15),

        // Achievement Categories
        _buildAchievementCategory(
          title: 'Milestone Achievements',
          description: 'Complete dhikr count milestones',
          progress: '3/5',
          color: const Color(0xFF4CAF50),
          backgroundColor: const Color(0xFFE8F5E8),
        ),
        const SizedBox(height: 10),
        _buildAchievementCategory(
          title: 'Streak Achievements',
          description: 'Maintain consistent dhikr streaks',
          progress: '2/5',
          color: const Color(0xFFFF9800),
          backgroundColor: const Color(0xFFFFF3E0),
        ),
        const SizedBox(height: 10),
        _buildAchievementCategory(
          title: 'Special Achievements',
          description: 'Unlock through special actions',
          progress: '0/5',
          color: const Color(0xFF9E9E9E),
          backgroundColor: const Color(0xFFF5F5F5),
          isLocked: true,
        ),
        const SizedBox(height: 20),

        // Recent Achievement
        _buildRecentAchievement(),
        const SizedBox(height: 20),

        // View All Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Handle view all achievements
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('View All Achievements tapped!'),
                  backgroundColor: Color(0xFF2E7D32),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'View All Achievements',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementCategory({
    required String title,
    required String description,
    required String progress,
    required Color color,
    required Color backgroundColor,
    bool isLocked = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      isLocked
                          ? const Color(0xFF9E9E9E)
                          : const Color(0xFF2E7D32),
                ),
              ),
              Text(
                progress,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(
              fontSize: 10,
              color:
                  isLocked ? const Color(0xFF9E9E9E) : const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAchievement() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recently Unlocked!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const Text(
                  'Consistent Worshipper',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const Text(
                  'Maintained a 7-day dhikr streak',
                  style: TextStyle(fontSize: 10, color: Color(0xFF666666)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityGridSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dhikr Journey',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F4C75),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '147 dhikr sessions this year',
                  style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                ),
              ],
            ),
            Row(
              children: [
                _buildCompactStreakInfo(
                  label: 'Current',
                  value: '15',
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 15),
                _buildCompactStreakInfo(
                  label: 'Best',
                  value: '32',
                  color: const Color(0xFFFF9800),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Activity grid with horizontal scroll
        SizedBox(
          height: 140,
          child: PageView(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              _buildSixMonthGrid(isFirstHalf: true),
              _buildSixMonthGrid(isFirstHalf: false),
            ],
          ),
        ),
        const SizedBox(height: 15),
        _buildActivityLegend(),
      ],
    );
  }

  Widget _buildCompactStreakInfo({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF666666)),
        ),
      ],
    );
  }

  Widget _buildSixMonthGrid({required bool isFirstHalf}) {
    final now = DateTime.now();
    final year = now.year;
    final startMonth = isFirstHalf ? 1 : 7;
    final endMonth = isFirstHalf ? 6 : 12;

    // Calculate the start date and total days for the 6-month period
    final startDate = DateTime(year, startMonth, 1);
    final endDate = DateTime(year, endMonth + 1, 0); // Last day of end month
    final totalDays = endDate.difference(startDate).inDays + 1;

    // Generate month labels
    final monthLabels = <String>[];
    for (int month = startMonth; month <= endMonth; month++) {
      monthLabels.add(DateFormat('MMM').format(DateTime(year, month)));
    }

    const cellSize = 16.0;
    const cellSpacing = 3.0;

    return Column(
      children: [
        // Month labels
        Row(
          children: [
            const SizedBox(width: 35), // Space for day labels
            ...monthLabels.map(
              (month) => Expanded(
                child: Text(
                  month,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Grid
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day labels
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children:
                    ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                        .map(
                          (day) => SizedBox(
                            height: cellSize,
                            child: Text(
                              day,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(width: 10),

              // Activity grid
              Expanded(
                child: _buildMonthlyGrid(
                  startDate,
                  totalDays,
                  cellSize,
                  cellSpacing,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyGrid(
    DateTime startDate,
    int totalDays,
    double cellSize,
    double cellSpacing,
  ) {
    // Calculate how many weeks we need
    final firstDayOfWeek = startDate.weekday % 7; // Convert to 0=Sunday format
    final totalCells = totalDays + firstDayOfWeek;
    final weeks = (totalCells / 7).ceil();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: weeks,
        childAspectRatio: 1,
        crossAxisSpacing: cellSpacing,
        mainAxisSpacing: cellSpacing,
      ),
      itemCount: weeks * 7,
      itemBuilder: (context, index) {
        final week = index ~/ 7;
        final dayInWeek = index % 7;
        final dayIndex = week * 7 + dayInWeek - firstDayOfWeek;

        // Check if this cell represents a valid day
        if (dayIndex < 0 || dayIndex >= totalDays) {
          return Container(); // Empty cell
        }

        final currentDate = startDate.add(Duration(days: dayIndex));
        final isToday =
            currentDate.year == DateTime.now().year &&
            currentDate.month == DateTime.now().month &&
            currentDate.day == DateTime.now().day;

        return Container(
          decoration: BoxDecoration(
            color: _getActivityColor(
              activityData[dayIndex % activityData.length],
            ),
            borderRadius: BorderRadius.circular(3),
            border: isToday ? Border.all(color: primaryColor, width: 2) : null,
          ),
          child:
              isToday
                  ? const Center(
                    child: Icon(Icons.circle, size: 4, color: Colors.white),
                  )
                  : null,
        );
      },
    );
  }

  Widget _buildActivityLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Less',
          style: TextStyle(fontSize: 10, color: Color(0xFF666666)),
        ),
        const SizedBox(width: 8),
        ...[0, 1, 2, 3, 4].map(
          (level) => Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              color: _getActivityColor(level),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'More',
          style: TextStyle(fontSize: 10, color: Color(0xFF666666)),
        ),
      ],
    );
  }

  Color _getActivityColor(int level) {
    switch (level) {
      case 0:
        return const Color(0xFFEBEDF0); // Light gray for no activity
      case 1:
        return const Color(0xFF0F4C75).withOpacity(0.3); // Light primary color
      case 2:
        return const Color(0xFF0F4C75).withOpacity(0.5); // Medium primary color
      case 3:
        return const Color(0xFF0F4C75).withOpacity(0.7); // Darker primary color
      case 4:
        return const Color(0xFF0F4C75); // Full primary color
      default:
        return const Color(0xFFEBEDF0);
    }
  }
}
