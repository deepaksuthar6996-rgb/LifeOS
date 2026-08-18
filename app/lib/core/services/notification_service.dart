import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../models/event.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._init();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click if needed
      },
    );

    // Request permissions for Android 13+
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      try {
        await androidPlugin.requestExactAlarmsPermission();
      } catch (_) {}
    }
  }

  Future<void> scheduleEventNotifications(List<Event> events) async {
    // Clear all previously scheduled notifications first to avoid duplication
    await _notificationsPlugin.cancelAll();

    final now = DateTime.now();
    int notificationId = 1;

    // Loop through next 7 days to schedule events
    for (int i = 0; i < 7; i++) {
      final targetDate = now.add(Duration(days: i));
      final dateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);

      for (final event in events) {
        if (!event.occursOnDay(dateOnly)) continue;

        try {
          final timeParts = Event.parseTimeParts(event.startTime);
          final eventDateTime = DateTime(
            dateOnly.year,
            dateOnly.month,
            dateOnly.day,
            timeParts[0],
            timeParts[1],
          );

          // Only schedule if the alarm time is in the future
          if (eventDateTime.isAfter(now)) {
            // 1. Exact Event Trigger Alarm
            await _schedule(
              id: notificationId++,
              title: event.title,
              body: 'Ascend Event starting now!',
              dateTime: eventDateTime,
            );

            // 2. 5-Minute Pre-Alert Alarm
            final preAlertTime = eventDateTime.subtract(const Duration(minutes: 5));
            if (preAlertTime.isAfter(now)) {
              await _schedule(
                id: notificationId++,
                title: event.title,
                body: 'Ascend Event starting in 5 minutes.',
                dateTime: preAlertTime,
              );
            }
          }
        } catch (_) {
          // Ignore event formatting errors
        }
      }
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ascend_lifeos_alarms',
      'Ascend LifeOS Alarms',
      channelDescription: 'Exact time and pre-alerts for Ascend calendar events.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    // Make sure we resolve to correct timezone location
    tz.Location location;
    try {
      location = tz.local;
    } catch (_) {
      location = tz.UTC;
    }

    final scheduledTZDateTime = tz.TZDateTime.from(dateTime, location);

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTZDateTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
