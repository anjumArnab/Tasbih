import '../models/dhikr.dart';

class InitialDhikrData {
  /// Returns the list of initial dhikr data to be added when the app is first opened
  static List<Dhikr> getInitialDhikrList() {
    final now = DateTime.now();

    return [
      Dhikr(
        id: 0,
        dhikrTitle: 'Subhan Allah',
        dhikr: 'سُبْحَانَ اللهِ - Glory be to Allah',
        times: 33,
        when: now.add(const Duration(hours: 2)),
        currentCount: 0,
      ),
      Dhikr(
        id: 1,
        dhikrTitle: 'Alhamdulillah',
        dhikr: 'الْحَمْدُ لِلَّهِ - All praise is due to Allah',
        times: 33,
        when: now.add(const Duration(hours: 1)),
        currentCount: 0,
      ),
      Dhikr(
        id: 2,
        dhikrTitle: 'Allahu Akbar',
        dhikr: 'اللهُ أَكْبَرُ - Allah is the Greatest',
        times: 34,
        when: now.add(const Duration(minutes: 30)),
        currentCount: 0,
      ),
      Dhikr(
        id: 3,
        dhikrTitle: 'La hawla wa la quwwata illa billah',
        dhikr:
            'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللهِ - There is no power except with Allah',
        times: 10,
        when: now.add(const Duration(hours: 1)),
        currentCount: 0,
      ),
      Dhikr(
        id: 4,
        dhikrTitle: 'Astaghfirullah',
        dhikr: 'أَسْتَغْفِرُ اللهَ - I seek forgiveness from Allah',
        times: 100,
        when: now.add(const Duration(hours: 2)),
        currentCount: 0,
      ),
      Dhikr(
        id: 5,
        dhikrTitle: 'La ilaha illa Allah',
        dhikr: 'لَا إِلَهَ إِلَّا اللهُ - There is no deity except Allah',
        times: 100,
        when: now.add(const Duration(hours: 3)),
        currentCount: 0,
      ),
    ];
  }
}
