import 'package:hive/hive.dart';
import '../models/achievement.dart';
import '../models/dhikr.dart';
import '../data/init_achievement_data.dart';

class AchievementService {
  static const String _achievementBoxName = 'achievements';
  static const String _userStatsBoxName = 'user_stats';
  static const String _dhikrHistoryBoxName = 'dhikr_history';

  late Box<Achievement> _achievementBox;
  late Box<Map<dynamic, dynamic>> _userStatsBox;
  late Box<Map<dynamic, dynamic>> _dhikrHistoryBox;

  Future<void> init() async {
    _achievementBox = await Hive.openBox<Achievement>(_achievementBoxName);
    _userStatsBox = await Hive.openBox<Map<dynamic, dynamic>>(
      _userStatsBoxName,
    );
    _dhikrHistoryBox = await Hive.openBox<Map<dynamic, dynamic>>(
      _dhikrHistoryBoxName,
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

  // Main method to update dhikr count and check achievements
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

    // Update streak
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastDhikrDate = userStats['last_dhikr_date'];

    if (lastDhikrDate == null || lastDhikrDate != today) {
      final yesterday =
          DateTime.now()
              .subtract(Duration(days: 1))
              .toIso8601String()
              .split('T')[0];

      if (lastDhikrDate == yesterday) {
        userStats['current_streak'] = (userStats['current_streak'] ?? 0) + 1;
      } else {
        userStats['current_streak'] = 1;
      }

      userStats['last_dhikr_date'] = today;
      userStats['longest_streak'] = [
        userStats['longest_streak'] ?? 0,
        userStats['current_streak'],
      ].reduce((a, b) => a > b ? a : b);
    }

    await _userStatsBox.put('user_stats', userStats);

    // Check achievements
    final achievements = _achievementBox.values.toList();

    for (var achievement in achievements) {
      if (!achievement.isUnlocked) {
        if (await _checkAchievementUnlocked(achievement, userStats)) {
          final unlockedAchievement = achievement.copyWith(
            isUnlocked: true,
            unlockedAt: DateTime.now(),
          );

          await _achievementBox.put(achievement.id, unlockedAchievement);
          newlyUnlockedAchievements.add(unlockedAchievement);

          // Add points
          userStats['total_points'] =
              (userStats['total_points'] ?? 0) + achievement.points;
          await _userStatsBox.put('user_stats', userStats);
        }
      }
    }

    // Check master achievement
    await _checkMasterAchievement(newlyUnlockedAchievements);

    return newlyUnlockedAchievements;
  }

  Future<bool> _checkAchievementUnlocked(
    Achievement achievement,
    Map<dynamic, dynamic> userStats,
  ) async {
    switch (achievement.type) {
      case AchievementType.count:
        return _checkCountAchievement(achievement, userStats);
      case AchievementType.streak:
        return _checkStreakAchievement(achievement, userStats);
      case AchievementType.special:
        return _checkSpecialAchievement(achievement, userStats);
      default:
        return false;
    }
  }

  bool _checkCountAchievement(
    Achievement achievement,
    Map<dynamic, dynamic> userStats,
  ) {
    final dhikrCounts = Map<String, dynamic>.from(
      userStats['dhikr_counts'] ?? {},
    );

    switch (achievement.dhikrType) {
      case 'All':
        return (userStats['total_dhikr_count'] ?? 0) >= achievement.targetCount;
      case 'SubhanAllah':
      case 'Alhamdulillah':
      case 'Allahu Akbar':
      case 'Astaghfirullah':
      case 'La ilaha illa Allah':
      case 'Salawat':
      case 'Dua':
      case 'Adhkar':
        return (dhikrCounts[achievement.dhikrType] ?? 0) >=
            achievement.targetCount;
      case 'Balanced':
        // For perfect balance achievement
        return (dhikrCounts['SubhanAllah'] ?? 0) >= 100 &&
            (dhikrCounts['Alhamdulillah'] ?? 0) >= 100 &&
            (dhikrCounts['Allahu Akbar'] ?? 0) >= 100;
      default:
        return false;
    }
  }

  bool _checkStreakAchievement(
    Achievement achievement,
    Map<dynamic, dynamic> userStats,
  ) {
    return (userStats['current_streak'] ?? 0) >= achievement.targetCount;
  }

  bool _checkSpecialAchievement(
    Achievement achievement,
    Map<dynamic, dynamic> userStats,
  ) {
    final specialStats = Map<String, dynamic>.from(
      userStats['special_achievements'] ?? {},
    );

    switch (achievement.id) {
      case 'fajr_dhikr':
      case 'maghrib_dhikr':
      case 'tahajjud_warrior':
        // These would need time-based checking - simplified for now
        return (userStats['total_dhikr_count'] ?? 0) >= achievement.targetCount;
      case 'friday_blessing':
        final fridayWeeks = List<String>.from(
          specialStats['friday_dhikr_weeks'] ?? [],
        );
        return fridayWeeks.length >= achievement.targetCount;
      case 'morning_evening':
        return (specialStats['morning_evening_streak'] ?? 0) >=
            achievement.targetCount;
      case 'ramadan_dedication':
        return (specialStats['ramadan_dhikr_count'] ?? 0) >=
            achievement.targetCount;
      default:
        return (userStats['total_dhikr_count'] ?? 0) >= achievement.targetCount;
    }
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
      default:
        return dhikrTitle;
    }
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

  int getCurrentStreak() {
    final userStats = getUserStats();
    return userStats['current_streak'] ?? 0;
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
    await _dhikrHistoryBox.close();
  }
}
