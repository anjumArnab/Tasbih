import 'package:hive/hive.dart';

part 'dhikr.g.dart';

@HiveType(typeId: 0)
class Dhikr {
  @HiveField(0)
  final int? id;

  @HiveField(1)
  final String dhikrTitle;

  @HiveField(2)
  final String dhikr;

  @HiveField(3)
  final int times;

  @HiveField(4)
  final DateTime? when;

  @HiveField(5)
  int? currentCount;

  Dhikr({
    this.id,
    required this.dhikrTitle,
    required this.dhikr,
    required this.times,
    this.when,
    this.currentCount = 0,
  });
}
