part of 'dhikr.dart';

class DhikrAdapter extends TypeAdapter<Dhikr> {
  @override
  final int typeId = 0;

  @override
  Dhikr read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Dhikr(
      id: fields[0] as int?,
      dhikrTitle: fields[1] as String,
      dhikr: fields[2] as String,
      times: fields[3] as int,
      when: fields[4] as DateTime,
      currentCount: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Dhikr obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dhikrTitle)
      ..writeByte(2)
      ..write(obj.dhikr)
      ..writeByte(3)
      ..write(obj.times)
      ..writeByte(4)
      ..write(obj.when)
      ..writeByte(5)
      ..write(obj.currentCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DhikrAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
