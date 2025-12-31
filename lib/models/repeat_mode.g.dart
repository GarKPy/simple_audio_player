// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repeat_mode.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RepeatModeAdapter extends TypeAdapter<RepeatMode> {
  @override
  final int typeId = 3;

  @override
  RepeatMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RepeatMode.none;
      case 1:
        return RepeatMode.one;
      case 2:
        return RepeatMode.list;
      default:
        return RepeatMode.none;
    }
  }

  @override
  void write(BinaryWriter writer, RepeatMode obj) {
    switch (obj) {
      case RepeatMode.none:
        writer.writeByte(0);
      case RepeatMode.one:
        writer.writeByte(1);
      case RepeatMode.list:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepeatModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
