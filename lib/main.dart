import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lab4/services/location_reminder_notification.dart';
import 'screens/home_screen.dart';
import 'models/exam_event.dart';

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(ExamEventAdapter());
  await Hive.openBox<ExamEvent>('events');

  final locationService = LocationReminderService();
  await locationService.initialize();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exam Schedule',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}
