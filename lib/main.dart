import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../screens/nav_wrapper.dart';
import '../services/db_service.dart';
import '../services/achievement_service.dart';
import '../services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize services
  try {
    //Initialize notification service first
    final notificationService = NotificationService();
    await notificationService.init();

    // Request notification permissions
    await notificationService.requestPermissions();

    // Initialize database service
    await DbService.init();

    // Initialize achievement service
    final achievementService = AchievementService();
    await achievementService.init();

    //Schedule notifications for existing dhikrs
    await _scheduleExistingDhikrNotifications();
  } catch (e) {
    // Silent error handling
  }

  runApp(const Tasbih());
}

// Helper function to schedule notifications for existing dhikrs
Future<void> _scheduleExistingDhikrNotifications() async {
  try {
    final notificationService = NotificationService();
    final allDhikrs = DbService.getAllDhikr();

    int scheduledCount = 0;
    for (final dhikr in allDhikrs) {
      if (dhikr.when != null && dhikr.id != null) {
        // Only schedule if the time is in the future
        if (dhikr.when!.isAfter(DateTime.now())) {
          await notificationService.scheduleDhikrNotification(dhikr);
          scheduledCount++;
        }
      }
    }

    debugPrint('Scheduled $scheduledCount notifications for existing dhikrs');
  } catch (e) {
    // Silent error handling
  }
}

class Tasbih extends StatelessWidget {
  const Tasbih({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tasbih',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black87),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      home: const NavigationWrapper(),
    );
  }
}
