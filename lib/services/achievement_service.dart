import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/achievement.dart';
import '../models/dhikr.dart';
import '../data/init_achievement_data.dart';
import '../services/db_service.dart';

class AchievementService {
  static const String _achievementBoxName = 'achievements';
  static const String _userStatsBoxName = 'user_stats';

  late Box<Achievement> _achievementBox;
  late Box<Map<dynamic, dynamic>> _userStatsBox;

  Future<void> init() async {
    _achievementBox = await Hive.openBox<Achievement>(_achievementBoxName);
    _userStatsBox = await Hive.openBox<Map<dynamic, dynamic>>(
      _userStatsBoxName,
    );

    // Initialize achievements if empty
    if (_achievementBox.isEmpty) {
      await _initializeAchievements();
    }

    // Initialize user stats if empty
    if (_userStatsBox.isEmpty) {
      await _initializeUserStats();
    }
  }

  Future<void> _initializeAchievements() async {
    final initialAchievements = InitAchievementData.getInitialAchievements();
    for (var achievement in initialAchievements) {
      await _achievementBox.put(achievement.id, achievement);
    }
  }

  Future<void> _initializeUserStats() async {
    await _userStatsBox.put(_userStatsBoxName, {
      'total_dhikr_count': 0,
      'total_points': 0,
      'dhikr_counts': {
        'SubhanAllah': 0,
        'Alhamdulillah': 0,
        'Allahu Akbar': 0,
        'Astaghfirullah': 0,
        'La ilaha illa Allah': 0,
      },
    });
  }

  /// Get current streak from DbService
  Future<int> getCurrentStreak() async {
    return await DbService.getCurrentStreak();
  }

  /// Get best streak from DbService
  Future<int> getBestStreak() async {
    return await DbService.getBestStreak();
  }

  /// Get streak data from DbService
  Future<Map<String, int>> getStreakData() async {
    return await DbService.getStreakData();
  }

  /// Update dhikr count
  Future<List<Achievement>> updateDhikrCount(
    Dhikr dhikr,
    // int incrementCount,
  ) async {
    final newlyUnlockedAchievements = <Achievement>[];

    // Update user stats
    final userStats = _userStatsBox.get('user_stats') ?? {};

    // Update total dhikr count
    userStats['total_dhikr_count'] += (userStats['total_dhikr_count'] ?? 0);

    // Update specific dhikr counts
    final dhikrCounts = Map<String, dynamic>.from(
      userStats['dhikr_counts'] ?? {},
    );
    final dhikrKey = _mapDhikrTitle(dhikr.dhikrTitle);
    dhikrCounts[dhikrKey] += (dhikrCounts[dhikrKey] ?? 0);
    userStats['dhikr_counts'] = dhikrCounts;

    await _userStatsBox.put('user_stats', userStats);

    // Check achievements
    await _checkAndUnlockAchievements(userStats, newlyUnlockedAchievements);

    return newlyUnlockedAchievements;
  }

  // Enhanced method to check achievements based on dhikr data
  Future<void> _checkAndUnlockAchievements(
    Map<dynamic, dynamic> userStats,
    List<Achievement> newlyUnlockedAchievements,
  ) async {
    final achievements = _achievementBox.values.toList();

    // Get current dhikr counts from the dhikr database
    final allDhikr = DbService.getAllDhikr();
    final actualDhikrCounts = _calculateDhikrCounts(allDhikr);

    for (var achievement in achievements) {
      if (!achievement.isUnlocked) {
        bool shouldUnlock = false;
        int currentProgress = 0;

        switch (achievement.type) {
          case AchievementType.count:
            final result = _checkCountAchievement(
              achievement,
              actualDhikrCounts,
              userStats,
            );
            shouldUnlock = result['shouldUnlock'];
            currentProgress = result['currentProgress'];
            break;
          case AchievementType.streak:
            final result = await _checkStreakAchievement(
              achievement,
              userStats,
            );
            shouldUnlock = result['shouldUnlock'];
            currentProgress = result['currentProgress'];
            break;
        }

        // Update achievement progress
        final updatedAchievement = achievement.copyWith(
          currentProgress: currentProgress,
          isUnlocked: shouldUnlock,
          unlockedAt: shouldUnlock ? DateTime.now() : null,
        );

        await _achievementBox.put(achievement.id, updatedAchievement);

        if (shouldUnlock && !achievement.isUnlocked) {
          newlyUnlockedAchievements.add(updatedAchievement);

          // Add points
          userStats['total_points'] =
              (userStats['total_points'] ?? 0) + achievement.points;
          await _userStatsBox.put('user_stats', userStats);
        }
      }
    }
  }

