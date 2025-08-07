import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/achievement.dart';
import '../services/achievement_service.dart';
import '../services/db_service.dart';
import '../widgets/achievement_tile.dart';

class AchievementsSection extends StatefulWidget {
  const AchievementsSection({super.key});

  @override
  State<AchievementsSection> createState() => _AchievementsSectionState();
}

class _AchievementsSectionState extends State<AchievementsSection> {
  final AchievementService _achievementService = AchievementService();
  List<Achievement> _achievements = [];
  List<Achievement> _unlockedAchievements = [];
  Map<dynamic, dynamic> _userStats = {};
  bool _isLoading = true;
  String? _errorMessage;

  static const Color primaryColor = Color(0xFF0F4C75);

  @override
  void initState() {
    super.initState();
    _initializeData();
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

      // Load achievement data
      await _loadAchievementData();
    } catch (e) {
      print('Error initializing achievements data: $e');
      setState(() {
        _errorMessage = 'Failed to load achievements data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAchievementData() async {
    try {
      // Recalculate achievements to ensure they're up to date
      await _achievementService.recalculateAchievements();

      setState(() {
        _achievements = _achievementService.getAllAchievements();
        _unlockedAchievements = _achievementService.getUnlockedAchievements();
        _userStats = _achievementService.getUserStats();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading achievement data: $e');
      setState(() {
        _errorMessage = 'Failed to load achievement data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> refreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadAchievementData();
    } catch (e) {
      print('Error refreshing achievements data: $e');
      setState(() {
        _errorMessage = 'Failed to refresh achievements data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    return _buildAchievementsSection();
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
              'Error Loading Achievements Data',
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
      ),
    );
  }

  Widget _buildAchievementsSection() {
    final unlockedCount = _unlockedAchievements.length;
    final totalCount = _achievements.length;
    final totalPoints = _achievementService.getTotalPoints();

    return RefreshIndicator(
      onRefresh: refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Achievement Header with Stats
            _buildAchievementHeader(unlockedCount, totalCount, totalPoints),
            const SizedBox(height: 20),

            // Recent Achievement (if any)
            if (_getRecentAchievement() != null) ...[
              _buildRecentAchievementCard(_getRecentAchievement()!),
              const SizedBox(height: 20),
            ],

            // Achievement Categories
            ...AchievementCategory.values.map((category) {
              final categoryAchievements = _achievementService
                  .getAchievementsByCategory(category);

              if (categoryAchievements.isEmpty) return const SizedBox.shrink();

              return _buildAchievementCategorySection(
                category,
                categoryAchievements,
              );
            }).toList(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementHeader(
    int unlockedCount,
    int totalCount,
    int totalPoints,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
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
                style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
              ),
              if (totalCount > 0) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: unlockedCount / totalCount,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Total Points Display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                '$totalPoints',
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
          padding: const EdgeInsets.symmetric(vertical: 8),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unlockedCount/${achievements.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getCategoryColor(category),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Achievement Tiles for this category
        ...achievements
            .map(
              (achievement) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AchievementTile(achievement: achievement),
              ),
            )
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
                  'Recently Unlocked!',
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
                if (achievement.unlockedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Unlocked ${_formatDate(achievement.unlockedAt!)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF888888),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
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
    if (_unlockedAchievements.isEmpty) return null;

    // Sort by unlock date and get the most recent
    final sortedAchievements = List<Achievement>.from(_unlockedAchievements);
    sortedAchievements.sort((a, b) {
      if (a.unlockedAt == null && b.unlockedAt == null) return 0;
      if (a.unlockedAt == null) return 1;
      if (b.unlockedAt == null) return -1;
      return b.unlockedAt!.compareTo(a.unlockedAt!);
    });

    final mostRecent = sortedAchievements.first;
    if (mostRecent.unlockedAt == null) return null;

    // Return recent achievement if unlocked within last 7 days
    final daysSinceUnlock =
        DateTime.now().difference(mostRecent.unlockedAt!).inDays;
    return daysSinceUnlock <= 7 ? mostRecent : null;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'today';
    } else if (difference == 1) {
      return 'yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  Color _getCategoryColor(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.tasbeh:
        return Colors.blue;
      case AchievementCategory.consistency:
        return Colors.green;
      case AchievementCategory.milestone:
        return Colors.purple;
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
    }
  }

  String _getCategoryDisplayName(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.tasbeh:
        return 'Tasbih';
      case AchievementCategory.consistency:
        return 'Consistency';
      case AchievementCategory.milestone:
        return 'Milestone';
    }
  }
}
