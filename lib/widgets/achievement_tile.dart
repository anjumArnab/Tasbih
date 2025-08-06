// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/achievement.dart';

class AchievementTile extends StatelessWidget {
  final Achievement achievement;

  const AchievementTile({super.key, required this.achievement});

  static const Color primaryColor = Color(0xFF0F4C75);
  static const Color secondaryColor = Color(0xFF3282B8);
  static const Color accentColor = Color(0xFF00A8CC);
  static const Color lightAccent = Color(0xFFBBE1FA);
  static const Color backgroundColor = Color(0xFFF8FBFF);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Achievement Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  achievement.isUnlocked
                      ? _getCategoryColor()
                      : lightAccent.withOpacity(0.5),
            ),
            child: Icon(
              _getCategoryIcon(),
              color: achievement.isUnlocked ? Colors.white : primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Achievement Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color:
                              achievement.isUnlocked
                                  ? primaryColor
                                  : Colors.grey[600],
                        ),
                      ),
                    ),
                    if (achievement.isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${achievement.points}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${achievement.targetCount} ${achievement.dhikrType}',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (achievement.isUnlocked &&
                        achievement.unlockedAt != null) ...[
                      const Spacer(),
                      Text(
                        _formatDateTime(achievement.unlockedAt!),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor() {
    switch (achievement.category) {
      case AchievementCategory.tasbeh:
        return primaryColor;
      case AchievementCategory.consistency:
        return secondaryColor;
      case AchievementCategory.milestone:
        return accentColor;
    }
  }

  IconData _getCategoryIcon() {
    switch (achievement.category) {
      case AchievementCategory.tasbeh:
        return Icons.repeat;
      case AchievementCategory.consistency:
        return Icons.trending_up;
      case AchievementCategory.milestone:
        return Icons.flag;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }
}
