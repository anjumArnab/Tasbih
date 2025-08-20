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
    await _userStatsBox.put('user_stats', {
      'total_dhikr_count': 0,
      'total_points': 0,
      'dhikr_counts': {
        'SubhanAllah': 0,
        'Alhamdulillah': 0,
        'Allahu Akbar': 0,
        'Astaghfirullah': 0,
        'La ilaha illa Allah': 0,
        'Salawat': 0,
        'Dua': 0,
        'Adhkar': 0,
      },
      'special_achievements': {
        'fajr_dhikr_dates': <String>[],
        'maghrib_dhikr_dates': <String>[],
        'friday_dhikr_weeks': <String>[],
        'ramadan_dhikr_count': 0,
        'morning_evening_streak': 0,
        'tahajjud_dhikr_count': 0,
      },
    });
  }

  /// Get current streak from DbService (READ ONLY)
  Future<int> getCurrentStreak() async {
    return await DbService.getCurrentStreak();
  }

  /// Get best streak from DbService (READ ONLY)
  Future<int> getBestStreak() async {
    return await DbService.getBestStreak();
  }

  /// Get streak data from DbService (READ ONLY)
  Future<Map<String, int>> getStreakData() async {
    return await DbService.getStreakData();
  }

  /// Enhanced updateDhikrCount that integrates with DbService
  /// NOTE: Streak logic is handled entirely by DbService
  Future<List<Achievement>> updateDhikrCount(
    Dhikr dhikr,
    int incrementCount,
  ) async {
    final newlyUnlockedAchievements = <Achievement>[];

    // Update user stats
    final userStats = _userStatsBox.get('user_stats') ?? {};

    // Update total dhikr count
    userStats['total_dhikr_count'] =
        (userStats['total_dhikr_count'] ?? 0) + incrementCount;

    // Update specific dhikr counts
    final dhikrCounts = Map<String, dynamic>.from(
      userStats['dhikr_counts'] ?? {},
    );
    final dhikrKey = _mapDhikrTitle(dhikr.dhikrTitle);
    dhikrCounts[dhikrKey] = (dhikrCounts[dhikrKey] ?? 0) + incrementCount;
    userStats['dhikr_counts'] = dhikrCounts;

    await _userStatsBox.put('user_stats', userStats);

    // NOTE: Streak logic is now handled entirely by DbService
    // This method only updates achievement-specific stats

    // Check achievements
    await _checkAndUnlockAchievements(userStats, newlyUnlockedAchievements);

    return newlyUnlockedAchievements;
  }

  // Enhanced method to check achievements based on actual dhikr data
  Future<void> _checkAndUnlockAchievements(
    Map<dynamic, dynamic> userStats,
    List<Achievement> newlyUnlockedAchievements,
  ) async {
    final achievements = _achievementBox.values.toList();

    // Get current dhikr counts from the actual dhikr database
    final allDhikr = DbService.getAllDhikr();
    final actualDhikrCounts = _calculateActualDhikrCounts(allDhikr);

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
          case AchievementType.time:
            final result = _checkTimeAchievement(achievement, userStats);
            shouldUnlock = result['shouldUnlock'];
            currentProgress = result['currentProgress'];
            break;
          case AchievementType.special:
            final result = _checkSpecialAchievement(achievement, userStats);
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

    // Check master achievement
    await _checkMasterAchievement(newlyUnlockedAchievements);
  }

  // Calculate actual dhikr counts from the dhikr database
  Map<String, int> _calculateActualDhikrCounts(List<Dhikr> allDhikr) {
    final counts = <String, int>{
      'SubhanAllah': 0,
      'Alhamdulillah': 0,
      'Allahu Akbar': 0,
      'Astaghfirullah': 0,
      'La ilaha illa Allah': 0,
      'Salawat': 0,
      'Dua': 0,
      'Adhkar': 0,
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
      case 'Salawat':
      case 'Dua':
      case 'Adhkar':
        currentProgress = actualDhikrCounts[achievement.dhikrType] ?? 0;
        shouldUnlock = currentProgress >= achievement.targetCount;
        break;
      case 'Balanced':
        // For perfect balance achievement
        final subhanCount = actualDhikrCounts['SubhanAllah'] ?? 0;
        final alhamdCount = actualDhikrCounts['Alhamdulillah'] ?? 0;
        final akbarCount = actualDhikrCounts['Allahu Akbar'] ?? 0;

        currentProgress = [
          subhanCount,
          alhamdCount,
          akbarCount,
        ].reduce((a, b) => a < b ? a : b);
        shouldUnlock =
            subhanCount >= achievement.targetCount &&
            alhamdCount >= achievement.targetCount &&
            akbarCount >= achievement.targetCount;
        break;
    }

    return {'shouldUnlock': shouldUnlock, 'currentProgress': currentProgress};
  }

  Map<String, dynamic> _checkTimeAchievement(
    Achievement achievement,
    Map<dynamic, dynamic> userStats,
  ) {
    int currentProgress = 0;
    bool shouldUnlock = false;

    switch (achievement.id) {
      case 'fajr_time':
        final specialStats = Map<String, dynamic>.from(
          userStats['special_achievements'] ?? {},
        );
        final fajrDates = List<String>.from(
          specialStats['fajr_dhikr_dates'] ?? [],
        );
        currentProgress = fajrDates.length;
        shouldUnlock = currentProgress >= achievement.targetCount;
        break;
      case 'maghrib_time':
        final specialStats = Map<String, dynamic>.from(
          userStats['special_achievements'] ?? {},
        );
        final maghribDates = List<String>.from(
          specialStats['maghrib_dhikr_dates'] ?? [],
        );
        currentProgress = maghribDates.length;
        shouldUnlock = currentProgress >= achievement.targetCount;
        break;
      case 'early_morning':
      case 'late_night':
        currentProgress = userStats['total_dhikr_count'] ?? 0;
        shouldUnlock = currentProgress >= achievement.targetCount;
        break;
      default:
        // For other time-based achievements, use streak data
        // This will be handled by the streak achievements instead
        currentProgress = 0;
        shouldUnlock = false;
    }

    return {'shouldUnlock': shouldUnlock, 'currentProgress': currentProgress};
  }

  /// Enhanced streak achievement checking using DbService data
  Future<Map<String, dynamic>> _checkStreakAchievement(
    Achievement achievement,
    Map<dynamic, dynamic> userStats,
  ) async {
    // Get streak data from DbService (single source of truth)
    final streakData = await getStreakData();
    final currentStreak = streakData['current'] ?? 0;
    final bestStreak = streakData['best'] ?? 0;

    // Use the highest streak (either current or best) for achievement checking
    final streakToCheck =
        currentStreak > bestStreak ? currentStreak : bestStreak;

    return {
      'shouldUnlock': streakToCheck >= achievement.targetCount,
      'currentProgress': currentStreak, // Show current streak as progress
    };
  }

  Map<String, dynamic> _checkSpecialAchievement(
    Achievement achievement,
    Map<dynamic, dynamic> userStats,
  ) {
    final specialStats = Map<String, dynamic>.from(
      userStats['special_achievements'] ?? {},
    );

    int currentProgress = 0;
    bool shouldUnlock = false;

    switch (achievement.id) {
      case 'fajr_dhikr':
        final fajrDates = List<String>.from(
          specialStats['fajr_dhikr_dates'] ?? [],
        );
        currentProgress = fajrDates.length;
        shouldUnlock = currentProgress >= achievement.targetCount;
        break;
      case 'maghrib_dhikr':
        final maghribDates = List<String>.from(
          specialStats['maghrib_dhikr_dates'] ?? [],
        );
        currentProgress = maghribDates.length;
        shouldUnlock = currentProgress >= achievement.targetCount;
        break;
      case 'friday_blessing':
        final fridayWeeks = List<String>.from(
          specialStats['friday_dhikr_weeks'] ?? [],
        );
        currentProgress = fridayWeeks.length;
        shouldUnlock = currentProgress >= achievement.targetCount;
        break;
      case 'morning_evening':
        currentProgress = specialStats['morning_evening_streak'] ?? 0;
        shouldUnlock = currentProgress >= achievement.targetCount;
        break;
      case 'ramadan_dedication':
        currentProgress = specialStats['ramadan_dhikr_count'] ?? 0;
        shouldUnlock = currentProgress >= achievement.targetCount;
        break;
      case 'tahajjud_warrior':
        currentProgress = specialStats['tahajjud_dhikr_count'] ?? 0;
        shouldUnlock = currentProgress >= achievement.targetCount;
        break;
      default:
        currentProgress = userStats['total_dhikr_count'] ?? 0;
        shouldUnlock = currentProgress >= achievement.targetCount;
    }

    return {'shouldUnlock': shouldUnlock, 'currentProgress': currentProgress};
  }

  Future<void> _checkMasterAchievement(List<Achievement> newlyUnlocked) async {
    final masterAchievement = _achievementBox.get('dhikr_master');
    if (masterAchievement != null && !masterAchievement.isUnlocked) {
      final totalUnlocked =
          _achievementBox.values
              .where((a) => a.isUnlocked && a.id != 'dhikr_master')
              .length;

      if (totalUnlocked >= 29) {
        final unlockedMaster = masterAchievement.copyWith(
          isUnlocked: true,
          unlockedAt: DateTime.now(),
        );
        await _achievementBox.put('dhikr_master', unlockedMaster);
        newlyUnlocked.add(unlockedMaster);

        final userStats = _userStatsBox.get('user_stats') ?? {};
        userStats['total_points'] =
            (userStats['total_points'] ?? 0) + masterAchievement.points;
        await _userStatsBox.put('user_stats', userStats);
      }
    }
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

  // Method to be called whenever dhikr count is updated in the main app
  Future<List<Achievement>> onDhikrCountUpdated(int dhikrId) async {
    final dhikr = DbService.getDhikrById(dhikrId);
    if (dhikr != null) {
      return await updateDhikrCount(dhikr, 1);
    }
    return [];
  }

  // Method to recalculate all achievements based on current dhikr data
  Future<void> recalculateAchievements() async {
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

  // Special achievement methods
  Future<void> markFridayDhikr() async {
    final userStats = _userStatsBox.get('user_stats') ?? {};
    final specialStats = Map<String, dynamic>.from(
      userStats['special_achievements'] ?? {},
    );
    final fridayWeeks = List<String>.from(
      specialStats['friday_dhikr_weeks'] ?? [],
    );

    final currentWeek = _getCurrentWeekString();
    if (!fridayWeeks.contains(currentWeek)) {
      fridayWeeks.add(currentWeek);
      specialStats['friday_dhikr_weeks'] = fridayWeeks;
      userStats['special_achievements'] = specialStats;
      await _userStatsBox.put('user_stats', userStats);
    }
  }

  Future<void> markFajrDhikr() async {
    final userStats = _userStatsBox.get('user_stats') ?? {};
    final specialStats = Map<String, dynamic>.from(
      userStats['special_achievements'] ?? {},
    );
    final fajrDates = List<String>.from(specialStats['fajr_dhikr_dates'] ?? []);

    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';

    if (!fajrDates.contains(todayString)) {
      fajrDates.add(todayString);
      specialStats['fajr_dhikr_dates'] = fajrDates;
      userStats['special_achievements'] = specialStats;
      await _userStatsBox.put('user_stats', userStats);
    }
  }

  Future<void> markMaghribDhikr() async {
    final userStats = _userStatsBox.get('user_stats') ?? {};
    final specialStats = Map<String, dynamic>.from(
      userStats['special_achievements'] ?? {},
    );
    final maghribDates = List<String>.from(
      specialStats['maghrib_dhikr_dates'] ?? [],
    );

    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';

    if (!maghribDates.contains(todayString)) {
      maghribDates.add(todayString);
      specialStats['maghrib_dhikr_dates'] = maghribDates;
      userStats['special_achievements'] = specialStats;
      await _userStatsBox.put('user_stats', userStats);
    }
  }

  Future<void> markMorningEveningDhikr() async {
    final userStats = _userStatsBox.get('user_stats') ?? {};
    final specialStats = Map<String, dynamic>.from(
      userStats['special_achievements'] ?? {},
    );
    specialStats['morning_evening_streak'] =
        (specialStats['morning_evening_streak'] ?? 0) + 1;
    userStats['special_achievements'] = specialStats;
    await _userStatsBox.put('user_stats', userStats);
  }

  Future<void> markRamadanDhikr() async {
    final userStats = _userStatsBox.get('user_stats') ?? {};
    final specialStats = Map<String, dynamic>.from(
      userStats['special_achievements'] ?? {},
    );
    specialStats['ramadan_dhikr_count'] =
        (specialStats['ramadan_dhikr_count'] ?? 0) + 1;
    userStats['special_achievements'] = specialStats;
    await _userStatsBox.put('user_stats', userStats);
  }

  Future<void> markTahajjudDhikr() async {
    final userStats = _userStatsBox.get('user_stats') ?? {};
    final specialStats = Map<String, dynamic>.from(
      userStats['special_achievements'] ?? {},
    );
    specialStats['tahajjud_dhikr_count'] =
        (specialStats['tahajjud_dhikr_count'] ?? 0) + 1;
    userStats['special_achievements'] = specialStats;
    await _userStatsBox.put('user_stats', userStats);
  }

  String _getCurrentWeekString() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return '${startOfWeek.year}-W${_getWeekNumber(startOfWeek)}';
  }

  int _getWeekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final difference = date.difference(startOfYear).inDays;
    return (difference / 7).ceil();
  }

  // Utility method to check if achievements need recalculation
  Future<void> checkAndRecalculateIfNeeded() async {
    try {
      // This can be called periodically to ensure achievements are up-to-date
      await recalculateAchievements();
      debugPrint('Achievement recalculation completed');
    } catch (e) {
      debugPrint('Error during achievement recalculation: $e');
    }
  }

  // Method to get streak-related achievement progress
  Future<List<Map<String, dynamic>>> getStreakAchievementProgress() async {
    try {
      final streakData = await getStreakData();
      final currentStreak = streakData['current'] ?? 0;
      final bestStreak = streakData['best'] ?? 0;

      final streakAchievements =
          _achievementBox.values
              .where(
                (achievement) => achievement.type == AchievementType.streak,
              )
              .toList();

      final progressList = <Map<String, dynamic>>[];

      for (final achievement in streakAchievements) {
        final streakToCheck =
            currentStreak > bestStreak ? currentStreak : bestStreak;
        final progress = (streakToCheck / achievement.targetCount * 100).clamp(
          0,
          100,
        );

        progressList.add({
          'achievement': achievement,
          'currentStreak': currentStreak,
          'bestStreak': bestStreak,
          'targetCount': achievement.targetCount,
          'progress': progress.toInt(),
          'isUnlocked': achievement.isUnlocked,
        });
      }

      return progressList;
    } catch (e) {
      debugPrint('Error getting streak achievement progress: $e');
      return [];
    }
  }

  // Method to get all achievement progress with current status
  Future<List<Map<String, dynamic>>> getAllAchievementProgress() async {
    try {
      final achievements = _achievementBox.values.toList();
      final userStats = getUserStats();
      final allDhikr = DbService.getAllDhikr();
      final actualDhikrCounts = _calculateActualDhikrCounts(allDhikr);

      final progressList = <Map<String, dynamic>>[];

      for (final achievement in achievements) {
        int currentProgress = 0;
        double progressPercentage = 0.0;

        switch (achievement.type) {
          case AchievementType.count:
            final result = _checkCountAchievement(
              achievement,
              actualDhikrCounts,
              userStats,
            );
            currentProgress = result['currentProgress'];
            break;
          case AchievementType.streak:
            final streakData = await getStreakData();
            currentProgress = streakData['current'] ?? 0;
            break;
          case AchievementType.time:
            final result = _checkTimeAchievement(achievement, userStats);
            currentProgress = result['currentProgress'];
            break;
          case AchievementType.special:
            final result = _checkSpecialAchievement(achievement, userStats);
            currentProgress = result['currentProgress'];
            break;
        }

        progressPercentage =
            achievement.targetCount > 0
                ? (currentProgress / achievement.targetCount * 100).clamp(
                  0,
                  100,
                )
                : 0.0;

        progressList.add({
          'achievement': achievement,
          'currentProgress': currentProgress,
          'targetCount': achievement.targetCount,
          'progressPercentage': progressPercentage.toInt(),
          'isUnlocked': achievement.isUnlocked,
          'category': achievement.category.toString(),
          'type': achievement.type.toString(),
        });
      }

      // Sort by category and then by unlock status
      progressList.sort((a, b) {
        final aCategory = a['category'] as String;
        final bCategory = b['category'] as String;

        if (aCategory != bCategory) {
          return aCategory.compareTo(bCategory);
        }

        final aUnlocked = a['isUnlocked'] as bool;
        final bUnlocked = b['isUnlocked'] as bool;

        if (aUnlocked != bUnlocked) {
          return bUnlocked ? 1 : -1; // Unlocked first
        }

        return 0;
      });

      return progressList;
    } catch (e) {
      debugPrint('Error getting all achievement progress: $e');
      return [];
    }
  }

  // Method to get summary statistics
  Future<Map<String, dynamic>> getAchievementSummary() async {
    try {
      final allAchievements = _achievementBox.values.toList();
      final unlockedAchievements =
          allAchievements.where((a) => a.isUnlocked).toList();
      final totalPoints = getTotalPoints();
      final streakData = await getStreakData();

      // Calculate completion percentage
      final completionPercentage =
          allAchievements.isNotEmpty
              ? (unlockedAchievements.length / allAchievements.length * 100)
                  .round()
              : 0;

      // Get category breakdown
      final categoryBreakdown = <String, Map<String, int>>{};
      for (final category in AchievementCategory.values) {
        final categoryAchievements =
            allAchievements.where((a) => a.category == category).toList();
        final unlockedInCategory =
            categoryAchievements.where((a) => a.isUnlocked).length;

        categoryBreakdown[category.toString()] = {
          'total': categoryAchievements.length,
          'unlocked': unlockedInCategory,
          'percentage':
              categoryAchievements.isNotEmpty
                  ? (unlockedInCategory / categoryAchievements.length * 100)
                      .round()
                  : 0,
        };
      }

      return {
        'totalAchievements': allAchievements.length,
        'unlockedAchievements': unlockedAchievements.length,
        'completionPercentage': completionPercentage,
        'totalPoints': totalPoints,
        'currentStreak': streakData['current'],
        'bestStreak': streakData['best'],
        'categoryBreakdown': categoryBreakdown,
        'totalDhikrCount': getTotalDhikrCount(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting achievement summary: $e');
      return {
        'totalAchievements': 0,
        'unlockedAchievements': 0,
        'completionPercentage': 0,
        'totalPoints': 0,
        'currentStreak': 0,
        'bestStreak': 0,
        'categoryBreakdown': {},
        'totalDhikrCount': 0,
        'error': e.toString(),
      };
    }
  }

  // Reset methods for testing
  Future<void> resetAllAchievements() async {
    await _achievementBox.clear();
    await _userStatsBox.clear();
    await _initializeAchievements();
    await _initializeUserStats();
    debugPrint('All achievements and user stats have been reset');
  }

  // Export achievements data for backup
  Future<Map<String, dynamic>> exportAchievementData() async {
    try {
      final achievements = <String, dynamic>{};
      for (final key in _achievementBox.keys) {
        final achievement = _achievementBox.get(key);
        if (achievement != null) {
          achievements[key.toString()] = {
            'id': achievement.id,
            'isUnlocked': achievement.isUnlocked,
            'currentProgress': achievement.currentProgress,
            'unlockedAt': achievement.unlockedAt?.toIso8601String(),
          };
        }
      }

      final userStats = getUserStats();

      return {
        'exportDate': DateTime.now().toIso8601String(),
        'achievements': achievements,
        'userStats': userStats,
      };
    } catch (e) {
      return {
        'error': 'Failed to export achievement data: $e',
        'exportDate': DateTime.now().toIso8601String(),
      };
    }
  }

  // Import achievements data from backup
  Future<bool> importAchievementData(Map<String, dynamic> importData) async {
    try {
      if (importData.containsKey('achievements')) {
        final achievementsData =
            importData['achievements'] as Map<String, dynamic>;

        for (final entry in achievementsData.entries) {
          final achievementId = entry.key;
          final data = entry.value as Map<String, dynamic>;

          final existingAchievement = _achievementBox.get(achievementId);
          if (existingAchievement != null) {
            final updatedAchievement = existingAchievement.copyWith(
              isUnlocked: data['isUnlocked'] ?? false,
              currentProgress: data['currentProgress'] ?? 0,
              unlockedAt:
                  data['unlockedAt'] != null
                      ? DateTime.parse(data['unlockedAt'])
                      : null,
            );
            await _achievementBox.put(achievementId, updatedAchievement);
          }
        }
      }

      if (importData.containsKey('userStats')) {
        final userStatsData = importData['userStats'] as Map<String, dynamic>;
        await _userStatsBox.put('user_stats', userStatsData);
      }

      debugPrint('Achievement data import completed successfully');
      return true;
    } catch (e) {
      debugPrint('Failed to import achievement data: $e');
      return false;
    }
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

  // Watch for changes in achievements
  Stream<BoxEvent> watchAchievements() {
    return _achievementBox.watch();
  }

  // Watch for changes in user stats
  Stream<BoxEvent> watchUserStats() {
    return _userStatsBox.watch();
  }
}
