import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzData;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'golemons_daily_reminder';
  static const String _channelName = 'Daily Reminder';
  static const int _notifId = 0;

  static const String _keyEnabled = 'notif_enabled';
  static const String _keyHour = 'notif_hour';
  static const String _keyMinute = 'notif_minute';

  // ==========================================
  // 🍋 INITIALIZE
  // ==========================================
  static Future<void> initialize() async {
    tzData.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // 🍋 Create the notification channel explicitly on Android
    await _createNotificationChannel();

    // Request Android 13+ notification permission
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    // Re-schedule on app start if previously enabled
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    if (enabled) {
      final hour = prefs.getInt(_keyHour) ?? 20;
      final minute = prefs.getInt(_keyMinute) ?? 0;
      await scheduleDailyReminder(TimeOfDay(hour: hour, minute: minute));
    }
  }

  // ==========================================
  // 🍋 CREATE ANDROID NOTIFICATION CHANNEL
  // ==========================================
  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Daily mood journaling reminder from goLemons',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ==========================================
  // 🍋 CHECK IF NOTIFICATIONS ARE PERMITTED
  // ==========================================
  static Future<bool> areNotificationsEnabled() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final bool? granted =
        await androidImpl?.areNotificationsEnabled();
    return granted ?? false;
  }

  // ==========================================
  // 🍋 SHOW IMMEDIATE NOTIFICATION (to test channel works)
  // ==========================================
  static Future<void> showImmediateNotification() async {
    await _plugin.show(
      98,
      'goLemons Notifications are working! 🍋',
      'Your daily reminder is set up correctly.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
    print('🍋 Immediate notification sent!');
  }

  // ==========================================
  // 🍋 SCHEDULE DAILY REMINDER
  // ==========================================
  static Future<bool> scheduleDailyReminder(TimeOfDay time) async {
    try {
      await _plugin.cancel(_notifId);

      final tz.TZDateTime scheduledTime = _nextInstanceOfTime(time);

      print('🍋 Scheduling notification for: $scheduledTime (UTC)');
      print('🍋 Current UTC time: ${DateTime.now().toUtc()}');
      print('🍋 Difference: ${scheduledTime.difference(tz.TZDateTime.now(tz.UTC)).inMinutes} minutes from now');

      await _plugin.zonedSchedule(
        _notifId,
        'Time to squeeze your lemons! 🍋',
        'Don\'t forget to log your mood today. How are you feeling?',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription:
                'Daily mood journaling reminder from goLemons',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      // Save preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, true);
      await prefs.setInt(_keyHour, time.hour);
      await prefs.setInt(_keyMinute, time.minute);

      print('🍋 Notification scheduled successfully!');
      return true;
    } catch (e) {
      print('🍋 ERROR scheduling notification: $e');
      return false;
    }
  }

  // ==========================================
  // 🍋 CANCEL REMINDER
  // ==========================================
  static Future<void> cancelReminder() async {
    await _plugin.cancel(_notifId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, false);
    print('🍋 Notification cancelled.');
  }

  // ==========================================
  // 🍋 LOAD SAVED PREFERENCES
  // ==========================================
  static Future<Map<String, dynamic>> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool(_keyEnabled) ?? false,
      'hour': prefs.getInt(_keyHour) ?? 20,
      'minute': prefs.getInt(_keyMinute) ?? 0,
    };
  }

  // ==========================================
  // 🍋 TEST — fires in 5 seconds
  // ==========================================
  static Future<void> scheduleTestNotification() async {
    final DateTime fiveSecondsFromNow =
        DateTime.now().add(const Duration(seconds: 5));
    final DateTime utc = fiveSecondsFromNow.toUtc();
    final tz.TZDateTime tzScheduled = tz.TZDateTime.utc(
      utc.year, utc.month, utc.day,
      utc.hour, utc.minute, utc.second,
    );

    print('🍋 Test notification scheduled for: $tzScheduled (UTC)');

    await _plugin.zonedSchedule(
      99,
      'Time to squeeze your lemons! 🍋',
      'Don\'t forget to log your mood today. How are you feeling?',
      tzScheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    print('🍋 Test notification fires in 5 seconds!');
  }

  // ==========================================
  // 🍋 HELPER: next UTC TZDateTime — no tz.local used
  // ==========================================
  static tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final DateTime now = DateTime.now();

    DateTime local = DateTime(
      now.year, now.month, now.day,
      time.hour, time.minute,
    );

    if (local.isBefore(now)) {
      local = local.add(const Duration(days: 1));
    }

    final DateTime utc = local.toUtc();
    return tz.TZDateTime.utc(
      utc.year, utc.month, utc.day,
      utc.hour, utc.minute,
    );
  }
}