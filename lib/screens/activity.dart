// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:tasbih/widgets/app_snack_bar.dart';
import '../services/db_service.dart';
import '../widgets/rounded_button.dart';

class ActivitySection extends StatefulWidget {
  const ActivitySection({super.key});

  @override
  State<ActivitySection> createState() => _ActivitySectionState();
}

class _ActivitySectionState extends State<ActivitySection> {
  // Real activity data from database
  Map<DateTime, int> _activityData = {};
  int _totalDhikrSessions = 0;

  // Streak data from DbService (single source of truth)
  int _currentStreak = 0;
  int _bestStreak = 0;

  bool _isLoading = true;
  String? _errorMessage;

  // Stream subscriptions for real-time updates
  StreamSubscription<BoxEvent>? _dhikrSubscription;
  StreamSubscription<BoxEvent>? _activitySubscription;

  // Timer for periodic sync
  Timer? _syncTimer;

  // Cache management
  DateTime? _lastDataLoad;
  static const _cacheValidityDuration = Duration(minutes: 1);

  // Separate scroll controllers for grid and month labels
  ScrollController? _gridScrollController;
  ScrollController? _monthLabelScrollController;

  static const Color primaryColor = Color(0xFF0F4C75);

  @override
  void initState() {
    super.initState();
    _gridScrollController = ScrollController();
    _monthLabelScrollController = ScrollController();

    // Sync the scroll controllers
    _setupScrollSync();

    _initializeData();
    _setupRealTimeListeners();
    _setupPeriodicSync();
  }

  @override
  void dispose() {
    _dhikrSubscription?.cancel();
    _activitySubscription?.cancel();
    _syncTimer?.cancel();
    _gridScrollController?.dispose();
    _monthLabelScrollController?.dispose();
    super.dispose();
  }

