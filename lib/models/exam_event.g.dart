// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExamEventAdapter extends TypeAdapter<ExamEvent> {
  @override
  final int typeId = 0;

  @override
  ExamEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExamEvent(
      title: fields[0] as String,
      dateTime: fields[1] as DateTime,
      location: fields[2] as String,
      latitude: fields[3] as double,
      longitude: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ExamEvent obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.dateTime)
      ..writeByte(2)
      ..write(obj.location)
      ..writeByte(3)
      ..write(obj.latitude)
      ..writeByte(4)
      ..write(obj.longitude);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
