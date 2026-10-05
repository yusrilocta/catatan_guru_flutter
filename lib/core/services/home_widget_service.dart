import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../../data/datasources/local/database_helper.dart';

final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) {
  return HomeWidgetService();
});

class HomeWidgetService {
  static const _androidNextClass = 'NextClassWidgetProvider';
  static const _androidTaskStack = 'TaskStackWidgetProvider';

  Future<void> updateWidgets() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final todayWeekday = DateTime.now().weekday;

      // ── 1. Widget Kelas Berikutnya ──
      final schedules = await db.rawQuery('''
        SELECT s.*, sch.name as school_name, c.name as class_name, sub.name as subject_name
        FROM schedules s
        LEFT JOIN schools sch ON s.school_id = sch.id
        LEFT JOIN classes c ON s.class_id = c.id
        LEFT JOIN subjects sub ON s.subject_id = sub.id
        WHERE s.day = ?
        ORDER BY s.start_time ASC
      ''', [todayWeekday]);

      Map<String, dynamic>? nextSchedule;
      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;
      for (final s in schedules) {
        final parts = (s['start_time'] as String).split(':');
        final startMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        if (startMinutes >= nowMinutes) {
          nextSchedule = s;
          break;
        }
      }
      nextSchedule ??= schedules.isNotEmpty ? schedules.first : null;

      if (nextSchedule != null) {
        final subject = '${nextSchedule['subject_name']}';
        final cls = '${nextSchedule['class_name']}';
        final school = '${nextSchedule['school_name'] ?? ''} • ${nextSchedule['room'] ?? 'Ruang Kelas'}';
        final time = '${nextSchedule['start_time']} - ${nextSchedule['end_time']}';
        final date = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
        print('Widget NextClass: subject=$subject, class=$cls, school=$school, time=$time, date=$date');
        await HomeWidget.saveWidgetData<String>('next_subject', subject);
        await HomeWidget.saveWidgetData<String>('next_class', cls);
        await HomeWidget.saveWidgetData<String>('next_school', school);
        await HomeWidget.saveWidgetData<String>('next_time', time);
        await HomeWidget.saveWidgetData<String>('next_date', date);
      } else {
        print('Widget NextClass: no schedule');
        await HomeWidget.saveWidgetData<String>('next_subject', 'Tidak ada jadwal hari ini');
        await HomeWidget.saveWidgetData<String>('next_class', '—');
        await HomeWidget.saveWidgetData<String>('next_school', '');
        await HomeWidget.saveWidgetData<String>('next_time', '');
        await HomeWidget.saveWidgetData<String>('next_date', DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now));
      }

      // ── 2. Widget Tugas (stack, deadline terdekat paling depan) ──
      final tasks = await db.rawQuery('''
        SELECT a.*, sub.name as subject_name, c.name as class_name
        FROM assignments a
        LEFT JOIN subjects sub ON a.subject_id = sub.id
        LEFT JOIN classes c ON a.class_id = c.id
        WHERE a.status != 'Selesai' AND a.status != 'Diarsipkan'
        ORDER BY a.deadline ASC
        LIMIT 10
      ''');

      final taskList = tasks.map((t) {
        String deadlineLabel = '${t['deadline']}';
        try {
          final d = DateTime.parse('${t['deadline']}');
          deadlineLabel = DateFormat('d MMM yyyy', 'id_ID').format(d);
        } catch (_) {}
        return {
          'title': '${t['title']}',
          'meta': '${t['subject_name'] ?? ''} — ${t['class_name'] ?? ''}',
          'deadline': deadlineLabel,
          'status': '${t['status'] ?? 'Aktif'}',
        };
      }).toList();

      print('Widget TaskStack: ${taskList.length} tasks');
      for (var t in taskList) {
        print('  - ${t['title']} | ${t['meta']} | ${t['deadline']} | ${t['status']}');
      }

      await HomeWidget.saveWidgetData<String>('task_list', jsonEncode(taskList));
      await HomeWidget.saveWidgetData<String>('task_count', '${taskList.length}');

      await HomeWidget.updateWidget(androidName: _androidNextClass, iOSName: _androidNextClass);
      await HomeWidget.updateWidget(androidName: _androidTaskStack, iOSName: _androidTaskStack);
    } catch (e) {
      print('HomeWidget update error: $e');
    }
  }

  Future<void> handleWidgetClick(Uri? uri) async {}
}
