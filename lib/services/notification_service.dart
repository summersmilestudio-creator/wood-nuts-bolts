import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Re-engagement notifications.
///
/// Two things made the old version unreliable:
///  1. nothing ever proved to the user that notifications arrive at all;
///  2. the channel was only created lazily by the first scheduled item, so a
///     denied/late permission left the whole chain dead and silent.
///
/// This version: creates the channel up-front, requests permission, schedules a
/// one-time WELCOME notification ~1 minute after the very first launch (so the
/// user can SEE it works), then keeps 4 nudges/day alive (every ~6h).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'reengagement_6h';
  static const _channelName = 'Play reminders';

  static const AndroidNotificationDetails _android = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: 'Friendly nudges to come back and play',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const NotificationDetails _details = NotificationDetails(
    android: _android,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {/* falls back to UTC */}

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _plugin.initialize(
          const InitializationSettings(android: android, iOS: ios));

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Create the channel explicitly so it exists regardless of scheduling.
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Friendly nudges to come back and play',
          importance: Importance.high,
        ),
      );
      await androidImpl?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService init failed: $e');
    }
  }

  /// Call once on every app open. Sets everything up and keeps the chain alive.
  Future<void> setup({
    required String appTitle,
    required List<String> messages,
  }) async {
    await init();
    if (!_ready) return;
    await _scheduleWelcomeOnce(appTitle);
    await scheduleEvery6Hours(title: appTitle, messages: messages);
  }

  /// Backward-compat wrapper kept so old call sites keep compiling.
  Future<void> scheduleDailyReminder({
    required String title,
    required String body,
    int hour = 19,
    int minute = 0,
  }) =>
      scheduleEvery6Hours(title: title, messages: [body]);

  /// Fires once, ~1 minute after the FIRST ever launch, so the user can confirm
  /// notifications actually arrive on their device. Persisted so it never repeats.
  Future<void> _scheduleWelcomeOnce(String appTitle) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('welcome_notif_done') ?? false) return;
      await prefs.setBool('welcome_notif_done', true);
      await _plugin.zonedSchedule(
        7000,
        appTitle,
        'Notificările sunt active ✅ Te așteptăm înapoi la joc!',
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1)),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('welcome notif failed: $e');
    }
  }

  /// Instant notification — for manual testing from a settings/debug button.
  Future<void> showTestNow(String appTitle) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
          7777, appTitle, 'Test notificare — funcționează! 🎉', _details);
    } catch (e) {
      if (kDebugMode) debugPrint('showTestNow failed: $e');
    }
  }

  /// 4 reminders/day at 09:00, 15:00, 21:00, 23:30 local. Stable IDs so
  /// rescheduling on each app open just refreshes the same slots, never stacks.
  Future<void> scheduleEvery6Hours({
    required String title,
    required List<String> messages,
  }) async {
    await init();
    if (!_ready) return;
    final msgs = messages.isEmpty ? ['Hai înapoi la joc! 🎮'] : messages;
    const slots = [
      [9025, 9, 0],
      [15025, 15, 0],
      [21025, 21, 0],
      [3025, 23, 30],
    ];
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      try {
        await _plugin.zonedSchedule(
          s[0],
          title,
          msgs[i % msgs.length],
          _nextInstance(s[1], s[2]),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('scheduleEvery6Hours[$s] failed: $e');
      }
    }
  }

  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (d.isBefore(now)) d = d.add(const Duration(days: 1));
    return d;
  }
}
