import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/exam_event.dart';
import 'dart:async';

class LocationReminderService {
  static final LocationReminderService _instance =
      LocationReminderService._internal();
  factory LocationReminderService() => _instance;
  LocationReminderService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Timer? _locationCheckTimer;
  final double _reminderRadius = 1000;

  Future<void> initialize() async {
    final initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final initializationSettingsIOS = DarwinInitializationSettings();
    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications
        .initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {},
    )
        .then((_) {
      print('Notifications initialized successfully');
    }).catchError((e) {
      print('Failed to initialize notifications: $e');
    });

    await _requestNotificationPermission();
    await _requestLocationPermission();

    await _createNotificationChannel();
    _startLocationChecking();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }
  }

  void _startLocationChecking() {
    _locationCheckTimer?.cancel();
    _locationCheckTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      await _checkNearbyExams();
    });
  }

  Future<void> _checkNearbyExams() async {
    try {
      final Position currentPosition = await Geolocator.getCurrentPosition();
      print('Current Position: $currentPosition');
      final examBox = Hive.box<ExamEvent>('events');

      for (var event in examBox.values) {
        if (event.dateTime.isAfter(DateTime.now()) &&
            event.dateTime.isBefore(DateTime.now().add(Duration(hours: 24)))) {
          double distance = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            event.latitude,
            event.longitude,
          );

          print('Distance to event: $distance meters');

          if (distance <= _reminderRadius && !event.hasLocationAlertShown) {
            await _showNotification(event);
            event.hasLocationAlertShown = true;
            await event.save();
          }
        }
      }
    } catch (e) {
      print('Error checking nearby exams: $e');
    }
  }

  Future<void> _showNotification(ExamEvent event) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'exam_reminder_channel',
      'Exam Reminders',
      channelDescription: 'Notifications for nearby exam locations',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications
        .show(
      event.hashCode,
      'Upcoming Exam Nearby',
      'You are near the location of your ${event.title} exam scheduled for ${_formatDateTime(event.dateTime)}',
      platformDetails,
    )
        .then((_) {
      print('Notification triggered for ${event.title}');
    }).catchError((e) {
      print('Failed to show notification: $e');
    });
  }

  Future<void> checkLocationNow() async {
    print('Manually triggering location check');
    await _checkNearbyExams();
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _locationCheckTimer?.cancel();
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'exam_reminder_channel',
      'Exam Reminders',
      description: 'Notifications for nearby exam locations',
      importance: Importance.high,
      playSound: true,
    );

    final androidFlutterLocalNotificationsPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidFlutterLocalNotificationsPlugin != null) {
      await androidFlutterLocalNotificationsPlugin
          .createNotificationChannel(channel);
      print('Notification channel created successfully');
    } else {
      print('Failed to create notification channel');
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled() ==
        false) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }
}
