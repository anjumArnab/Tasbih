// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/achievement.dart';
import '../services/achievement_service.dart';
import '../widgets/achievement_tile.dart';

class DhikrAchievementsPage extends StatefulWidget {
  const DhikrAchievementsPage({super.key});

  @override
  State<DhikrAchievementsPage> createState() => _DhikrAchievementsPageState();
}

class _DhikrAchievementsPageState extends State<DhikrAchievementsPage> {
  late PageController _pageController;
  int _currentPage = 0;
  String selectedFilter = 'activity'; // Default to activity section

  final AchievementService _achievementService = AchievementService();
  List<Achievement> _achievements = [];
  Map<dynamic, dynamic> _userStats = {};
  bool _isLoading = true;

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
    _initializeAchievements();
  }

  Future<void> _initializeAchievements() async {
    try {
      await _achievementService.init();
      _loadAchievementData();
    } catch (e) {
      print('Error initializing achievements: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadAchievementData() {
    setState(() {
      _achievements = _achievementService.getAllAchievements();
      _userStats = _achievementService.getUserStats();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _achievementService.dispose();
    super.dispose();
  }

  void _applyFilters() {
    // This method can be used for any additional filtering logic if needed
    setState(() {
      // Filter logic here if needed
    });
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
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    // Filter Chips Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          _buildFilterChip('Activity', 'activity'),
                          const SizedBox(width: 10),
                          _buildFilterChip('Achievements', 'achievements'),
                        ],
                      ),
                    ),

                    // Content Section
                    Expanded(
                      child:
                          selectedFilter == 'activity'
                              ? _buildActivityGridSection()
                              : _buildAchievementsSection(),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = value;
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient:
              isSelected
                  ? const LinearGradient(colors: [primaryColor, secondaryColor])
                  : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey[300]!,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementsSection() {
    final unlockedCount = _achievements.where((a) => a.isUnlocked).length;
    final totalCount = _achievements.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Achievement Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
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
                  const SizedBox(height: 2),
                  Text(
                    '$unlockedCount of $totalCount unlocked',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
              // Total Points Display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${_achievementService.getTotalPoints()}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recent Achievement (if any)
          if (_getRecentAchievement() != null) ...[
            _buildRecentAchievementCard(_getRecentAchievement()!),
            const SizedBox(height: 20),
          ],

          // Achievement Categories
          ...AchievementCategory.values.map((category) {
            final categoryAchievements =
                _achievements.where((a) => a.category == category).toList();

            if (categoryAchievements.isEmpty) return const SizedBox.shrink();

            return _buildAchievementCategorySection(
              category,
              categoryAchievements,
            );
          }).toList(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAchievementCategorySection(
    AchievementCategory category,
    List<Achievement> achievements,
  ) {
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _getCategoryColor(category).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getCategoryColor(category).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _getCategoryIcon(category),
                color: _getCategoryColor(category),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _getCategoryDisplayName(category),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _getCategoryColor(category),
                ),
              ),
              const Spacer(),
              Text(
                '$unlockedCount/${achievements.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getCategoryColor(category),
                ),
              ),
            ],
          ),
        ),

        // Achievement Tiles for this category
        ...achievements
            .map((achievement) => AchievementTile(achievement: achievement))
            .toList(),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRecentAchievementCard(Achievement achievement) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.withOpacity(0.1), Colors.blue.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.green, Colors.teal]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.celebration, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🎉 Recently Unlocked!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  achievement.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  achievement.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  '+${achievement.points}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Achievement? _getRecentAchievement() {
    final unlockedAchievements =
        _achievements
            .where((a) => a.isUnlocked && a.unlockedAt != null)
            .toList();

    if (unlockedAchievements.isEmpty) return null;

    // Sort by unlock date and get the most recent
    unlockedAchievements.sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));

    // Return recent achievement if unlocked within last 7 days
    final mostRecent = unlockedAchievements.first;
    final daysSinceUnlock =
        DateTime.now().difference(mostRecent.unlockedAt!).inDays;

    return daysSinceUnlock <= 7 ? mostRecent : null;
  }

  Color _getCategoryColor(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.tasbeh:
        return Colors.blue;
      case AchievementCategory.consistency:
        return Colors.green;
      case AchievementCategory.milestone:
        return Colors.purple;
      case AchievementCategory.special:
        return Colors.orange;
      case AchievementCategory.spiritual:
        return Colors.teal;
    }
  }

  IconData _getCategoryIcon(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.tasbeh:
        return Icons.repeat;
      case AchievementCategory.consistency:
        return Icons.trending_up;
      case AchievementCategory.milestone:
        return Icons.flag;
      case AchievementCategory.special:
        return Icons.star_border;
      case AchievementCategory.spiritual:
        return Icons.self_improvement;
    }
  }

  String _getCategoryDisplayName(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.tasbeh:
        return 'Tasbeh Achievements';
      case AchievementCategory.consistency:
        return 'Consistency Achievements';
      case AchievementCategory.milestone:
        return 'Milestone Achievements';
      case AchievementCategory.special:
        return 'Special Achievements';
      case AchievementCategory.spiritual:
        return 'Spiritual Achievements';
    }
  }

  Widget _buildActivityGridSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
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
                  Text(
                    '${_achievementService.getTotalDhikrCount()} dhikr sessions this year',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildCompactStreakInfo(
                    label: 'Current',
                    value: '${_achievementService.getCurrentStreak()}',
                    color: const Color(0xFF4CAF50),
                  ),
                  const SizedBox(width: 15),
                  _buildCompactStreakInfo(
                    label: 'Best',
                    value: '${_userStats['longest_streak'] ?? 0}',
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
          const SizedBox(height: 20),
        ],
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
