import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/reminder_planner.dart';
import 'reminder_scheduler.dart';

/// 基于 `flutter_local_notifications` 的真实实现。
class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  static const String channelId = 'birthday_reminders';
  static const String channelName = '生日提醒';

  /// 生日提醒用「不准时但省电」的模式即可。
  ///
  /// 这样不需要 `SCHEDULE_EXACT_ALARM` 这类敏感权限，而且提前 3 天的提醒
  /// 本来也不需要精确到分钟。
  static const AndroidScheduleMode scheduleMode =
      AndroidScheduleMode.inexactAllowWhileIdle;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: '生日前与生日当天的提醒',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  /// 拿不到系统时区时，按当前 UTC 偏移去找一个等价的城市时区。
  static const List<String> _fallbackZones = <String>[
    'Asia/Shanghai',
    'Asia/Hong_Kong',
    'Asia/Taipei',
    'Asia/Tokyo',
    'Asia/Seoul',
    'Asia/Singapore',
    'Asia/Kolkata',
    'Europe/London',
    'Europe/Berlin',
    'Europe/Moscow',
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/Sao_Paulo',
    'Australia/Sydney',
    'Pacific/Auckland',
    'UTC',
  ];

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();

    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    const DarwinInitializationSettings darwin = DarwinInitializationSettings(
      // 权限在用户真正开启提醒时再请求，避免一进 App 就弹窗。
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );
    _initialized = true;
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      return;
    } on Object {
      // 继续尝试偏移量兜底方案。
    }
    final Duration offset = DateTime.now().timeZoneOffset;
    for (final String name in _fallbackZones) {
      try {
        final tz.Location location = tz.getLocation(name);
        if (tz.TZDateTime.now(location).timeZoneOffset == offset) {
          tz.setLocalLocation(location);
          return;
        }
      } on Object {
        continue;
      }
    }
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (kIsWeb) return false;
    // 用 defaultTargetPlatform 代替 dart:io 的 Platform，
    // 这样这个文件在 Web 上也能编译通过。
    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final bool? granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IOSFlutterLocalNotificationsPlugin? ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final bool? granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  @override
  Future<void> apply(List<PendingReminder> reminders) async {
    await initialize();
    await _plugin.cancelAll();
    for (final PendingReminder reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.scheduledAt, tz.local),
        notificationDetails: _details,
        androidScheduleMode: scheduleMode,
        payload: reminder.payload,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  @override
  Future<List<int>> pendingIds() async {
    await initialize();
    final List<PendingNotificationRequest> pending = await _plugin
        .pendingNotificationRequests();
    return pending.map((PendingNotificationRequest e) => e.id).toList();
  }
}
