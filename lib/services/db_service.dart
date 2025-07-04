import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/dhikr.dart';
import '../data/init_dhikr_data.dart';
import '../services/achievement_service.dart'; // Add this import

class DbService {
  static const String _boxName = 'dhikr_box';
  static const String _isInitializedKey = 'is_initialized';
  static const String _lastResetDateKey = 'last_reset_date';
  static Box<Dhikr>? _box;
  static bool _isInitialized = false;

  // Add achievement service instance
  static AchievementService? _achievementService;

  // Initialize achievement service
  static Future<void> initAchievementService() async {
    if (_achievementService == null) {
      _achievementService = AchievementService();
      await _achievementService!.init();
    }
  }

  // Initialize Hive and open the box
  static Future<void> init() async {
    // Prevent multiple initializations
    if (_isInitialized && _box != null && _box!.isOpen) {
      return;
    }

    try {
      // Register the adapter if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(DhikrAdapter());
      }

      // Only open box if it's not already open
      if (_box == null || !_box!.isOpen) {
        _box = await Hive.openBox<Dhikr>(_boxName);
      }

      // Initialize achievement service
      await initAchievementService();

      // Add initial data if this is the first time opening the app
      await _addInitialDataIfNeeded();

      // Check and reset counters if it's a new day
      await _checkAndResetDailyCounters();

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize database: $e');
    }
  }

  // Update - Increment dhikr count
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

        // Find the index and update
        final index = _dhikrBox.values.toList().indexWhere(
          (d) => d.id == dhikrId,
        );

        if (index != -1) {
          await _dhikrBox.putAt(index, updatedDhikr);

          // Notify achievement service if dhikr just got completed
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

  // Check if it's a new day and reset all dhikr counters
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
      final todayString = '${today.year}-${today.month}-${today.day}';

      final lastResetDate = preferences.get(
        _lastResetDateKey,
        defaultValue: '',
      );

      // If it's a new day, reset all counters
      if (lastResetDate != todayString) {
        await _resetAllDhikrCounters();
        await preferences.put(_lastResetDateKey, todayString);
        debugPrint('Daily dhikr counters reset for date: $todayString');

        // Check if we need to break the streak due to missed day
        await _checkStreakBreak(preferences, todayString, lastResetDate);
      }
    } catch (e) {
      debugPrint('Error checking daily reset: $e');
      // Don't throw here to prevent app initialization failure
    }
  }

  // Check if streak should be broken due to missed day
  static Future<void> _checkStreakBreak(
    Box preferences,
    String todayString,
    String lastResetDate,
  ) async {
    try {
      if (lastResetDate.isEmpty) return;

      final lastDate = DateTime.parse('${lastResetDate}T00:00:00');
      final todayDate = DateTime.parse('${todayString}T00:00:00');
      final daysDifference = todayDate.difference(lastDate).inDays;

      // If more than 1 day has passed, break the streak
      if (daysDifference > 1) {
        final lastStreakDate = preferences.get(
          'last_streak_date',
          defaultValue: '',
        );

        // Only break streak if the last streak date is not today
        if (lastStreakDate != todayString) {
          await preferences.put('current_streak', 0);
          debugPrint('Streak broken due to missed day(s)');
        }
      }
    } catch (e) {
      debugPrint('Error checking streak break: $e');
    }
  }

  // Reset all dhikr counters to 0
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

  // Add this method to DbService
  static Future<void> _checkDailyCompletionAndUpdateStreak(
    Dhikr completedDhikr,
  ) async {
    try {
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month}-${today.day}';

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

      // Only update streak if this is the first completion of the day
      if (lastCompletionDate != todayString) {
        await preferences.put('last_completion_date', todayString);

        // Update streak logic
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
          final lastDate = DateTime.parse('${lastStreakDate}T00:00:00');
          final todayDate = DateTime.parse('${todayString}T00:00:00');
          final daysDifference = todayDate.difference(lastDate).inDays;

          if (daysDifference == 1) {
            newCurrentStreak = currentStreak + 1;
          } else if (daysDifference > 1) {
            newCurrentStreak = 1; // Reset streak, start new
          } else {
            newCurrentStreak = currentStreak; // Same day, no change
          }
        }

        await preferences.put('current_streak', newCurrentStreak);
        await preferences.put('last_streak_date', todayString);

        if (newCurrentStreak > bestStreak) {
          await preferences.put('best_streak', newCurrentStreak);
        }
      }
    } catch (e) {
      debugPrint('Error updating completion streak: $e');
    }
  }

  // Manual method to reset all counters (can be called from UI if needed)
  static Future<void> resetAllCountersManually() async {
    try {
      if (!isInitialized) await init();
      await _resetAllDhikrCounters();

      // Update the last reset date to today
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
      final todayString = '${today.year}-${today.month}-${today.day}';
      await preferences.put(_lastResetDateKey, todayString);
    } catch (e) {
      throw Exception('Failed to manually reset counters: $e');
    }
  }

  // Get the last reset date (for debugging or UI display)
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

  // Check if counters were reset today
  static Future<bool> wereCountersResetToday() async {
    try {
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month}-${today.day}';
      final lastResetDate = await getLastResetDate();
      return lastResetDate == todayString;
    } catch (e) {
      return false;
    }
  }

  // Add initial data if the database hasn't been initialized before
  static Future<void> _addInitialDataIfNeeded() async {
    try {
      // Check if we've already added initial data
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
        // Clear any existing data first (optional)
        await _dhikrBox.clear();

        // Get initial dhikr data from the separate file
        final initialDhikrList = InitialDhikrData.getInitialDhikrList();

        // Add each dhikr to the database
        for (final dhikr in initialDhikrList) {
          await _dhikrBox.add(dhikr);
        }

        // Mark as initialized so we don't add initial data again
        await preferences.put(_isInitializedKey, true);
      }
    } catch (e) {
      throw Exception('Failed to add initial data: $e');
    }
  }

  // Get the box instance
  static Box<Dhikr> get _dhikrBox {
    if (_box == null || !_box!.isOpen) {
      throw Exception('Database not initialized. Call DbService.init() first.');
    }
    return _box!;
  }

  // Check if database is initialized
  static bool get isInitialized =>
      _isInitialized && _box != null && _box!.isOpen;

  // Create - Add a new dhikr
  static Future<int> addDhikr(Dhikr dhikr) async {
    try {
      if (!isInitialized) await init();

      // Generate a new ID to avoid conflicts
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
      return newId;
    } catch (e) {
      throw Exception('Failed to add dhikr: $e');
    }
  }

  // Read - Get all dhikr
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

  // Read - Get dhikr by ID
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

  // Read - Get upcoming dhikr (only for dhikr with scheduled times)
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
                dhikr.when != null && // Check if when is not null
                dhikr.when!.isAfter(now) &&
                (dhikr.currentCount ?? 0) < dhikr.times,
          )
          .toList()
        ..sort((a, b) => a.when!.compareTo(b.when!));
    } catch (e) {
      throw Exception('Failed to get upcoming dhikr: $e');
    }
  }

  // Read - Get completed dhikr
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
          // Handle null dates in sorting
          if (a.when == null && b.when == null) return 0;
          if (a.when == null) return 1;
          if (b.when == null) return -1;
          return b.when!.compareTo(a.when!);
        });
    } catch (e) {
      throw Exception('Failed to get completed dhikr: $e');
    }
  }

  /// Get count of completed dhikr sessions for a specific date
  static Future<int> getCompletedDhikrCountForDate(DateTime date) async {
    try {
      if (!isInitialized) await init();

      final dhikrList = _dhikrBox.values.toList();

      // Normalize the date to compare only year, month, day
      final targetDate = DateTime(date.year, date.month, date.day);

      int completedCount = 0;
      for (final dhikr in dhikrList) {
        // Skip dhikr without scheduled time
        if (dhikr.when == null) continue;

        final dhikrDate = DateTime(
          dhikr.when!.year,
          dhikr.when!.month,
          dhikr.when!.day,
        );

        // Check if dhikr is for the target date and is completed
        if (dhikrDate == targetDate &&
            dhikr.currentCount != null &&
            dhikr.currentCount! >= dhikr.times) {
          completedCount++;
        }
      }

      return completedCount;
    } catch (e) {
      return 0; // Return 0 on error to prevent UI issues
    }
  }

  /// Get activity level (0-4) for a specific date based on completed dhikr count
  static Future<int> getActivityLevelForDate(DateTime date) async {
    try {
      final completedCount = await getCompletedDhikrCountForDate(date);
      return _convertCountToActivityLevel(completedCount);
    } catch (e) {
      return 0; // Return 0 on error
    }
  }

  /// Convert completed dhikr count to activity level (0-4)
  static int _convertCountToActivityLevel(int completedCount) {
    if (completedCount == 0) return 0;
    if (completedCount == 1) return 1;
    if (completedCount == 2) return 2;
    if (completedCount == 3) return 3;
    return 4; // 4 or more completed dhikr
  }

  /// Get activity data for a date range (useful for bulk loading)
  static Future<Map<DateTime, int>> getActivityDataForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      if (!isInitialized) await init();

      final Map<DateTime, int> activityData = {};
      final dhikrList = _dhikrBox.values.toList();

      // Initialize all dates with 0 activity
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
        activityData[DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
            )] =
            0;
        currentDate = currentDate.add(const Duration(days: 1));
      }

      // Count completed dhikr for each date
      for (final dhikr in dhikrList) {
        // Skip dhikr without scheduled time
        if (dhikr.when == null) continue;

        final dhikrDate = DateTime(
          dhikr.when!.year,
          dhikr.when!.month,
          dhikr.when!.day,
        );

        // Check if dhikr date is within our range and is completed
        if (activityData.containsKey(dhikrDate) &&
            dhikr.currentCount != null &&
            dhikr.currentCount! >= dhikr.times) {
          activityData[dhikrDate] = activityData[dhikrDate]! + 1;
        }
      }

      // Convert counts to activity levels
      final Map<DateTime, int> activityLevels = {};
      activityData.forEach((date, count) {
        activityLevels[date] = _convertCountToActivityLevel(count);
      });

      return activityLevels;
    } catch (e) {
      return {}; // Return empty map on error
    }
  }

  // Update - Update dhikr
  static Future<void> updateDhikr(Dhikr updatedDhikr) async {
    try {
      if (!isInitialized) await init();

      // Find the index of the dhikr to update
      final index = _dhikrBox.values.toList().indexWhere(
        (dhikr) => dhikr.id == updatedDhikr.id,
      );

      if (index != -1) {
        await _dhikrBox.putAt(index, updatedDhikr);
      } else {
        throw Exception('Dhikr not found for update');
      }
    } catch (e) {
      throw Exception('Failed to update dhikr: $e');
    }
  }

  // Update - Decrement dhikr count
  static Future<void> decrementDhikrCount(int dhikrId) async {
    try {
      if (!isInitialized) await init();

      final dhikr = getDhikrById(dhikrId);
      if (dhikr != null) {
        final currentCount = dhikr.currentCount ?? 0;
        // Only decrement if current count is greater than 0
        if (currentCount > 0) {
          final updatedDhikr = Dhikr(
            id: dhikr.id,
            dhikrTitle: dhikr.dhikrTitle,
            dhikr: dhikr.dhikr,
            times: dhikr.times,
            when: dhikr.when,
            currentCount: currentCount - 1,
          );

          // Find the index and update
          final index = _dhikrBox.values.toList().indexWhere(
            (d) => d.id == dhikrId,
          );

          if (index != -1) {
            await _dhikrBox.putAt(index, updatedDhikr);
          } else {
            throw Exception('Dhikr not found');
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to decrement dhikr count: $e');
    }
  }

  // Update - Reset dhikr count to 0
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

        // Find the index and update
        final index = _dhikrBox.values.toList().indexWhere(
          (d) => d.id == dhikrId,
        );

        if (index != -1) {
          await _dhikrBox.putAt(index, updatedDhikr);
        } else {
          throw Exception('Dhikr not found');
        }
      }
    } catch (e) {
      throw Exception('Failed to reset dhikr count: $e');
    }
  }

  // Delete - Delete dhikr by ID
  static Future<void> deleteDhikr(int dhikrId) async {
    try {
      if (!isInitialized) await init();

      final index = _dhikrBox.values.toList().indexWhere(
        (dhikr) => dhikr.id == dhikrId,
      );

      if (index != -1) {
        await _dhikrBox.deleteAt(index);
      } else {
        throw Exception('Dhikr not found for deletion');
      }
    } catch (e) {
      throw Exception('Failed to delete dhikr: $e');
    }
  }

  // Delete - Clear all dhikr
  static Future<void> clearAllDhikr() async {
    try {
      if (!isInitialized) await init();
      await _dhikrBox.clear();
    } catch (e) {
      throw Exception('Failed to clear all dhikr: $e');
    }
  }

  // Utility - Get dhikr count
  static int getDhikrCount() {
    try {
      if (!isInitialized) return 0;
      return _dhikrBox.length;
    } catch (e) {
      return 0;
    }
  }

  // Listen to changes in the database
  static Stream<BoxEvent> watchDhikr() {
    if (!isInitialized) {
      throw Exception('Database not initialized. Call DbService.init() first.');
    }
    return _dhikrBox.watch();
  }

  // Close the database (call this when app is disposed)
  static Future<void> close() async {
    try {
      if (_box != null && _box!.isOpen) {
        await _box!.close();
      }
      _isInitialized = false;
    } catch (e) {
      // Ignore close errors
    }
  }
}
