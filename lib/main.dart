import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../screens/nav_wrapper.dart';
import '../models/dhikr.dart';
import '../models/achievement.dart';
import '../services/db_service.dart';
import '../services/achievement_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(DhikrAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(AchievementAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(AchievementCategoryAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(AchievementTypeAdapter());
  }

  // Initialize services
  try {
    // Initialize database service
    await DbService.init();
    debugPrint('Database service initialized successfully');

    // Initialize achievement service
    final achievementService = AchievementService();
    await achievementService.init();
    debugPrint('Achievement service initialized successfully');
  } catch (e) {
    debugPrint('Error initializing services: $e');
    // You might want to show an error dialog or handle this more gracefully
  }

  runApp(const Tasbih());
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
