// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import '../services/achievement_service.dart';
import '../services/db_service.dart';

class ActivitySection extends StatefulWidget {
  const ActivitySection({super.key});

  @override
  State<ActivitySection> createState() => _ActivitySectionState();
}

class _ActivitySectionState extends State<ActivitySection> {
  final AchievementService _achievementService = AchievementService();

  // Real activity data from database
  Map<DateTime, int> _activityData = {};
  int _totalDhikrSessions = 0;

  // Streak data from AchievementService
  int _currentStreak = 0;
  int _bestStreak = 0;

  bool _isLoading = true;
  String? _errorMessage;

  // Stream subscriptions for real-time updates
  StreamSubscription<BoxEvent>? _dhikrSubscription;
  StreamSubscription<BoxEvent>? _activitySubscription;

  static const Color primaryColor = Color(0xFF0F4C75);
  static const Color secondaryColor = Color(0xFF3282B8);

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupRealTimeListeners();
  }

  @override
  void dispose() {
    _dhikrSubscription?.cancel();
    _activitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Initialize database
      await DbService.init();

      // Initialize achievements service
      await _achievementService.init();

      // Load all data
      await _loadAllData();
    } catch (e) {
      print('Error initializing activity data: $e');
      setState(() {
        _errorMessage = 'Failed to load activity data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _setupRealTimeListeners() {
    try {
      // Listen for dhikr changes (completions, increments, decrements)
      _dhikrSubscription = DbService.watchDhikr().listen((event) {
        // Refresh activity data when dhikr data changes
        _loadActivityDataSilently();
      });

      // Listen for activity data changes (daily resets, manual updates)
      _activitySubscription = DbService.watchActivityData().listen((event) {
        // Refresh activity data when activity snapshots change
        _loadActivityDataSilently();
      });
    } catch (e) {
      print('Error setting up real-time listeners: $e');
      // Continue without real-time updates if listeners fail
    }
  }

  // Silent refresh without loading indicators (for real-time updates)
  Future<void> _loadActivityDataSilently() async {
    try {
      if (!mounted) return;

      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final endOfYear = DateTime(now.year, 12, 31);

      // Get activity data using the new DbService method
      final activityData = await DbService.getActivityDataForDateRange(
        startOfYear,
        endOfYear,
      );

      // Get accurate total using the new DbService method
      final totalSessions = await DbService.getTotalDhikrSessionsForYear();

      // Get updated streak data
      final currentStreak = await _achievementService.getCurrentStreak();
      final bestStreak = await _achievementService.getBestStreak();

      if (mounted) {
        setState(() {
          _activityData = activityData;
          _totalDhikrSessions = totalSessions;
          _currentStreak = currentStreak;
          _bestStreak = bestStreak;
        });
      }
    } catch (e) {
      print('Error in silent activity data refresh: $e');
      // Don't show error for silent updates
    }
  }

  Future<void> _loadAllData() async {
    try {
      // Load activity data
      await _loadActivityData();

      // Load streak data from AchievementService
      await _loadStreakData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading activity data: $e');
      setState(() {
        _errorMessage = 'Failed to load activity data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStreakData() async {
    try {
      final currentStreak = await _achievementService.getCurrentStreak();
      final bestStreak = await _achievementService.getBestStreak();

      setState(() {
        _currentStreak = currentStreak;
        _bestStreak = bestStreak;
      });
    } catch (e) {
      print('Error loading streak data: $e');
      setState(() {
        _currentStreak = 0;
        _bestStreak = 0;
      });
    }
  }

  Future<void> _loadActivityData() async {
    try {
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final endOfYear = DateTime(now.year, 12, 31);

      // Get activity data using the new accurate DbService method
      final activityData = await DbService.getActivityDataForDateRange(
        startOfYear,
        endOfYear,
      );

      // Get accurate total sessions using the new DbService method
      final totalSessions = await DbService.getTotalDhikrSessionsForYear();

      setState(() {
        _activityData = activityData;
        _totalDhikrSessions = totalSessions;
      });

      print(
        'Activity data loaded: ${activityData.length} days, $totalSessions total sessions',
      );
    } catch (e) {
      print('Error loading activity data: $e');
      // Set empty data on error
      setState(() {
        _activityData = {};
        _totalDhikrSessions = 0;
      });
    }
  }

  Future<void> refreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadAllData();
    } catch (e) {
      print('Error refreshing activity data: $e');
      setState(() {
        _errorMessage = 'Failed to refresh activity data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading activity data...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    return _buildActivityGridSection();
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error Loading Activity Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.red[600]),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _initializeData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityGridSection() {
    return RefreshIndicator(
      onRefresh: refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
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
                      Text(
                        '$_totalDhikrSessions dhikr sessions this year',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildCompactStreakInfo(
                      label: 'Current',
                      value: _currentStreak.toString(),
                      color: const Color(0xFF0F4C75),
                    ),
                    const SizedBox(width: 15),
                    _buildCompactStreakInfo(
                      label: 'Best',
                      value: _bestStreak.toString(),
                      color: const Color(0xFF00A8CC),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Activity Grid - Show only relevant 6-month period
            SizedBox(height: 140, child: _buildCurrentSixMonthGrid()),
            const SizedBox(height: 15),
            _buildActivityLegend(),
            const SizedBox(height: 20),
          ],
        ),
      ),
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

  // New method to determine which 6-month grid to show
  Widget _buildCurrentSixMonthGrid() {
    final now = DateTime.now();
    final currentMonth = now.month;

    // If current month is January to June (1-6), show first half
    // If current month is July to December (7-12), show second half
    final isFirstHalf = currentMonth >= 1 && currentMonth <= 6;

    return _buildSixMonthGrid(isFirstHalf: isFirstHalf);
  }

  Widget _buildSixMonthGrid({required bool isFirstHalf}) {
    final now = DateTime.now();
    final year = now.year;
    final startMonth = isFirstHalf ? 1 : 7;
    final endMonth = isFirstHalf ? 6 : 12;

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

              // Activity grid - now properly aligned by month
              Expanded(
                child: _buildCalendarAlignedGrid(
                  startMonth,
                  endMonth,
                  year,
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

  Widget _buildCalendarAlignedGrid(
    int startMonth,
    int endMonth,
    int year,
    double cellSize,
    double cellSpacing,
  ) {
    // Calculate total weeks needed across all months
    int totalWeeks = 0;

    // For each month, calculate how many weeks it spans
    for (int month = startMonth; month <= endMonth; month++) {
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0); // Last day of month
      final daysInMonth = lastDay.day;

      // Calculate starting day of week (0 = Sunday, 6 = Saturday)
      final startDayOfWeek = firstDay.weekday % 7;

      // Calculate weeks needed for this month
      final weeksInMonth = ((startDayOfWeek + daysInMonth - 1) / 7).ceil();
      totalWeeks += weeksInMonth;
    }

    // Build the grid
    return SizedBox(
      height: 7 * (cellSize + cellSpacing) - cellSpacing,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7, // Days of week
          childAspectRatio: 1,
          crossAxisSpacing: cellSpacing,
          mainAxisSpacing: cellSpacing,
        ),
        itemCount: totalWeeks * 7,
        itemBuilder: (context, index) {
          final week = index ~/ 7;
          final dayOfWeek = index % 7;

          // Calculate which month and day this cell represents
          final dateInfo = _getDateForGridPosition(
            week,
            dayOfWeek,
            startMonth,
            endMonth,
            year,
          );

          if (dateInfo == null) {
            // Empty cell (before month start or after month end)
            return Container();
          }

          final currentDate = dateInfo['date'] as DateTime;
          final normalizedDate = DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
          );

          // Check if this is today
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final isToday = normalizedDate.isAtSameMomentAs(today);

          // Get activity level from the new accurate data source
          final activityLevel = _activityData[normalizedDate] ?? 0;

          return GestureDetector(
            onTap: () => _showDateDebugInfo(normalizedDate, activityLevel),
            child: Container(
              decoration: BoxDecoration(
                color: _getActivityColor(activityLevel),
                borderRadius: BorderRadius.circular(3),
                border:
                    isToday ? Border.all(color: primaryColor, width: 1) : null,
              ),
            ),
          );
        },
      ),
    );
  }

  // Debug method to show date information
  void _showDateDebugInfo(DateTime date, int activityLevel) async {
    try {
      final completedCount = await DbService.getCompletedDhikrCountForDate(
        date,
      );
      final dateStr = DateFormat('MMM dd, yyyy').format(date);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$dateStr: $completedCount completed dhikr (level $activityLevel)',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error showing date debug info: $e');
    }
  }

  Map<String, dynamic>? _getDateForGridPosition(
    int week,
    int dayOfWeek,
    int startMonth,
    int endMonth,
    int year,
  ) {
    int currentWeek = 0;

    for (int month = startMonth; month <= endMonth; month++) {
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0);
      final daysInMonth = lastDay.day;

      // Calculate starting day of week (0 = Sunday, 6 = Saturday)
      final startDayOfWeek = firstDay.weekday % 7;

      // Calculate weeks needed for this month
      final weeksInMonth = ((startDayOfWeek + daysInMonth - 1) / 7).ceil();

      if (week >= currentWeek && week < currentWeek + weeksInMonth) {
        // This position is within the current month
        final weekInMonth = week - currentWeek;
        final dayInWeek = dayOfWeek;

        // Calculate the actual day of the month
        final dayOfMonth = (weekInMonth * 7) + dayInWeek - startDayOfWeek + 1;

        // Check if this is a valid day in the month
        if (dayOfMonth >= 1 && dayOfMonth <= daysInMonth) {
          return {'date': DateTime(year, month, dayOfMonth), 'month': month};
        }

        // Invalid day (empty cell)
        return null;
      }

      currentWeek += weeksInMonth;
    }

    return null;
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
        return const Color(0xFFEBEDF0);
      case 1:
        return const Color(0xFF0F4C75).withOpacity(0.3);
      case 2:
        return const Color(0xFF0F4C75).withOpacity(0.5);
      case 3:
        return const Color(0xFF0F4C75).withOpacity(0.7);
      case 4:
      default:
        return const Color(0xFF0F4C75);
    }
  }
}
