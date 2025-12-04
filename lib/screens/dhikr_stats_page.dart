// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../services/achievement_service.dart';
import 'activity.dart';
import 'achievements.dart';

class DhikrStatsPage extends StatefulWidget {
  const DhikrStatsPage({super.key});

  @override
  State<DhikrStatsPage> createState() => _DhikrStatsPageState();
}

class _DhikrStatsPageState extends State<DhikrStatsPage> {
  final AchievementService _achievementService = AchievementService();
  String selectedFilter = 'activity'; // Default to activity section

  // Keys for accessing child components - using correct generic types
  final GlobalKey<State<ActivitySection>> _activityKey =
      GlobalKey<State<ActivitySection>>();
  final GlobalKey<State<AchievementsSection>> _achievementsKey =
      GlobalKey<State<AchievementsSection>>();

  static const Color primaryColor = Color(0xFF0F4C75);
  static const Color secondaryColor = Color(0xFF3282B8);
  static const Color backgroundColor = Color(0xFFF8FBFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Achievements',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, secondaryColor],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Chips Section
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _buildFilterChip('Activity', 'activity'),
                  const SizedBox(width: 10),
                  _buildFilterChip('Achievements', 'achievements'),
                ],
              ),
            ),
            // Content Section
            Expanded(
              child:
                  selectedFilter == 'activity'
                      ? ActivitySection(key: _activityKey)
                      : AchievementsSection(key: _achievementsKey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient:
              isSelected
                  ? const LinearGradient(colors: [primaryColor, secondaryColor])
                  : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey[300]!,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _achievementService.dispose();
    super.dispose();
  }
}
