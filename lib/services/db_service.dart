import 'package:hive/hive.dart';
import '../models/dhikr.dart';
import '../data/init_dhikr_data.dart';

class DbService {
  static const String _boxName = 'dhikr_box';
  static const String _isInitializedKey = 'is_initialized';
  static Box<Dhikr>? _box;
  static bool _isInitialized = false; // Add this flag

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

      // Add initial data if this is the first time opening the app
      await _addInitialDataIfNeeded();

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize database: $e');
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

  // Read - Get upcoming dhikr
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
                dhikr.when.isAfter(now) &&
                (dhikr.currentCount ?? 0) < dhikr.times,
          )
          .toList()
        ..sort((a, b) => a.when.compareTo(b.when));
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
        ..sort((a, b) => b.when.compareTo(a.when));
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
        final dhikrDate = DateTime(
          dhikr.when.year,
          dhikr.when.month,
          dhikr.when.day,
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
        final dhikrDate = DateTime(
          dhikr.when.year,
          dhikr.when.month,
          dhikr.when.day,
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

  // Update - Increment dhikr count
  static Future<void> incrementDhikrCount(int dhikrId) async {
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
          currentCount: (dhikr.currentCount ?? 0) + 1,
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
      throw Exception('Failed to increment dhikr count: $e');
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
