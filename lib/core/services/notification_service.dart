import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'guru_asisten_reminders';
  static const _channelName = 'Pengingat Guru Asisten';

  Future<void> initialize() async {
    tz.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
  }

  Future<bool> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;
    return await androidPlugin.requestNotificationsPermission() ?? false;
  }

  Future<void> scheduleDeadlineReminder({
    required String payloadId,
    required String title,
    required DateTime deadline,
  }) async {
    final id = payloadId.hashCode.abs() + Random().nextInt(1000);
    final reminderAt = DateTime(deadline.year, deadline.month, deadline.day, 8);
    if (!reminderAt.isAfter(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: id,
      title: 'Deadline tugas hari ini',
      body: '$title memiliki deadline hari ini.',
      scheduledDate: tz.TZDateTime.from(reminderAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Pengingat jadwal mengajar dan deadline tugas.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> scheduleScheduleReminder({
    required String payloadId,
    required String subjectName,
    required String className,
    required int day,
    required String startTime,
  }) async {
    final parts = startTime.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    // 15 menit sebelum pertemuan berikutnya pada hari jadwal terpilih.
    final now = DateTime.now();
    final daysUntil = (day - now.weekday + 7) % 7;
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute)
        .add(Duration(days: daysUntil))
        .subtract(const Duration(minutes: 15));
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    final id = payloadId.hashCode.abs();
    await _plugin.zonedSchedule(
      id: id,
      title: '15 Menit Lagi: $subjectName',
      body: 'Persiapan mengajar kelas $className ($startTime).',
      scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Pengingat jadwal mengajar dan deadline tugas.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancel(String payloadId) async {
    final id = payloadId.hashCode.abs();
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
