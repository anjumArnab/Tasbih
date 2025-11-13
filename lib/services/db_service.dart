import 'package:hive/hive.dart';
import '../models/dhikr.dart';
import '../data/init_dhikr_data.dart';
import '../services/achievement_service.dart';
import '../services/notification_service.dart';

class DbService {
  static const String _boxName = 'dhikr_box';
  static const String _activityBoxName = 'daily_activity_box';
  static const String _isInitializedKey = 'is_initialized';
  static const String _lastResetDateKey = 'last_reset_date';

  static Box<Dhikr>? _box;
  static Box? _activityBox;
  static bool _isInitialized = false;

  static AchievementService? _achievementService;
  static NotificationService? _notificationService;

  static Future<void> initAchievementService() async {
    if (_achievementService == null) {
      _achievementService = AchievementService();
      await _achievementService!.init();
    }
  }

  // Initialize NotificationService
  static Future<void> initNotificationService() async {
    if (_notificationService == null) {
      _notificationService = NotificationService();
      await _notificationService!.init();
    }
  }

  static Future<void> init() async {
    if (_isInitialized && _box != null && _box!.isOpen) {
      return;
    }

    try {
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(DhikrAdapter());
      }

      if (_box == null || !_box!.isOpen) {
        _box = await Hive.openBox<Dhikr>(_boxName);
      }

      if (_activityBox == null || !_activityBox!.isOpen) {
        _activityBox = await Hive.openBox(_activityBoxName);
      }

      await initAchievementService();
      await initNotificationService();
      await _addInitialDataIfNeeded();
      await _checkAndResetDailyCounters();

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize database: $e');
    }
  }

  static String _normalizeDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseNormalizedDate(String dateString) {
    try {
      final parts = dateString.split('-');
      if (parts.length != 3) return null;

      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  static Future<void> incrementDhikrCount(int dhikrId) async {
    try {
      if (!isInitialized) await init();

      final dhikr = getDhikrById(dhikrId);
      if (dhikr != null) {
        final oldCount = dhikr.currentCount ?? 0;
        final newCount = oldCount + 1;
        final wasCompleted = oldCount >= dhikr.times;
        final isNowCompleted = newCount >= dhikr.times;

        final updatedDhikr = Dhikr(
          id: dhikr.id,
          dhikrTitle: dhikr.dhikrTitle,
          dhikr: dhikr.dhikr,
          times: dhikr.times,
          when: dhikr.when,
          currentCount: newCount,
        );

        final index = _dhikrBox.values.toList().indexWhere(
          (d) => d.id == dhikrId,
        );

        if (index != -1) {
          await _dhikrBox.putAt(index, updatedDhikr);
          await _updateTodayActivitySnapshot();

          if (!wasCompleted && isNowCompleted) {
            await _checkDailyCompletionAndUpdateStreak(updatedDhikr);

            if (_achievementService != null) {
              await _achievementService!.updateDhikrCount(updatedDhikr, 1);
            }
          }
        } else {
          throw Exception('Dhikr not found');
        }
      }
    } catch (e) {
      throw Exception('Failed to increment dhikr count: $e');
    }
  }

  static Future<void> _updateTodayActivitySnapshot() async {
    try {
      final today = DateTime.now();
      final todayKey = _normalizeDateString(today);

      final completedCount = _getTodayCompletedDhikrCount();
      final activityLevel = _convertCountToActivityLevel(completedCount);

      await _activityBox!.put(todayKey, {
        'date': todayKey,
        'completedCount': completedCount,
        'activityLevel': activityLevel,
        'timestamp': today.millisecondsSinceEpoch,
      });
    } catch (e) {
      // Silent error handling
    }
  }

  static int _getTodayCompletedDhikrCount() {
    try {
      final allDhikr = _dhikrBox.values.toList();
      int completedCount = 0;

      for (final dhikr in allDhikr) {
        if (dhikr.currentCount != null && dhikr.currentCount! >= dhikr.times) {
          completedCount++;
        }
      }

      return completedCount;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> _checkAndResetDailyCounters() async {
    try {
      Box? preferences;
      try {
        preferences =
            Hive.isBoxOpen('app_preferences')
                ? Hive.box('app_preferences')
                : await Hive.openBox('app_preferences');
      } catch (e) {
        preferences = await Hive.openBox('app_preferences');
      }

      final today = DateTime.now();
      final todayString = _normalizeDateString(today);

      final lastResetDate = preferences.get(
        _lastResetDateKey,
        defaultValue: '',
      );

      if (lastResetDate != todayString) {
        await _checkStreakBreak(preferences, todayString, lastResetDate);

        if (lastResetDate.isNotEmpty) {
          await _storeYesterdayActivitySnapshot(lastResetDate);
        }

        await _resetAllDhikrCounters();
        await preferences.put(_lastResetDateKey, todayString);
        await _initializeTodayActivitySnapshot();

        // Reschedule all notifications after daily reset
        await _rescheduleAllNotifications();
      } else {
        await _updateTodayActivitySnapshot();
      }
    } catch (e) {
      // Silent error handling to prevent app initialization failure
    }
  }

  // Reschedule all notifications
  static Future<void> _rescheduleAllNotifications() async {
    try {
      if (_notificationService != null) {
        final allDhikr = _dhikrBox.values.toList();
        for (final dhikr in allDhikr) {
          if (dhikr.when != null && dhikr.id != null) {
            await _notificationService!.rescheduleDhikrNotification(dhikr);
          }
        }
      }
    } catch (e) {
      // Silent error handling
    }
  }

  static Future<void> _storeYesterdayActivitySnapshot(
    String lastResetDate,
  ) async {
    try {
      final completedCount = _getTodayCompletedDhikrCount();
      final activityLevel = _convertCountToActivityLevel(completedCount);

      await _activityBox!.put(lastResetDate, {
        'date': lastResetDate,
        'completedCount': completedCount,
        'activityLevel': activityLevel,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isFinal': true,
      });
    } catch (e) {
      // Silent error handling
    }
  }

  static Future<void> _initializeTodayActivitySnapshot() async {
    try {
      final today = DateTime.now();
      final todayKey = _normalizeDateString(today);

      await _activityBox!.put(todayKey, {
        'date': todayKey,
        'completedCount': 0,
        'activityLevel': 0,
        'timestamp': today.millisecondsSinceEpoch,
      });
    } catch (e) {
      // Silent error handling
    }
  }

  static Future<void> _checkStreakBreak(
    Box preferences,
    String todayString,
    String lastResetDate,
  ) async {
    try {
      if (lastResetDate.isEmpty) {
        await preferences.put('current_streak', 0);
        return;
      }

      final lastDate = _parseNormalizedDate(lastResetDate);
      final todayDate = _parseNormalizedDate(todayString);

      if (lastDate == null || todayDate == null) {
        await preferences.put('current_streak', 0);
        return;
      }

      final daysDifference = todayDate.difference(lastDate).inDays;

      if (daysDifference > 1) {
        bool streakBroken = false;

        for (int i = 1; i < daysDifference; i++) {
          final checkDate = lastDate.add(Duration(days: i));
          final completedCount = await getCompletedDhikrCountForDate(checkDate);

          if (completedCount == 0) {
            streakBroken = true;
            break;
          }
        }

        if (streakBroken) {
          await preferences.put('current_streak', 0);
        }
      }
    } catch (e) {
      await preferences.put('current_streak', 0);
    }
  }

  static Future<void> _resetAllDhikrCounters() async {
    try {
      final allDhikr = _dhikrBox.values.toList();

      for (int i = 0; i < allDhikr.length; i++) {
        final dhikr = allDhikr[i];
        final resetDhikr = Dhikr(
          id: dhikr.id,
          dhikrTitle: dhikr.dhikrTitle,
          dhikr: dhikr.dhikr,
          times: dhikr.times,
          when: dhikr.when,
          currentCount: 0,
        );
        await _dhikrBox.putAt(i, resetDhikr);
      }
    } catch (e) {
      throw Exception('Failed to reset daily counters: $e');
    }
  }

  static Future<void> _checkDailyCompletionAndUpdateStreak(
    Dhikr completedDhikr,
  ) async {
    try {
      final today = DateTime.now();
      final todayString = _normalizeDateString(today);

      Box? preferences;
      try {
        preferences =
            Hive.isBoxOpen('app_preferences')
                ? Hive.box('app_preferences')
                : await Hive.openBox('app_preferences');
      } catch (e) {
        preferences = await Hive.openBox('app_preferences');
      }

      final lastCompletionDate = preferences.get(
        'last_completion_date',
        defaultValue: '',
      );

      if (lastCompletionDate != todayString) {
        await preferences.put('last_completion_date', todayString);

        final currentStreak = preferences.get(
          'current_streak',
          defaultValue: 0,
        );
        final lastStreakDate = preferences.get(
          'last_streak_date',
          defaultValue: '',
        );
        final bestStreak = preferences.get('best_streak', defaultValue: 0);

        int newCurrentStreak;

        if (lastStreakDate.isEmpty) {
          newCurrentStreak = 1;
        } else {
          final lastDate = _parseNormalizedDate(lastStreakDate);
          final todayDate = _parseNormalizedDate(todayString);

          if (lastDate == null || todayDate == null) {
            newCurrentStreak = 1;
          } else {
            final daysDifference = todayDate.difference(lastDate).inDays;

            if (daysDifference == 1) {
              newCurrentStreak = currentStreak + 1;
            } else if (daysDifference > 1) {
              bool hasGap = false;
              for (int i = 1; i < daysDifference; i++) {
                final checkDate = lastDate.add(Duration(days: i));
                final completedCount = await getCompletedDhikrCountForDate(
                  checkDate,
                );
                if (completedCount == 0) {
                  hasGap = true;
                  break;
                }
              }

              if (hasGap) {
                newCurrentStreak = 1;
              } else {
                newCurrentStreak = currentStreak + 1;
              }
            } else if (daysDifference == 0) {
              newCurrentStreak = currentStreak;
            } else {
              newCurrentStreak = 1;
            }
          }
        }

        await preferences.put('current_streak', newCurrentStreak);
        await preferences.put('last_streak_date', todayString);

        int newBestStreak = bestStreak;
        if (newCurrentStreak > bestStreak) {
          newBestStreak = newCurrentStreak;
          await preferences.put('best_streak', newBestStreak);
        }
      }
    } catch (e) {
      // Silent error handling
    }
  }

  static Future<int> getCurrentStreak() async {
    try {
      Box? preferences;
      try {
        preferences =
            Hive.isBoxOpen('app_preferences')
                ? Hive.box('app_preferences')
                : await Hive.openBox('app_preferences');
      } catch (e) {
        preferences = await Hive.openBox('app_preferences');
      }

      return preferences.get('current_streak', defaultValue: 0);
    } catch (e) {
      return 0;
    }
  }

  static Future<int> getBestStreak() async {
    try {
      Box? preferences;
      try {
        preferences =
            Hive.isBoxOpen('app_preferences')
                ? Hive.box('app_preferences')
                : await Hive.openBox('app_preferences');
      } catch (e) {
        preferences = await Hive.openBox('app_preferences');
      }

      return preferences.get('best_streak', defaultValue: 0);
    } catch (e) {
      return 0;
    }
  }

  static Future<Map<String, int>> getStreakData() async {
    try {
      final currentStreak = await getCurrentStreak();
      final bestStreak = await getBestStreak();

      return {'current': currentStreak, 'best': bestStreak};
    } catch (e) {
      return {'current': 0, 'best': 0};
    }
  }

  static Future<void> resetAllCountersManually() async {
    try {
      if (!isInitialized) await init();

      final today = DateTime.now();
      final todayKey = _normalizeDateString(today);
      await _storeYesterdayActivitySnapshot(todayKey);

      await _resetAllDhikrCounters();
      await _initializeTodayActivitySnapshot();

      Box? preferences;
      try {
        preferences =
            Hive.isBoxOpen('app_preferences')
                ? Hive.box('app_preferences')
                : await Hive.openBox('app_preferences');
      } catch (e) {
        preferences = await Hive.openBox('app_preferences');
      }

      await preferences.put(_lastResetDateKey, todayKey);
    } catch (e) {
      throw Exception('Failed to manually reset counters: $e');
    }
  }

  static Future<String> getLastResetDate() async {
    try {
      Box? preferences;
      try {
        preferences =
            Hive.isBoxOpen('app_preferences')
                ? Hive.box('app_preferences')
                : await Hive.openBox('app_preferences');
      } catch (e) {
        preferences = await Hive.openBox('app_preferences');
      }

      return preferences.get(_lastResetDateKey, defaultValue: 'Never');
    } catch (e) {
      return 'Error';
    }
  }

  static Future<bool> wereCountersResetToday() async {
    try {
      final today = DateTime.now();
      final todayString = _normalizeDateString(today);
      final lastResetDate = await getLastResetDate();
      return lastResetDate == todayString;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _addInitialDataIfNeeded() async {
    try {
      Box? preferences;
      try {
        preferences =
            Hive.isBoxOpen('app_preferences')
                ? Hive.box('app_preferences')
                : await Hive.openBox('app_preferences');
      } catch (e) {
        preferences = await Hive.openBox('app_preferences');
      }

      final isInitialized = preferences.get(
        _isInitializedKey,
        defaultValue: false,
      );

      if (!isInitialized) {
        await _dhikrBox.clear();
        final initialDhikrList = InitialDhikrData.getInitialDhikrList();

        for (final dhikr in initialDhikrList) {
          await _dhikrBox.add(dhikr);
          // Schedule notification for initial dhikr
          if (dhikr.when != null && _notificationService != null) {
            await _notificationService!.scheduleDhikrNotification(dhikr);
          }
        }

        await preferences.put(_isInitializedKey, true);
        await _initializeTodayActivitySnapshot();
      }
    } catch (e) {
      throw Exception('Failed to add initial data: $e');
    }
  }

  static Box<Dhikr> get _dhikrBox {
    if (_box == null || !_box!.isOpen) {
      throw Exception('Database not initialized. Call DbService.init() first.');
    }
    return _box!;
  }

  static Box get _activityStorageBox {
    if (_activityBox == null || !_activityBox!.isOpen) {
      throw Exception(
        'Activity database not initialized. Call DbService.init() first.',
      );
    }
    return _activityBox!;
  }

  static bool get isInitialized =>
      _isInitialized &&
      _box != null &&
      _box!.isOpen &&
      _activityBox != null &&
      _activityBox!.isOpen;

  static Future<int> addDhikr(Dhikr dhikr) async {
    try {
      if (!isInitialized) await init();

      final existingIds = _dhikrBox.values.map((d) => d.id ?? 0).toList();
      int newId = 0;
      while (existingIds.contains(newId)) {
        newId++;
      }

      final dhikrWithId = Dhikr(
        id: newId,
        dhikrTitle: dhikr.dhikrTitle,
        dhikr: dhikr.dhikr,
        times: dhikr.times,
        when: dhikr.when,
        currentCount: dhikr.currentCount ?? 0,
      );

      await _dhikrBox.add(dhikrWithId);

      // Schedule notification
      if (dhikrWithId.when != null && _notificationService != null) {
        await _notificationService!.scheduleDhikrNotification(dhikrWithId);
      }

      return newId;
    } catch (e) {
      throw Exception('Failed to add dhikr: $e');
    }
  }

  static List<Dhikr> getAllDhikr() {
    try {
      if (!isInitialized) {
        throw Exception(
          'Database not initialized. Call DbService.init() first.',
        );
      }
      return _dhikrBox.values.toList();
    } catch (e) {
      throw Exception('Failed to get dhikr list: $e');
    }
  }

  static Dhikr? getDhikrById(int id) {
    try {
      if (!isInitialized) return null;
      return _dhikrBox.values.firstWhere(
        (dhikr) => dhikr.id == id,
        orElse: () => throw Exception('Dhikr not found'),
      );
    } catch (e) {
      return null;
    }
  }

  static List<Dhikr> getUpcomingDhikr() {
    try {
      if (!isInitialized) {
        throw Exception(
          'Database not initialized. Call DbService.init() first.',
        );
      }
      final now = DateTime.now();
      return _dhikrBox.values
          .where(
            (dhikr) =>
                dhikr.when != null &&
                dhikr.when!.isAfter(now) &&
                (dhikr.currentCount ?? 0) < dhikr.times,
          )
          .toList()
        ..sort((a, b) => a.when!.compareTo(b.when!));
    } catch (e) {
      throw Exception('Failed to get upcoming dhikr: $e');
    }
  }

  static List<Dhikr> getCompletedDhikr() {
    try {
      if (!isInitialized) {
        throw Exception(
          'Database not initialized. Call DbService.init() first.',
        );
      }
      return _dhikrBox.values
          .where((dhikr) => (dhikr.currentCount ?? 0) >= dhikr.times)
          .toList()
        ..sort((a, b) {
          if (a.when == null && b.when == null) return 0;
          if (a.when == null) return 1;
          if (b.when == null) return -1;
          return b.when!.compareTo(a.when!);
        });
    } catch (e) {
      throw Exception('Failed to get completed dhikr: $e');
    }
  }

  static Future<int> getCompletedDhikrCountForDate(DateTime date) async {
    try {
      if (!isInitialized) await init();

      final dateKey = _normalizeDateString(date);
      final today = DateTime.now();
      final todayKey = _normalizeDateString(today);

      if (dateKey == todayKey) {
        return _getTodayCompletedDhikrCount();
      }

      final activityData = _activityStorageBox.get(dateKey);
      if (activityData != null && activityData is Map) {
        return activityData['completedCount'] ?? 0;
      }

      return 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> getActivityLevelForDate(DateTime date) async {
    try {
      final completedCount = await getCompletedDhikrCountForDate(date);
      return _convertCountToActivityLevel(completedCount);
    } catch (e) {
      return 0;
    }
  }

  static int _convertCountToActivityLevel(int completedCount) {
    if (completedCount == 0) return 0;
    if (completedCount == 1) return 1;
    if (completedCount == 2) return 2;
    if (completedCount == 3) return 3;
    return 4;
  }

  static Future<Map<DateTime, int>> getActivityDataForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      if (!isInitialized) await init();

      final Map<DateTime, int> activityLevels = {};

      DateTime currentDate = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final normalizedEndDate = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
      );

      while (currentDate.isBefore(normalizedEndDate) ||
          currentDate.isAtSameMomentAs(normalizedEndDate)) {
        final dateKey = _normalizeDateString(currentDate);
        final today = DateTime.now();
        final todayKey = _normalizeDateString(today);

        int activityLevel = 0;

        if (dateKey == todayKey) {
          final completedCount = _getTodayCompletedDhikrCount();
          activityLevel = _convertCountToActivityLevel(completedCount);
        } else {
          final activityData = _activityStorageBox.get(dateKey);
          if (activityData != null && activityData is Map) {
            activityLevel = activityData['activityLevel'] ?? 0;
          }
        }

        activityLevels[DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
            )] =
            activityLevel;

        currentDate = currentDate.add(const Duration(days: 1));
      }

      return activityLevels;
    } catch (e) {
      return {};
    }
  }

  static Future<int> getTotalDhikrSessionsForYear([int? year]) async {
    try {
      if (!isInitialized) await init();

      final targetYear = year ?? DateTime.now().year;
      final today = DateTime.now();
      final todayKey = _normalizeDateString(today);

      int totalSessions = 0;

      final allKeys = _activityStorageBox.keys.cast<String>();

      for (final key in allKeys) {
        try {
          final parts = key.split('-');
          if (parts.length >= 3) {
            final keyYear = int.parse(parts[0]);
            if (keyYear == targetYear) {
              final activityData = _activityStorageBox.get(key);
              if (activityData != null && activityData is Map) {
                final completedCount = activityData['completedCount'] ?? 0;
                totalSessions += completedCount as int;
              }
            }
          }
        } catch (e) {
          continue;
        }
      }

      if (targetYear == today.year) {
        final todayStoredData = _activityStorageBox.get(todayKey);
        final currentTodayCount = _getTodayCompletedDhikrCount();

        if (todayStoredData != null && todayStoredData is Map) {
          final storedTodayCount = todayStoredData['completedCount'] ?? 0;

          if (currentTodayCount != storedTodayCount) {
            totalSessions =
                totalSessions - (storedTodayCount as int) + currentTodayCount;
          }
        } else {
          totalSessions += currentTodayCount;
        }
      }

      return totalSessions;
    } catch (e) {
      return 0;
    }
  }

  // Added notification rescheduling
  static Future<void> updateDhikr(Dhikr updatedDhikr) async {
    try {
      if (!isInitialized) await init();

      final index = _dhikrBox.values.toList().indexWhere(
        (dhikr) => dhikr.id == updatedDhikr.id,
      );

      if (index != -1) {
        await _dhikrBox.putAt(index, updatedDhikr);
        await _updateTodayActivitySnapshot();

        // Reschedule notification
        if (updatedDhikr.id != null && _notificationService != null) {
          await _notificationService!.rescheduleDhikrNotification(updatedDhikr);
        }
      } else {
        throw Exception('Dhikr not found for update');
      }
    } catch (e) {
      throw Exception('Failed to update dhikr: $e');
    }
  }

  static Future<void> decrementDhikrCount(int dhikrId) async {
    try {
      if (!isInitialized) await init();

      final dhikr = getDhikrById(dhikrId);
      if (dhikr != null) {
        final currentCount = dhikr.currentCount ?? 0;
        if (currentCount > 0) {
          final updatedDhikr = Dhikr(
            id: dhikr.id,
            dhikrTitle: dhikr.dhikrTitle,
            dhikr: dhikr.dhikr,
            times: dhikr.times,
            when: dhikr.when,
            currentCount: currentCount - 1,
          );

          final index = _dhikrBox.values.toList().indexWhere(
            (d) => d.id == dhikrId,
          );

          if (index != -1) {
            await _dhikrBox.putAt(index, updatedDhikr);
            await _updateTodayActivitySnapshot();
          } else {
            throw Exception('Dhikr not found');
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to decrement dhikr count: $e');
    }
  }

  static Future<void> resetDhikrCount(int dhikrId) async {
    try {
      if (!isInitialized) await init();

      final dhikr = getDhikrById(dhikrId);
      if (dhikr != null) {
        final updatedDhikr = Dhikr(
          id: dhikr.id,
          dhikrTitle: dhikr.dhikrTitle,
          dhikr: dhikr.dhikr,
          times: dhikr.times,
          when: dhikr.when,
          currentCount: 0,
        );

        final index = _dhikrBox.values.toList().indexWhere(
          (d) => d.id == dhikrId,
        );

        if (index != -1) {
          await _dhikrBox.putAt(index, updatedDhikr);
          await _updateTodayActivitySnapshot();
        } else {
          throw Exception('Dhikr not found');
        }
      }
    } catch (e) {
      throw Exception('Failed to reset dhikr count: $e');
    }
  }

  // Added notification canceling
  static Future<void> deleteDhikr(int dhikrId) async {
    try {
      if (!isInitialized) await init();

      final index = _dhikrBox.values.toList().indexWhere(
        (dhikr) => dhikr.id == dhikrId,
      );

      if (index != -1) {
        await _dhikrBox.deleteAt(index);
        await _updateTodayActivitySnapshot();

        // Cancel notification when dhikr is deleted
        if (_notificationService != null) {
          await _notificationService!.cancelDhikrNotification(dhikrId);
        }
      } else {
        throw Exception('Dhikr not found for deletion');
      }
    } catch (e) {
      throw Exception('Failed to delete dhikr: $e');
    }
  }

  static Future<void> clearAllDhikr() async {
    try {
      if (!isInitialized) await init();

      // Cancel all notifications before clearing
      if (_notificationService != null) {
        await _notificationService!.cancelAllNotifications();
      }

      await _dhikrBox.clear();
      await _initializeTodayActivitySnapshot();
    } catch (e) {
      throw Exception('Failed to clear all dhikr: $e');
    }
  }

  static Future<void> clearAllActivityData() async {
    try {
      if (!isInitialized) await init();
      await _activityStorageBox.clear();
      await _initializeTodayActivitySnapshot();
    } catch (e) {
      throw Exception('Failed to clear activity data: $e');
    }
  }

  static Future<Map<String, dynamic>> getActivityDataDebugInfo() async {
    try {
      if (!isInitialized) await init();

      final Map<String, dynamic> debugInfo = {};
      final allKeys = _activityStorageBox.keys.cast<String>().toList()..sort();

      for (final key in allKeys) {
        final data = _activityStorageBox.get(key);
        debugInfo[key] = data;
      }

      return debugInfo;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static int getDhikrCount() {
    try {
      if (!isInitialized) return 0;
      return _dhikrBox.length;
    } catch (e) {
      return 0;
    }
  }

  static Stream<BoxEvent> watchDhikr() {
    if (!isInitialized) {
      throw Exception('Database not initialized. Call DbService.init() first.');
    }
    return _dhikrBox.watch();
  }

  static Stream<BoxEvent> watchActivityData() {
    if (!isInitialized) {
      throw Exception('Database not initialized. Call DbService.init() first.');
    }
    return _activityStorageBox.watch();
  }

  static Future<void> close() async {
    try {
      if (_box != null && _box!.isOpen) {
        await _box!.close();
      }
      if (_activityBox != null && _activityBox!.isOpen) {
        await _activityBox!.close();
      }
      _isInitialized = false;
    } catch (e) {
      // Silent error handling
    }
  }

  static Future<Map<String, dynamic>> exportActivityData() async {
    try {
      if (!isInitialized) await init();

      final Map<String, dynamic> exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'activityData': {},
      };

      final allKeys = _activityStorageBox.keys.cast<String>().toList()..sort();

      for (final key in allKeys) {
        final data = _activityStorageBox.get(key);
        if (data != null) {
          exportData['activityData'][key] = Map<String, dynamic>.from(data);
        }
      }

      return exportData;
    } catch (e) {
      return {'error': 'Failed to export activity data: $e'};
    }
  }

  static Future<bool> importActivityData(
    Map<String, dynamic> importData,
  ) async {
    try {
      if (!isInitialized) await init();

      if (importData.containsKey('activityData')) {
        final activityData = importData['activityData'] as Map<String, dynamic>;

        for (final entry in activityData.entries) {
          await _activityStorageBox.put(entry.key, entry.value);
        }

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}
