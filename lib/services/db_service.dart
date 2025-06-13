import 'package:hive/hive.dart';
import '../models/dhikr.dart';

class DbService {
  static const String _boxName = 'dhikr_box';
  static Box<Dhikr>? _box;

  // Initialize Hive and open the box
  static Future<void> init() async {
    // Register the adapter if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DhikrAdapter());
    }

    _box = await Hive.openBox<Dhikr>(_boxName);
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
      // Generate a new ID based on the current length
      final newId = _dhikrBox.length;
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
        await updateDhikr(updatedDhikr);
      }
    } catch (e) {
      throw Exception('Failed to increment dhikr count: $e');
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

  // Close the database
  static Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
  }

  // Listen to changes in the database
  static Stream<BoxEvent> watchDhikr() {
    return _dhikrBox.watch();
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
          await updateDhikr(updatedDhikr);
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
        await updateDhikr(updatedDhikr);
      }
    } catch (e) {
      throw Exception('Failed to reset dhikr count: $e');
    }
  }
}