  void _setupScrollSync() {
    // Sync month labels with grid scrolling
    _gridScrollController?.addListener(() {
      if (_monthLabelScrollController != null &&
          _monthLabelScrollController!.hasClients &&
          _gridScrollController!.hasClients) {
        _monthLabelScrollController!.jumpTo(_gridScrollController!.offset);
      }
    });
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Initialize database
      await DbService.init();

      // Load all data
      await _loadAllData();

      // Auto-scroll to current month after data loads
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentMonth();
      });
    } catch (e) {
      debugPrint('Error initializing activity data: $e');
      setState(() {
        _errorMessage = 'Failed to load activity data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _setupRealTimeListeners() {
    try {
      // Listen for dhikr changes (completions, increments, decrements)
      _dhikrSubscription = DbService.watchDhikr().listen(
        (event) {
          // Refresh activity data when dhikr data changes
          _loadActivityDataSilently();
        },
        onError: (error) {
          debugPrint('Error in dhikr stream: $error');
        },
        cancelOnError: false, // Keep listening even after errors
      );

      // Listen for activity data changes (daily resets, manual updates)
      _activitySubscription = DbService.watchActivityData().listen(
        (event) {
          // Refresh activity data when activity snapshots change
          _loadActivityDataSilently();
        },
        onError: (error) {
          debugPrint('Error in activity stream: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error setting up real-time listeners: $e');
      // Continue without real-time updates if listeners fail
    }
  }

  void _setupPeriodicSync() {
    // Optional: Periodic sync every 5 minutes to ensure data consistency
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) {
        _loadActivityDataSilently(forceRefresh: true);
      }
    });
  }

  // Silent refresh without loading indicators (for real-time updates)
  Future<void> _loadActivityDataSilently({bool forceRefresh = false}) async {
    try {
      if (!mounted) return;

      // Skip if data was loaded recently (unless forced)
      if (!forceRefresh &&
          _lastDataLoad != null &&
          DateTime.now().difference(_lastDataLoad!) < _cacheValidityDuration) {
        return;
      }

      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final endOfYear = DateTime(now.year, 12, 31);

      // Get all data from DbService (single source of truth)
      final activityData = await DbService.getActivityDataForDateRange(
        startOfYear,
        endOfYear,
      );

      // Get accurate total using the new DbService method
      final totalSessions = await DbService.getTotalDhikrSessionsForYear();

      // Get updated streak data directly from DbService
      final streakData = await DbService.getStreakData();

      if (mounted) {
        setState(() {
          _activityData = activityData;
          _totalDhikrSessions = totalSessions;
          _currentStreak = streakData['current'] ?? 0;
          _bestStreak = streakData['best'] ?? 0;
        });
        _lastDataLoad = DateTime.now();
      }
    } catch (e) {
      debugPrint('Error in silent activity data refresh: $e');
      // Don't show error for silent updates
    }
  }

  Future<void> _loadAllData() async {
    try {
      // Load activity data
      await _loadActivityData();

      // Load streak data from DbService
      await _loadStreakData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading activity data: $e');
      setState(() {
        _errorMessage = 'Failed to load activity data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStreakData() async {
    try {
      // Get streak data directly from DbService (single source of truth)
      final streakData = await DbService.getStreakData();

      setState(() {
        _currentStreak = streakData['current'] ?? 0;
        _bestStreak = streakData['best'] ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading streak data: $e');
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

      // Get activity data using the accurate DbService method
      final activityData = await DbService.getActivityDataForDateRange(
        startOfYear,
        endOfYear,
      );

      // Get accurate total sessions using the DbService method
      final totalSessions = await DbService.getTotalDhikrSessionsForYear();

      setState(() {
        _activityData = activityData;
        _totalDhikrSessions = totalSessions;
      });

      _lastDataLoad = DateTime.now();

      debugPrint(
        'Activity data loaded: ${activityData.length} days, $totalSessions total sessions',
      );
    } catch (e) {
      debugPrint('Error loading activity data: $e');
      // Set empty data on error
      setState(() {
        _activityData = {};
        _totalDhikrSessions = 0;
      });
    }
  }

  // Auto-scroll to current month
  void _scrollToCurrentMonth() {
    if (_gridScrollController == null || !_gridScrollController!.hasClients)
      return;

    try {
      final now = DateTime.now();
      final currentMonth = now.month;

      // Determine if we're in first or second half
      final isFirstHalf = currentMonth >= 1 && currentMonth <= 6;
      final startMonth = isFirstHalf ? 1 : 7;

      // Calculate scroll position to current month
      double scrollPosition = 0;
      const cellSize = 16.0;
      const cellSpacing = 3.0;

      for (int month = startMonth; month < currentMonth; month++) {
        final firstDay = DateTime(now.year, month, 1);
        final lastDay = DateTime(now.year, month + 1, 0);
        final daysInMonth = lastDay.day;
        final startDayOfWeek = firstDay.weekday % 7;
        final weeksInMonth = ((startDayOfWeek + daysInMonth - 1) / 7).ceil();

        scrollPosition += weeksInMonth * (cellSize + cellSpacing);
      }

      // Animate to the calculated position
      _gridScrollController!.animateTo(
        scrollPosition,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      debugPrint('Error auto-scrolling to current month: $e');
    }
  }

  Future<void> refreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Clear cache to force fresh data
      _lastDataLoad = null;
      await _loadAllData();
    } catch (e) {
      debugPrint('Error refreshing activity data: $e');
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
            CircularProgressIndicator(color: primaryColor),
            SizedBox(height: 16),
            Text(
              'Loading activity data...',
              style: TextStyle(color: primaryColor),
            ),
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
            Icon(Icons.error_outline, color: Colors.red[700], size: 48),
            const SizedBox(height: 16),
            Text(
              'Error Loading Activity Data',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: TextStyle(color: Colors.red[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            RoundedButton(onTap: _initializeData, text: 'Retry'),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityGridSection() {
    return RefreshIndicator(
      onRefresh: refreshData,
      color: primaryColor,
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
                          color: primaryColor,
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
                      color: primaryColor,
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

            // Activity Grid - Show only relevant 6-month period with horizontal scrolling
            SizedBox(height: 140, child: _buildCurrentSixMonthGrid()),
            const SizedBox(height: 15),
            _buildActivityLegend(),
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

  // Determine which 6-month grid to show
  Widget _buildCurrentSixMonthGrid() {
    final now = DateTime.now();
    final currentMonth = now.month;
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
        Row(
          children: [
            const SizedBox(width: 35),
            Expanded(
              child: SingleChildScrollView(
                controller: _monthLabelScrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children:
                      monthLabels.map((month) {
                        // Calculate width for each month
                        final monthIndex = monthLabels.indexOf(month);
                        final actualMonth = startMonth + monthIndex;
                        final firstDay = DateTime(year, actualMonth, 1);
                        final lastDay = DateTime(year, actualMonth + 1, 0);
                        final daysInMonth = lastDay.day;
                        final startDayOfWeek = firstDay.weekday % 7;
                        final weeksInMonth =
                            ((startDayOfWeek + daysInMonth - 1) / 7).ceil();
                        final monthWidth =
                            weeksInMonth * (cellSize + cellSpacing) -
                            cellSpacing;

                        return SizedBox(
                          width: monthWidth,
                          child: Text(
                            month,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF666666),
                            ),
                          ),
                        );
                      }).toList(),
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

    // Calculate the total width needed for all weeks
    final totalGridWidth = totalWeeks * (cellSize + cellSpacing) - cellSpacing;

    return Scrollbar(
      controller: _gridScrollController,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _gridScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: totalGridWidth,
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

              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final isToday = normalizedDate.isAtSameMomentAs(today);

              final activityLevel = _activityData[normalizedDate] ?? 0;

              return GestureDetector(
                onTap: () => _showDateInfo(normalizedDate, activityLevel),
                child: Container(
                  decoration: BoxDecoration(
                    color: _getActivityColor(activityLevel),
                    borderRadius: BorderRadius.circular(3),
                    border:
                        isToday
                            ? Border.all(color: primaryColor, width: 2)
                            : null,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDateInfo(DateTime date, int activityLevel) async {
    try {
      final completedCount = await DbService.getCompletedDhikrCountForDate(
        date,
      );
      final dateStr = DateFormat('MMM dd, yyyy').format(date);

      if (mounted) {
        AppSnackbar.showActivityStatus(
          context,
          '$dateStr: $completedCount completed dhikr (level $activityLevel)',
        );
      }
    } catch (e) {
      debugPrint('Error showing date debug info: $e');
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
        return primaryColor.withOpacity(0.3);
      case 2:
        return primaryColor.withOpacity(0.5);
      case 3:
        return primaryColor.withOpacity(0.7);
      case 4:
      default:
        return primaryColor;
    }
  }
}
