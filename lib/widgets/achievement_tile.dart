// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/achievement.dart';

class AchievementTile extends StatelessWidget {
  final Achievement achievement;

  const AchievementTile({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border:
            achievement.isUnlocked
                ? Border.all(
                  color: _getCategoryColor().withOpacity(0.5),
                  width: 2,
                )
                : Border.all(color: Colors.grey[300]!, width: 1),
        gradient:
            achievement.isUnlocked
                ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_getCategoryColor().withOpacity(0.1), Colors.white],
                )
                : null,
        color: achievement.isUnlocked ? null : Colors.grey[50],
        boxShadow:
            achievement.isUnlocked
                ? [
                  BoxShadow(
                    color: _getCategoryColor().withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Achievement Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    achievement.isUnlocked
                        ? _getCategoryColor()
                        : Colors.grey[300],
                boxShadow:
                    achievement.isUnlocked
                        ? [
                          BoxShadow(
                            color: _getCategoryColor().withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : null,
              ),
              child: Icon(
                _getCategoryIcon(),
                color: achievement.isUnlocked ? Colors.white : Colors.grey[600],
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

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
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color:
                                achievement.isUnlocked
                                    ? Colors.black87
                                    : Colors.grey[600],
                          ),
                        ),
                      ),
                      if (achievement.isUnlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${achievement.points}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          achievement.isUnlocked
                              ? Colors.grey[700]
                              : Colors.grey[500],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor().withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getCategoryText(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getCategoryColor(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.tablet, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${achievement.targetCount} ${achievement.dhikrType}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (achievement.isUnlocked &&
                          achievement.unlockedAt != null) ...[
                        const Spacer(),
                        Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(achievement.unlockedAt!),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Status Indicator
            const SizedBox(width: 12),
            Column(
              children: [
                if (achievement.isUnlocked)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withOpacity(0.2),
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.green,
                      size: 24,
                    ),
                  )
                else
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey[400]!, width: 2),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      color: Colors.grey[600],
                      size: 24,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (achievement.category) {
      case AchievementCategory.tasbeh:
        return Colors.blue;
      case AchievementCategory.consistency:
        return Colors.green;
      case AchievementCategory.milestone:
        return Colors.purple;
      case AchievementCategory.special:
        return Colors.orange;
      case AchievementCategory.spiritual:
        return Colors.teal;
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
      case AchievementCategory.special:
        return Icons.star_border;
      case AchievementCategory.spiritual:
        return Icons.self_improvement;
    }
  }

  String _getCategoryText() {
    switch (achievement.category) {
      case AchievementCategory.tasbeh:
        return 'TASBEH';
      case AchievementCategory.consistency:
        return 'CONSISTENCY';
      case AchievementCategory.milestone:
        return 'MILESTONE';
      case AchievementCategory.special:
        return 'SPECIAL';
      case AchievementCategory.spiritual:
        return 'SPIRITUAL';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }
}
