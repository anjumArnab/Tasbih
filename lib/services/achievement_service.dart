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
      'current_streak': 0,
      'longest_streak': 0,
      'last_dhikr_date': null,
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

  /// Check and update streak status based on current date
  /// This should be called when the app starts or when the stats page loads
  Future<void> checkAndUpdateStreakStatus() async {
    final userStats = _userStatsBox.get('user_stats') ?? {};
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastDhikrDate = userStats['last_dhikr_date'];

    if (lastDhikrDate == null) {
      // No dhikr recorded yet, current streak should be 0
      userStats['current_streak'] = 0;
      await _userStatsBox.put('user_stats', userStats);
      return;
    }

    // Parse the last dhikr date
    final lastDate = DateTime.parse(lastDhikrDate + 'T00:00:00');
    final todayDate = DateTime.parse(today + 'T00:00:00');
    final daysDifference = todayDate.difference(lastDate).inDays;

    if (daysDifference > 1) {
      // User missed one or more days, reset current streak
      userStats['current_streak'] = 0;
      await _userStatsBox.put('user_stats', userStats);
    }
    // If daysDifference == 0 (today) or == 1 (yesterday), keep current streak
  }

  /// Enhanced updateDhikrCount with better date handling
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

    // Enhanced streak calculation
    final today = DateTime.now();
    final todayString = today.toIso8601String().split('T')[0];
    final lastDhikrDate = userStats['last_dhikr_date'];

    if (lastDhikrDate == null || lastDhikrDate != todayString) {
      // This is the first dhikr of the day
      if (lastDhikrDate == null) {
        // Very first dhikr ever
        userStats['current_streak'] = 1;
      } else {
        // Check if this continues a streak
        final lastDate = DateTime.parse(lastDhikrDate + 'T00:00:00');
        final daysDifference = today.difference(lastDate).inDays;

        if (daysDifference == 1) {
          // Consecutive day - continue streak
          userStats['current_streak'] = (userStats['current_streak'] ?? 0) + 1;
        } else if (daysDifference > 1) {
          // Missed day(s) - restart streak
          userStats['current_streak'] = 1;
        }
        // If daysDifference == 0, it means multiple dhikr sessions today - keep current streak
      }

      userStats['last_dhikr_date'] = todayString;

      // Update longest streak if current is higher
      final currentStreak = userStats['current_streak'] ?? 0;
      final longestStreak = userStats['longest_streak'] ?? 0;
      if (currentStreak > longestStreak) {
        userStats['longest_streak'] = currentStreak;
      }
    }

    await _userStatsBox.put('user_stats', userStats);

    // Check achievements
    await _checkAndUnlockAchievements(userStats, newlyUnlockedAchievements);

    return newlyUnlockedAchievements;
  }

  /// Get current streak with real-time validation
  int getCurrentStreak() {
    final userStats = getUserStats();
    final currentStreak = userStats['current_streak'] ?? 0;
    final lastDhikrDate = userStats['last_dhikr_date'];

    if (lastDhikrDate == null) return 0;

    // Check if streak should be reset due to missed days
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastDate = DateTime.parse(lastDhikrDate + 'T00:00:00');
    final todayDate = DateTime.parse(today + 'T00:00:00');
    final daysDifference = todayDate.difference(lastDate).inDays;

    if (daysDifference > 1) {
      // Streak should be reset but we don't modify data here
      // This will be handled by checkAndUpdateStreakStatus()
      return 0;
    }

    return currentStreak;
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
            final result = _checkStreakAchievement(achievement, userStats);
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
    // Time-based achievements could be based on:
    // - Total time spent in dhikr
    // - Consecutive days of dhikr
    // - Dhikr at specific times (Fajr, Maghrib, etc.)

    int currentProgress = 0;
    bool shouldUnlock = false;

    switch (achievement.id) {
      case 'fajr_time':
        // Check if dhikr was done during Fajr time
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
        // Check if dhikr was done during Maghrib time
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
        // These would need specific time checking logic
        // For now, fallback to total count
        currentProgress = userStats['total_dhikr_count'] ?? 0;
        shouldUnlock = currentProgress >= achievement.targetCount;
        break;
      default:
        // Default time-based achievement logic
        // Could be based on consecutive days or specific timing
        final currentStreak = userStats['current_streak'] ?? 0;
        currentProgress = currentStreak;
        shouldUnlock = currentStreak >= achievement.targetCount;
    }

    return {'shouldUnlock': shouldUnlock, 'currentProgress': currentProgress};
  }

  Map<String, dynamic> _checkStreakAchievement(
    Achievement achievement,
    Map<dynamic, dynamic> userStats,
  ) {
    final currentStreak = userStats['current_streak'] ?? 0;
    return {
      'shouldUnlock': currentStreak >= achievement.targetCount,
      'currentProgress': currentStreak,
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
        // Fallback to total dhikr count
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
        // All achievements except master
        final unlockedMaster = masterAchievement.copyWith(
          isUnlocked: true,
          unlockedAt: DateTime.now(),
        );
        await _achievementBox.put('dhikr_master', unlockedMaster);
        newlyUnlocked.add(unlockedMaster);

        // Add master achievement points
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

  // Reset methods for testing
  Future<void> resetAllAchievements() async {
    await _achievementBox.clear();
    await _userStatsBox.clear();
    await _initializeAchievements();
    await _initializeUserStats();
  }

  Future<void> dispose() async {
    await _achievementBox.close();
    await _userStatsBox.close();
  }
}
