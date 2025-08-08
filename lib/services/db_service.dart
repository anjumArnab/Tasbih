import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/dhikr.dart';
import '../data/init_dhikr_data.dart';
import '../services/achievement_service.dart';

class DbService {
  static const String _boxName = 'dhikr_box';
  static const String _activityBoxName = 'daily_activity_box';
  static const String _isInitializedKey = 'is_initialized';
  static const String _lastResetDateKey = 'last_reset_date';

  static Box<Dhikr>? _box;
  static Box? _activityBox; // New box for storing daily activity snapshots
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

  // Initialize Hive and open the boxes
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

      // Open dhikr box if not already open
      if (_box == null || !_box!.isOpen) {
        _box = await Hive.openBox<Dhikr>(_boxName);
      }

      // Open activity tracking box
      if (_activityBox == null || !_activityBox!.isOpen) {
        _activityBox = await Hive.openBox(_activityBoxName);
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

          // Update today's activity snapshot immediately
          await _updateTodayActivitySnapshot();

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

  // Store or update today's activity snapshot
  static Future<void> _updateTodayActivitySnapshot() async {
    try {
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';

      // Count completed dhikr for today
      final completedCount = _getTodayCompletedDhikrCount();
      final activityLevel = _convertCountToActivityLevel(completedCount);

      // Store today's activity data
      await _activityBox!.put(todayKey, {
        'date': todayKey,
        'completedCount': completedCount,
        'activityLevel': activityLevel,
        'timestamp': today.millisecondsSinceEpoch,
      });

      debugPrint(
        'Updated today\'s activity: $completedCount completed, level $activityLevel',
      );
    } catch (e) {
      debugPrint('Error updating today\'s activity snapshot: $e');
    }
  }

  // Get today's completed dhikr count from current state
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
      debugPrint('Error getting today\'s completed count: $e');
      return 0;
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

      // If it's a new day, store yesterday's activity and reset all counters
      if (lastResetDate != todayString) {
        // Store yesterday's final activity snapshot before resetting
        if (lastResetDate.isNotEmpty) {
          await _storeYesterdayActivitySnapshot(lastResetDate);
        }

        // Reset all dhikr counters
        await _resetAllDhikrCounters();

        // Update last reset date
        await preferences.put(_lastResetDateKey, todayString);
        debugPrint('Daily dhikr counters reset for date: $todayString');

        // Initialize today's activity snapshot with 0
        await _initializeTodayActivitySnapshot();

        // Check if we need to break the streak due to missed day
        await _checkStreakBreak(preferences, todayString, lastResetDate);
      } else {
        // Same day - just update today's activity snapshot
        await _updateTodayActivitySnapshot();
      }
    } catch (e) {
      debugPrint('Error checking daily reset: $e');
      // Don't throw here to prevent app initialization failure
    }
  }

  // Store yesterday's final activity snapshot
  static Future<void> _storeYesterdayActivitySnapshot(
    String lastResetDate,
  ) async {
    try {
      // Get yesterday's completed count before reset
      final completedCount = _getTodayCompletedDhikrCount();
      final activityLevel = _convertCountToActivityLevel(completedCount);

      // Store yesterday's final activity
      await _activityBox!.put(lastResetDate, {
        'date': lastResetDate,
        'completedCount': completedCount,
        'activityLevel': activityLevel,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isFinal': true, // Mark as final snapshot
      });

      debugPrint(
        'Stored yesterday\'s final activity ($lastResetDate): $completedCount completed, level $activityLevel',
      );
    } catch (e) {
      debugPrint('Error storing yesterday\'s activity snapshot: $e');
    }
  }

  // Initialize today's activity snapshot with 0
  static Future<void> _initializeTodayActivitySnapshot() async {
    try {
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';

      await _activityBox!.put(todayKey, {
        'date': todayKey,
        'completedCount': 0,
        'activityLevel': 0,
        'timestamp': today.millisecondsSinceEpoch,
      });

      debugPrint('Initialized today\'s activity snapshot: 0 completed');
    } catch (e) {
      debugPrint('Error initializing today\'s activity snapshot: $e');
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

  // Updated method for checking daily completion and updating streak
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

      // Store current activity before manual reset
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';
      await _storeYesterdayActivitySnapshot(todayKey);

      await _resetAllDhikrCounters();

      // Initialize fresh activity snapshot
      await _initializeTodayActivitySnapshot();

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

        // Initialize today's activity snapshot
        await _initializeTodayActivitySnapshot();
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

  // Get the activity box instance
  static Box get _activityStorageBox {
    if (_activityBox == null || !_activityBox!.isOpen) {
      throw Exception(
        'Activity database not initialized. Call DbService.init() first.',
      );
    }
    return _activityBox!;
  }

  // Check if database is initialized
  static bool get isInitialized =>
      _isInitialized &&
      _box != null &&
      _box!.isOpen &&
      _activityBox != null &&
      _activityBox!.isOpen;

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

  // Read - Get completed dhikr (current day only)
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

  /// Get count of completed dhikr sessions for a specific date from stored activity data
  static Future<int> getCompletedDhikrCountForDate(DateTime date) async {
    try {
      if (!isInitialized) await init();

      final dateKey = '${date.year}-${date.month}-${date.day}';
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';

      // If asking for today, get current live count
      if (dateKey == todayKey) {
        return _getTodayCompletedDhikrCount();
      }

      // For past dates, get from stored activity data
      final activityData = _activityStorageBox.get(dateKey);
      if (activityData != null && activityData is Map) {
        return activityData['completedCount'] ?? 0;
      }

      return 0; // No data for this date
    } catch (e) {
      debugPrint('Error getting completed dhikr count for date: $e');
      return 0; // Return 0 on error to prevent UI issues
    }
  }

  /// Get activity level (0-4) for a specific date
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

  /// Get activity data for a date range using stored historical data
  static Future<Map<DateTime, int>> getActivityDataForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      if (!isInitialized) await init();

      final Map<DateTime, int> activityLevels = {};

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
        final dateKey =
            '${currentDate.year}-${currentDate.month}-${currentDate.day}';
        final today = DateTime.now();
        final todayKey = '${today.year}-${today.month}-${today.day}';

        int activityLevel = 0;

        // If this is today, get current live activity level
        if (dateKey == todayKey) {
          final completedCount = _getTodayCompletedDhikrCount();
          activityLevel = _convertCountToActivityLevel(completedCount);
        } else {
          // For past dates, get from stored activity data
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
      debugPrint('Error getting activity data for date range: $e');
      return {}; // Return empty map on error
    }
  }

  /// Get total dhikr sessions for the year from stored activity data
  static Future<int> getTotalDhikrSessionsForYear([int? year]) async {
    try {
      if (!isInitialized) await init();

      final targetYear = year ?? DateTime.now().year;
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';

      int totalSessions = 0;

      // Get all activity data keys for the year
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
          // Skip invalid keys
          continue;
        }
      }

      // For current year, check if today's data needs to be updated
      // (in case today's snapshot is outdated)
      if (targetYear == today.year) {
        final todayStoredData = _activityStorageBox.get(todayKey);
        final currentTodayCount = _getTodayCompletedDhikrCount();

        if (todayStoredData != null && todayStoredData is Map) {
          final storedTodayCount = todayStoredData['completedCount'] ?? 0;

          // If live count is different from stored count, update the total
          if (currentTodayCount != storedTodayCount) {
            // Replace stored today's count with live count
            totalSessions =
                totalSessions - (storedTodayCount as int) + currentTodayCount;
          }
        } else {
          // Today's data not stored yet, add the current count
          totalSessions += currentTodayCount;
        }
      }

      return totalSessions;
    } catch (e) {
      debugPrint('Error getting total dhikr sessions for year: $e');
      return 0;
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

        // Update today's activity snapshot
        await _updateTodayActivitySnapshot();
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

            // Update today's activity snapshot
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

          // Update today's activity snapshot
          await _updateTodayActivitySnapshot();
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

        // Update today's activity snapshot after deletion
        await _updateTodayActivitySnapshot();
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

      // Reset today's activity snapshot to 0
      await _initializeTodayActivitySnapshot();
    } catch (e) {
      throw Exception('Failed to clear all dhikr: $e');
    }
  }

  // Clear all historical activity data (use with caution)
  static Future<void> clearAllActivityData() async {
    try {
      if (!isInitialized) await init();
      await _activityStorageBox.clear();

      // Reinitialize today's activity snapshot
      await _initializeTodayActivitySnapshot();

      debugPrint('All historical activity data cleared');
    } catch (e) {
      throw Exception('Failed to clear activity data: $e');
    }
  }

  // Get activity data for debugging purposes
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

  // Listen to changes in the activity database
  static Stream<BoxEvent> watchActivityData() {
    if (!isInitialized) {
      throw Exception('Database not initialized. Call DbService.init() first.');
    }
    return _activityStorageBox.watch();
  }

  // Close the database (call this when app is disposed)
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
      // Ignore close errors
      debugPrint('Error closing database: $e');
    }
  }

  // Export activity data (for backup/debugging)
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

  // Import activity data (for restore/migration)
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

        debugPrint(
          'Successfully imported ${activityData.length} activity records',
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Failed to import activity data: $e');
      return false;
    }
  }
}
