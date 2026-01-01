// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlaylistAdapter extends TypeAdapter<Playlist> {
  @override
  final int typeId = 2;

  @override
  Playlist read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Playlist(
      name: fields[0] as String,
      songPaths: (fields[1] as List).cast<String>(),
      lastPlayedIndex: fields[2] == null ? 0 : (fields[2] as num).toInt(),
      lastPlayedPosition: fields[3] == null ? 0 : (fields[3] as num).toInt(),
      shuffle: fields[4] == null ? false : fields[4] as bool,
      repeatMode: fields[5] == null ? 0 : (fields[5] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, Playlist obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.songPaths)
      ..writeByte(2)
      ..write(obj.lastPlayedIndex)
      ..writeByte(3)
      ..write(obj.lastPlayedPosition)
      ..writeByte(4)
      ..write(obj.shuffle)
      ..writeByte(5)
      ..write(obj.repeatMode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
