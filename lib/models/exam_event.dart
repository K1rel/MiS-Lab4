import 'package:hive/hive.dart';

part 'exam_event.g.dart'; // This will be generated

@HiveType(typeId: 0)
class ExamEvent extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  DateTime dateTime;

  @HiveField(2)
  String location;

  @HiveField(3)
  double latitude;

  @HiveField(4)
  double longitude;
  @HiveField(5)
  bool hasLocationAlertShown = false;

  ExamEvent({
    required this.title,
    required this.dateTime,
    required this.location,
    required this.latitude,
    required this.longitude,
  });
}