  // Calculate dhikr counts
  Map<String, int> _calculateDhikrCounts(List<Dhikr> allDhikr) {
    final counts = <String, int>{
      'SubhanAllah': 0,
      'Alhamdulillah': 0,
      'Allahu Akbar': 0,
      'Astaghfirullah': 0,
      'La ilaha illa Allah': 0,
    };

    int totalCount = 0;

    for (final dhikr in allDhikr) {
      final currentCount = dhikr.currentCount ?? 0;
      totalCount += currentCount;

      final dhikrKey = _mapDhikrTitle(dhikr.dhikrTitle);
      if (counts.containsKey(dhikrKey)) {
        counts[dhikrKey] = counts[dhikrKey]! + currentCount;
      }
    }

    counts['All'] = totalCount;
    return counts;
  }

  /// Count achievement
  Map<String, dynamic> _checkCountAchievement(
    Achievement achievement,
    Map<String, int> actualDhikrCounts,
    Map<dynamic, dynamic> userStats,
  ) {
    int currentProgress = 0;
    bool shouldUnlock = false;

    switch (achievement.dhikrType) {
      case 'All':
        currentProgress = actualDhikrCounts['All'] ?? 0;
        shouldUnlock = currentProgress >= achievement.targetCount;
        break;
      case 'SubhanAllah':
      case 'Alhamdulillah':
      case 'Allahu Akbar':
      case 'Astaghfirullah':
      case 'La ilaha illa Allah':
        currentProgress = actualDhikrCounts[achievement.dhikrType] ?? 0;
        shouldUnlock = currentProgress >= achievement.targetCount;
        break;
    }

    return {'shouldUnlock': shouldUnlock, 'currentProgress': currentProgress};
  }

  /// Streak achievement
  Future<Map<String, dynamic>> _checkStreakAchievement(
    Achievement achievement,
    Map<dynamic, dynamic> userStats,
  ) async {
    final streakData = await getStreakData();
    final currentStreak = streakData['current'] ?? 0;
    final bestStreak = streakData['best'] ?? 0;

    // Use the highest streak for achievement checking
    final streakToCheck =
        currentStreak > bestStreak ? currentStreak : bestStreak;

    return {
      'shouldUnlock': streakToCheck >= achievement.targetCount,
      'currentProgress': currentStreak, // Show current streak as progress
    };
  }

  String _mapDhikrTitle(String dhikrTitle) {
    switch (dhikrTitle.toLowerCase()) {
      case 'subhan allah':
        return 'SubhanAllah';
      case 'alhamdulillah':
        return 'Alhamdulillah';
      case 'allahu akbar':
        return 'Allahu Akbar';
      case 'astaghfirullah':
        return 'Astaghfirullah';
      case 'la ilaha illa allah':
        return 'La ilaha illa Allah';
      case 'salawat':
        return 'Salawat';
      case 'dua':
        return 'Dua';
      case 'adhkar':
        return 'Adhkar';
      default:
        return dhikrTitle;
    }
  }

  // Calculate achievements
  Future<void> calculateAchievements() async {
    final userStats = _userStatsBox.get('user_stats') ?? {};
    final newlyUnlockedAchievements = <Achievement>[];

    await _checkAndUnlockAchievements(userStats, newlyUnlockedAchievements);
  }

  // Getter methods
  List<Achievement> getAllAchievements() {
    return _achievementBox.values.toList();
  }

  List<Achievement> getUnlockedAchievements() {
    return _achievementBox.values
        .where((achievement) => achievement.isUnlocked)
        .toList();
  }

  List<Achievement> getAchievementsByCategory(AchievementCategory category) {
    return _achievementBox.values
        .where((achievement) => achievement.category == category)
        .toList();
  }

  Map<dynamic, dynamic> getUserStats() {
    return _userStatsBox.get('user_stats') ?? {};
  }

  int getTotalPoints() {
    final userStats = getUserStats();
    return userStats['total_points'] ?? 0;
  }

  int getTotalDhikrCount() {
    final userStats = getUserStats();
    return userStats['total_dhikr_count'] ?? 0;
  }

  // Cleanup method
  Future<void> dispose() async {
    try {
      if (_achievementBox.isOpen) {
        await _achievementBox.close();
      }
      if (_userStatsBox.isOpen) {
        await _userStatsBox.close();
      }
      debugPrint('AchievementService disposed successfully');
    } catch (e) {
      debugPrint('Error disposing AchievementService: $e');
    }
  }
}
