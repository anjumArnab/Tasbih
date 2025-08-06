import 'package:tasbih/models/achievement.dart';

class InitAchievementData {
  static List<Achievement> getInitialAchievements() {
    return [
      // Tasbeh Count Achievements
      Achievement(
        id: 'subhanallah_100',
        title: 'First Steps',
        description: 'Complete SubhanAllah 100 times',
        category: AchievementCategory.tasbeh,
        targetCount: 100,
        dhikrType: 'SubhanAllah',
        type: AchievementType.count,
        points: 10,
      ),

      Achievement(
        id: 'subhanallah_1000',
        title: 'Devoted Servant',
        description: 'Complete SubhanAllah 1000 times',
        category: AchievementCategory.tasbeh,
        targetCount: 1000,
        dhikrType: 'SubhanAllah',
        type: AchievementType.count,
        points: 50,
      ),

      Achievement(
        id: 'alhamdulillah_500',
        title: 'Grateful Heart',
        description: 'Complete Alhamdulillah 500 times',
        category: AchievementCategory.tasbeh,
        targetCount: 500,
        dhikrType: 'Alhamdulillah',
        type: AchievementType.count,
        points: 25,
      ),

      Achievement(
        id: 'allahuakbar_1000',
        title: 'Magnifier of Allah',
        description: 'Complete Allahu Akbar 1000 times',
        category: AchievementCategory.tasbeh,
        targetCount: 1000,
        dhikrType: 'Allahu Akbar',
        type: AchievementType.count,
        points: 50,
      ),

      Achievement(
        id: 'istighfar_333',
        title: 'Seeker of Forgiveness',
        description: 'Complete Astaghfirullah 333 times',
        category: AchievementCategory.tasbeh,
        targetCount: 333,
        dhikrType: 'Astaghfirullah',
        type: AchievementType.count,
        points: 30,
      ),

      Achievement(
        id: 'laailahaillallah_1000',
        title: 'Witness of Tawheed',
        description: 'Complete La ilaha illa Allah 1000 times',
        category: AchievementCategory.tasbeh,
        targetCount: 1000,
        dhikrType: 'La ilaha illa Allah',
        type: AchievementType.count,
        points: 60,
      ),

      // Streak Achievements
      Achievement(
        id: 'streak_3',
        title: 'Consistent Believer',
        description: 'Complete dhikr for 3 consecutive days',
        category: AchievementCategory.consistency,
        targetCount: 3,
        dhikrType: 'Any',
        type: AchievementType.streak,
        points: 15,
      ),

      Achievement(
        id: 'streak_7',
        title: 'Week Warrior',
        description: 'Complete dhikr for 7 consecutive days',
        category: AchievementCategory.consistency,
        targetCount: 7,
        dhikrType: 'Any',
        type: AchievementType.streak,
        points: 35,
      ),

      Achievement(
        id: 'streak_30',
        title: 'Month of Remembrance',
        description: 'Complete dhikr for 30 consecutive days',
        category: AchievementCategory.consistency,
        targetCount: 30,
        dhikrType: 'Any',
        type: AchievementType.streak,
        points: 100,
      ),

      Achievement(
        id: 'streak_100',
        title: 'Dedicated Worshipper',
        description: 'Complete dhikr for 100 consecutive days',
        category: AchievementCategory.consistency,
        targetCount: 100,
        dhikrType: 'Any',
        type: AchievementType.streak,
        points: 300,
      ),

      // Milestone Achievements
      Achievement(
        id: 'total_5000',
        title: 'Five Thousand Pearls',
        description: 'Complete 5000 total dhikr across all types',
        category: AchievementCategory.milestone,
        targetCount: 5000,
        dhikrType: 'All',
        type: AchievementType.count,
        points: 75,
      ),

      Achievement(
        id: 'total_10000',
        title: 'Ten Thousand Lights',
        description: 'Complete 10000 total dhikr across all types',
        category: AchievementCategory.milestone,
        targetCount: 10000,
        dhikrType: 'All',
        type: AchievementType.count,
        points: 150,
      ),

      Achievement(
        id: 'total_25000',
        title: 'Twenty Five Thousand Blessings',
        description: 'Complete 25000 total dhikr across all types',
        category: AchievementCategory.milestone,
        targetCount: 25000,
        dhikrType: 'All',
        type: AchievementType.count,
        points: 250,
      ),

      Achievement(
        id: 'total_50000',
        title: 'Fifty Thousand Praises',
        description: 'Complete 50000 total dhikr across all types',
        category: AchievementCategory.milestone,
        targetCount: 50000,
        dhikrType: 'All',
        type: AchievementType.count,
        points: 500,
      ),

      Achievement(
        id: 'total_100000',
        title: 'One Hundred Thousand Remembrances',
        description: 'Complete 100000 total dhikr - Ultimate Devotion',
        category: AchievementCategory.milestone,
        targetCount: 100000,
        dhikrType: 'All',
        type: AchievementType.count,
        points: 1000,
      ),
    ];
  }
}
