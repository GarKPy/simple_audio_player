import 'package:hive_ce/hive_ce.dart';

part 'repeat_mode.g.dart';

@HiveType(typeId: 3)
enum RepeatMode {
  @HiveField(0)
  none,
  @HiveField(1)
  one,
  @HiveField(2)
  list,
}
