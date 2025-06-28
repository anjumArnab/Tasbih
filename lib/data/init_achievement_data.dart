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
        targetCount: 33,
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

      // Special Time-based Achievements
      Achievement(
        id: 'fajr_dhikr',
        title: 'Dawn Remembrance',
        description: 'Complete 100 dhikr after Fajr prayer',
        category: AchievementCategory.special,
        targetCount: 100,
        dhikrType: 'Any',
        type: AchievementType.special,
        points: 40,
      ),

      Achievement(
        id: 'maghrib_dhikr',
        title: 'Sunset Serenity',
        description: 'Complete 100 dhikr after Maghrib prayer',
        category: AchievementCategory.special,
        targetCount: 100,
        dhikrType: 'Any',
        type: AchievementType.special,
        points: 40,
      ),

      Achievement(
        id: 'ramadan_dedication',
        title: 'Ramadan Devotee',
        description: 'Complete 1000 dhikr during Ramadan',
        category: AchievementCategory.special,
        targetCount: 1000,
        dhikrType: 'Any',
        type: AchievementType.special,
        points: 200,
      ),

      Achievement(
        id: 'laylatul_qadr',
        title: 'Night of Power',
        description: 'Complete 1000 dhikr on Laylatul Qadr',
        category: AchievementCategory.special,
        targetCount: 1000,
        dhikrType: 'Any',
        type: AchievementType.special,
        points: 500,
      ),

      Achievement(
        id: 'friday_blessing',
        title: 'Blessed Friday',
        description: 'Complete dhikr every Friday for 4 weeks',
        category: AchievementCategory.special,
        targetCount: 4,
        dhikrType: 'Any',
        type: AchievementType.special,
        points: 80,
      ),

      // Spiritual Achievements
      Achievement(
        id: 'morning_evening',
        title: 'Morning & Evening Guardian',
        description: 'Complete morning and evening adhkar for 7 days',
        category: AchievementCategory.spiritual,
        targetCount: 7,
        dhikrType: 'Adhkar',
        type: AchievementType.special,
        points: 70,
      ),

      Achievement(
        id: 'istighfar_master',
        title: 'Master of Seeking Forgiveness',
        description: 'Complete Istighfar 10000 times',
        category: AchievementCategory.spiritual,
        targetCount: 10000,
        dhikrType: 'Astaghfirullah',
        type: AchievementType.count,
        points: 200,
      ),

      Achievement(
        id: 'salawat_lover',
        title: 'Lover of the Prophet',
        description: 'Send 1000 Salawat upon Prophet Muhammad (PBUH)',
        category: AchievementCategory.spiritual,
        targetCount: 1000,
        dhikrType: 'Salawat',
        type: AchievementType.count,
        points: 100,
      ),

      Achievement(
        id: 'dua_devoted',
        title: 'Devoted in Dua',
        description: 'Complete 500 duas and supplications',
        category: AchievementCategory.spiritual,
        targetCount: 500,
        dhikrType: 'Dua',
        type: AchievementType.count,
        points: 60,
      ),

      Achievement(
        id: 'tahajjud_warrior',
        title: 'Night Prayer Warrior',
        description: 'Complete 100 dhikr during Tahajjud time',
        category: AchievementCategory.spiritual,
        targetCount: 100,
        dhikrType: 'Any',
        type: AchievementType.special,
        points: 120,
      ),

      Achievement(
        id: 'perfect_balance',
        title: 'Perfect Balance',
        description:
            'Complete 100 each of SubhanAllah, Alhamdulillah, and Allahu Akbar',
        category: AchievementCategory.spiritual,
        targetCount: 300,
        dhikrType: 'Balanced',
        type: AchievementType.special,
        points: 90,
      ),

      Achievement(
        id: 'quran_companion',
        title: 'Quran Companion',
        description: 'Complete dhikr while reading Quran 10 times',
        category: AchievementCategory.spiritual,
        targetCount: 10,
        dhikrType: 'Any',
        type: AchievementType.special,
        points: 80,
      ),

      Achievement(
        id: 'charity_dhikr',
        title: 'Generous Rememberer',
        description: 'Complete 100 dhikr after giving charity',
        category: AchievementCategory.spiritual,
        targetCount: 100,
        dhikrType: 'Any',
        type: AchievementType.special,
        points: 100,
      ),

      Achievement(
        id: 'hajj_pilgrim',
        title: 'Spiritual Pilgrim',
        description: 'Complete 2000 dhikr during Hajj/Umrah',
        category: AchievementCategory.spiritual,
        targetCount: 2000,
        dhikrType: 'Any',
        type: AchievementType.special,
        points: 300,
      ),

      Achievement(
        id: 'dhikr_master',
        title: 'Master of Remembrance',
        description: 'Unlock all other achievements',
        category: AchievementCategory.milestone,
        targetCount: 29,
        dhikrType: 'All',
        type: AchievementType.special,
        points: 2000,
      ),
    ];
  }
}
