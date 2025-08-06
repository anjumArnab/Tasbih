import 'package:hive/hive.dart';

part 'achievement.g.dart';

@HiveType(typeId: 1)
class Achievement {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final AchievementCategory category;

  @HiveField(4)
  final int targetCount;

  @HiveField(5)
  final String dhikrType;

  @HiveField(6)
  final AchievementType type;

  @HiveField(7)
  final int points;

  @HiveField(8)
  final DateTime? unlockedAt;

  @HiveField(9)
  final bool isUnlocked;

  @HiveField(10)
  final int currentProgress;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.targetCount,
    required this.dhikrType,
    required this.type,
    required this.points,
    this.unlockedAt,
    this.isUnlocked = false,
    this.currentProgress = 0,
  });

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    AchievementCategory? category,
    int? targetCount,
    String? dhikrType,
    AchievementType? type,
    int? points,
    DateTime? unlockedAt,
    bool? isUnlocked,
    int? currentProgress,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      targetCount: targetCount ?? this.targetCount,
      dhikrType: dhikrType ?? this.dhikrType,
      type: type ?? this.type,
      points: points ?? this.points,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      currentProgress: currentProgress ?? this.currentProgress,
    );
  }
}

@HiveType(typeId: 2)
enum AchievementCategory {
  @HiveField(0)
  tasbeh,
  @HiveField(1)
  consistency,
  @HiveField(2)
  milestone,
}

@HiveType(typeId: 3)
enum AchievementType {
  @HiveField(0)
  count,
  @HiveField(1)
  streak,
  @HiveField(2)
  time,
  @HiveField(3)
  special,
}
