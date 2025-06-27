import 'package:hive/hive.dart';
import '../models/dhikr.dart';
import '../data/init_dhikr_data.dart';

class DbService {
  static const String _boxName = 'dhikr_box';
  static const String _isInitializedKey = 'is_initialized';
  static Box<Dhikr>? _box;

  // Initialize Hive and open the box
  static Future<void> init() async {
    // Register the adapter if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DhikrAdapter());
    }

    _box = await Hive.openBox<Dhikr>(_boxName);

    // Add initial data if this is the first time opening the app
    await _addInitialDataIfNeeded();
  }

  // Add initial data if the database hasn't been initialized before
  static Future<void> _addInitialDataIfNeeded() async {
    try {
      // Check if we've already added initial data
      final preferences = await Hive.openBox('app_preferences');
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
        await preferences.close();
      } else {
        await preferences.close();
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

  // Create - Add a new dhikr
  static Future<int> addDhikr(Dhikr dhikr) async {
    try {
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
      return _dhikrBox.values.toList();
    } catch (e) {
      throw Exception('Failed to get dhikr list: $e');
    }
  }

  // Read - Get dhikr by ID
  static Dhikr? getDhikrById(int id) {
    try {
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
      return _dhikrBox.values
          .where((dhikr) => (dhikr.currentCount ?? 0) >= dhikr.times)
          .toList()
        ..sort((a, b) => b.when.compareTo(a.when));
    } catch (e) {
      throw Exception('Failed to get completed dhikr: $e');
    }
  }

  // Update - Update dhikr
  static Future<void> updateDhikr(Dhikr updatedDhikr) async {
    try {
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
      await _dhikrBox.clear();
    } catch (e) {
      throw Exception('Failed to clear all dhikr: $e');
    }
  }

  // Utility - Get dhikr count
  static int getDhikrCount() {
    try {
      return _dhikrBox.length;
    } catch (e) {
      return 0;
    }
  }

  // Listen to changes in the database
  static Stream<BoxEvent> watchDhikr() {
    return _dhikrBox.watch();
  }
}
