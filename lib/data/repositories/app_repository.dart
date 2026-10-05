import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../datasources/local/database_helper.dart';
import '../models/schedule_model.dart';
import '../models/student_model.dart';
import '../models/assignment_model.dart';
import '../models/note_model.dart';

final appRepositoryProvider = Provider<AppRepository>((ref) {
  return AppRepository(DatabaseHelper.instance);
});

final teacherProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return ref.watch(appRepositoryProvider).getTeacher();
});

class AppRepository {
  final DatabaseHelper _dbHelper;

  AppRepository(this._dbHelper);

  // Get Today Schedules
  Future<List<ScheduleItem>> getTodaySchedules() async {
    final db = await _dbHelper.database;
    final todayWeekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun

    final result = await db.rawQuery('''
      SELECT s.*, sch.name as school_name, c.name as class_name, sub.name as subject_name
      FROM schedules s
      LEFT JOIN schools sch ON s.school_id = sch.id
      LEFT JOIN classes c ON s.class_id = c.id
      LEFT JOIN subjects sub ON s.subject_id = sub.id
      WHERE s.day = ?
      ORDER BY s.start_time ASC
    ''', [todayWeekday]);

    return result.map((e) => ScheduleItem.fromMap(e)).toList();
  }

  // Get All Schedules
  Future<List<ScheduleItem>> getAllSchedules({String? schoolId}) async {
    final db = await _dbHelper.database;
    String query = '''
      SELECT s.*, sch.name as school_name, c.name as class_name, sub.name as subject_name
      FROM schedules s
      LEFT JOIN schools sch ON s.school_id = sch.id
      LEFT JOIN classes c ON s.class_id = c.id
      LEFT JOIN subjects sub ON s.subject_id = sub.id
    ''';
    List<dynamic> args = [];
    if (schoolId != null && schoolId.isNotEmpty && schoolId != 'all') {
      query += ' WHERE s.school_id = ?';
      args.add(schoolId);
    }
    query += ' ORDER BY s.day ASC, s.start_time ASC';

    final result = await db.rawQuery(query, args);
    return result.map((e) => ScheduleItem.fromMap(e)).toList();
  }

  // Get Dashboard Stats
  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await _dbHelper.database;
    final todayWeekday = DateTime.now().weekday;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    final scheduleCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM schedules WHERE day = ?', [todayWeekday]
    )) ?? 0;

    final classCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM classes'
    )) ?? 0;

    final studentCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM students'
    )) ?? 0;

    final attendanceDone = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(DISTINCT schedule_id) FROM attendance WHERE date LIKE ?', ['$todayStr%']
    )) ?? 0;

    final taskCount = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM assignments WHERE status != 'Selesai' AND status != 'Diarsipkan'"
    )) ?? 0;

    return {
      'schedules': scheduleCount,
      'classes': classCount,
      'students': studentCount,
      'attendanceDone': attendanceDone,
      'activeTasks': taskCount,
    };
  }

  // Get Urgent Assignments
  Future<List<AssignmentItem>> getUpcomingAssignments() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT a.*, sch.name as school_name, c.name as class_name, sub.name as subject_name
      FROM assignments a
      LEFT JOIN schools sch ON a.school_id = sch.id
      LEFT JOIN classes c ON a.class_id = c.id
      LEFT JOIN subjects sub ON a.subject_id = sub.id
      ORDER BY a.deadline ASC
      LIMIT 5
    ''');
    return result.map((e) => AssignmentItem.fromMap(e)).toList();
  }

  Future<List<AssignmentItem>> getAssignments({String? status}) async {
    final db = await _dbHelper.database;
    final where = status == null || status == 'Semua' ? null : 'a.status = ?';
    final args = status == null || status == 'Semua' ? null : [status];
    final result = await db.rawQuery('''
      SELECT a.*, sch.name as school_name, c.name as class_name, sub.name as subject_name
      FROM assignments a
      LEFT JOIN schools sch ON a.school_id = sch.id
      LEFT JOIN classes c ON a.class_id = c.id
      LEFT JOIN subjects sub ON a.subject_id = sub.id
      ${where == null ? '' : 'WHERE $where'}
      ORDER BY a.deadline ASC
    ''', args);
    return result.map((e) => AssignmentItem.fromMap(e)).toList();
  }

  Future<void> insertAssignment({
    required String schoolId,
    required String classId,
    required String subjectId,
    required String title,
    String? description,
    required String assignedDate,
    required String deadline,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('assignments', {
      'id': 'asg_${DateTime.now().microsecondsSinceEpoch}',
      'school_id': schoolId, 'class_id': classId, 'subject_id': subjectId,
      'title': title, 'description': description, 'assigned_date': assignedDate,
      'deadline': deadline, 'status': 'Aktif', 'sync_status': 'pending',
      'created_at': now, 'updated_at': now,
    });
  }

  Future<void> updateAssignmentStatus(String id, String status) async {
    final db = await _dbHelper.database;
    await db.update('assignments', {'status': status, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAssignment(String id) async {
    final db = await _dbHelper.database;
    await db.delete('assignments', where: 'id = ?', whereArgs: [id]);
  }

  // Get Students by Class
  Future<List<StudentItem>> getStudentsByClass(String classId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'students',
      where: 'class_id = ?',
      whereArgs: [classId],
      orderBy: 'name ASC',
    );
    return result.map((e) => StudentItem.fromMap(e)).toList();
  }

  // Get Schools
  Future<List<Map<String, dynamic>>> getSchools() async {
    final db = await _dbHelper.database;
    return await db.query('schools', orderBy: 'name ASC');
  }

  // Save Attendance List
  Future<void> saveAttendance({
    required String? scheduleId,
    required String date,
    required Map<String, String> studentStatuses, // studentId -> status (Hadir, Izin, Sakit, Alpa)
  }) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (var entry in studentStatuses.entries) {
      final studentId = entry.key;
      final status = entry.value;
      final id = 'att_${DateTime.now().microsecondsSinceEpoch}_$studentId';

      batch.insert(
        'attendance',
        {
          'id': id,
          'student_id': studentId,
          'schedule_id': scheduleId,
          'date': date,
          'status': status,
          'sync_status': 'pending',
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // Get Classes by School (pass 'all' for all classes)
  Future<List<Map<String, dynamic>>> getClassesBySchool(String schoolId) async {
    final db = await _dbHelper.database;
    if (schoolId == 'all') {
      return await db.rawQuery('''
        SELECT c.*, sch.name as school_name
        FROM classes c
        LEFT JOIN schools sch ON c.school_id = sch.id
        ORDER BY sch.name ASC, c.name ASC
      ''');
    }
    return await db.rawQuery('''
      SELECT c.*, sch.name as school_name
      FROM classes c
      LEFT JOIN schools sch ON c.school_id = sch.id
      WHERE c.school_id = ?
      ORDER BY c.name ASC
    ''', [schoolId]);
  }

  // Get Subjects
  Future<List<Map<String, dynamic>>> getSubjects() async {
    final db = await _dbHelper.database;
    return await db.query('subjects', orderBy: 'name ASC');
  }

  // Check Schedule Conflict
  Future<List<Map<String, dynamic>>> checkScheduleConflict({
    required String schoolId,
    required int day,
    required String startTime,
    required String endTime,
    required String? excludeId,
  }) async {
    final db = await _dbHelper.database;
    String query = '''
      SELECT s.*, sch.name as school_name, c.name as class_name, sub.name as subject_name
      FROM schedules s
      LEFT JOIN schools sch ON s.school_id = sch.id
      LEFT JOIN classes c ON s.class_id = c.id
      LEFT JOIN subjects sub ON s.subject_id = sub.id
      WHERE s.school_id = ? AND s.day = ?
        AND (
          (? >= s.start_time AND ? < s.end_time)
          OR (? > s.start_time AND ? <= s.end_time)
          OR (? <= s.start_time AND ? >= s.end_time)
        )
    ''';
    List<dynamic> args = [schoolId, day, startTime, startTime, endTime, endTime, startTime, endTime];

    if (excludeId != null) {
      query += ' AND s.id != ?';
      args.add(excludeId);
    }

    return await db.rawQuery(query, args);
  }

  // Insert Schedule
  Future<String> insertSchedule({
    required String schoolId,
    required String classId,
    required String subjectId,
    required int day,
    required String startTime,
    required String endTime,
    String? room,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final id = 'schd_${DateTime.now().microsecondsSinceEpoch}';
    await db.insert('schedules', {
      'id': id,
      'school_id': schoolId,
      'class_id': classId,
      'subject_id': subjectId,
      'day': day,
      'start_time': startTime,
      'end_time': endTime,
      'room': room,
      'notes': notes,
      'sync_status': 'pending',
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> deleteSchedule(String scheduleId) async {
    final db = await _dbHelper.database;
    await db.delete('schedules', where: 'id = ?', whereArgs: [scheduleId]);
  }

  Future<List<Map<String, dynamic>>> getStudentsNeedingAttention({int limit = 5}) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT s.id as student_id, s.name as student_name, c.name as class_name,
        COUNT(DISTINCT CASE WHEN sn.category IN ('Perhatian','Perilaku') THEN sn.id END) as perhatian_count,
        MAX(CASE WHEN sn.category IN ('Perhatian','Perilaku') THEN sn.content END) as last_note,
        COUNT(CASE WHEN a.status IN ('Alpa','Alpha') THEN 1 END) as alpa,
        COUNT(a.id) as total,
        COUNT(CASE WHEN a.status = 'Hadir' THEN 1 END) as hadir
      FROM students s
      LEFT JOIN classes c ON s.class_id = c.id
      LEFT JOIN student_notes sn ON sn.student_id = s.id
      LEFT JOIN attendance a ON a.student_id = s.id
      GROUP BY s.id, s.name, c.name
      HAVING perhatian_count > 0 OR alpa >= 2 OR (total > 0 AND CAST(alpa AS FLOAT) / total >= 0.2)
      ORDER BY perhatian_count DESC, alpa DESC
      LIMIT ?
    ''', [limit]);
    return result;
  }

  // Duplicate Schedule
  Future<void> duplicateSchedule({
    required String scheduleId,
    required int targetDay,
    required String? newStartTime,
    required String? newEndTime,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final source = await db.query('schedules', where: 'id = ?', whereArgs: [scheduleId]);
    if (source.isEmpty) return;

    final s = source.first;
    await db.insert('schedules', {
      'id': 'schd_${DateTime.now().microsecondsSinceEpoch}',
      'school_id': s['school_id'],
      'class_id': s['class_id'],
      'subject_id': s['subject_id'],
      'day': targetDay,
      'start_time': newStartTime ?? s['start_time'],
      'end_time': newEndTime ?? s['end_time'],
      'room': s['room'],
      'notes': s['notes'],
      'sync_status': 'pending',
      'created_at': now,
      'updated_at': now,
    });
  }

  // Student Notes
  Future<List<StudentNoteItem>> getStudentNotes({String? studentId}) async {
    final db = await _dbHelper.database;
    String query = '''
      SELECT sn.*, s.name as student_name
      FROM student_notes sn
      LEFT JOIN students s ON sn.student_id = s.id
    ''';
    List<dynamic> args = [];
    if (studentId != null) {
      query += ' WHERE sn.student_id = ?';
      args.add(studentId);
    }
    query += ' ORDER BY sn.date DESC';
    final result = await db.rawQuery(query, args);
    return result.map((e) => StudentNoteItem.fromMap(e)).toList();
  }

  Future<void> addStudentNote({
    required String studentId,
    required String category,
    required String content,
    String? date,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('student_notes', {
      'id': 'note_${DateTime.now().microsecondsSinceEpoch}',
      'student_id': studentId,
      'category': category,
      'content': content,
      'date': date ?? now,
      'sync_status': 'pending',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateStudentNote({
    required String noteId,
    required String category,
    required String content,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.update('student_notes', {
      'category': category,
      'content': content,
      'updated_at': now,
    }, where: 'id = ?', whereArgs: [noteId]);
  }

  Future<void> deleteStudentNote(String noteId) async {
    final db = await _dbHelper.database;
    await db.delete('student_notes', where: 'id = ?', whereArgs: [noteId]);
  }

  // Teaching Sessions (Jurnal Mengajar)
  Future<List<TeachingSessionItem>> getTeachingSessions({String? scheduleId, String? date}) async {
    final db = await _dbHelper.database;
    String query = '''
      SELECT ts.*, s.id as schedule_id_join, sub.name as subject_name, c.name as class_name
      FROM teaching_sessions ts
      LEFT JOIN schedules s ON ts.schedule_id = s.id
      LEFT JOIN subjects sub ON s.subject_id = sub.id
      LEFT JOIN classes c ON s.class_id = c.id
    ''';
    List<dynamic> args = [];
    if (scheduleId != null) {
      query += ' WHERE ts.schedule_id = ?';
      args.add(scheduleId);
    } else if (date != null) {
      query += ' WHERE ts.date = ?';
      args.add(date);
    }
    query += ' ORDER BY ts.date DESC';
    final result = await db.rawQuery(query, args);
    return result.map((e) => TeachingSessionItem.fromMap(e)).toList();
  }

  Future<void> addTeachingSession({
    required String scheduleId,
    required String date,
    required String material,
    String? objective,
    String? activity,
    String? notes,
    String status = 'Selesai',
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('teaching_sessions', {
      'id': 'ts_${DateTime.now().microsecondsSinceEpoch}',
      'schedule_id': scheduleId,
      'date': date,
      'material': material,
      'objective': objective,
      'activity': activity,
      'notes': notes,
      'status': status,
      'sync_status': 'pending',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateTeachingSession({
    required String sessionId,
    required String material,
    String? objective,
    String? activity,
    String? notes,
    String? status,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.update('teaching_sessions', {
      'material': material,
      'objective': objective,
      'activity': activity,
      'notes': notes,
      'status': status ?? 'Selesai',
      'updated_at': now,
    }, where: 'id = ?', whereArgs: [sessionId]);
  }

  Future<void> deleteTeachingSession(String sessionId) async {
    final db = await _dbHelper.database;
    await db.delete('teaching_sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  // ── Onboarding & Settings ──────────────────────────────────────────

  Future<bool> hasAnyUser() async {
    final db = await _dbHelper.database;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM users');
    return ((r.first['c'] as int?) ?? 0) > 0;
  }

  Future<void> createTeacher(String name, String? email) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('users', {
      'id': 'user_1',
      'name': name,
      'email': email ?? '',
      'created_at': now,
    });
  }

  Future<void> updateTeacher(String name, String? email) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'users',
      {
        'id': 'user_1',
        'name': name,
        'email': email ?? '',
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getTeacher() async {
    final db = await _dbHelper.database;
    final r = await db.query('users', where: 'id = ?', whereArgs: ['user_1']);
    return r.isNotEmpty ? r.first : null;
  }

  Future<String> insertSchool(String name, {String? address}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final id = 'sch_${DateTime.now().microsecondsSinceEpoch}';
    await db.insert('schools', {
      'id': id,
      'user_id': 'user_1',
      'name': name,
      'address': address,
      'sync_status': 'pending',
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> updateSchool(String schoolId, String name, {String? address}) async {
    final db = await _dbHelper.database;
    await db.update(
      'schools',
      {
        'name': name,
        'address': address,
        'sync_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [schoolId],
    );
  }

  Future<String> insertClass({
    required String schoolId,
    required String name,
    String? grade,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final id = 'cls_${DateTime.now().microsecondsSinceEpoch}';
    await db.insert('classes', {
      'id': id,
      'school_id': schoolId,
      'name': name,
      'grade': grade,
      'sync_status': 'pending',
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> updateClass({
    required String classId,
    required String name,
    String? grade,
    String? schoolId,
  }) async {
    final db = await _dbHelper.database;
    final map = <String, dynamic>{
      'name': name,
      'grade': grade,
      'sync_status': 'pending',
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (schoolId != null) map['school_id'] = schoolId;
    await db.update('classes', map, where: 'id = ?', whereArgs: [classId]);
  }

  Future<String> insertSubject(String name, {String? code}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final id = 'subj_${DateTime.now().microsecondsSinceEpoch}';
    await db.insert('subjects', {
      'id': id,
      'name': name,
      'code': code,
      'sync_status': 'pending',
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> deleteClass(String classId) async {
    final db = await _dbHelper.database;
    await db.delete('classes', where: 'id = ?', whereArgs: [classId]);
  }

  Future<void> deleteSubject(String subjectId) async {
    final db = await _dbHelper.database;
    await db.delete('subjects', where: 'id = ?', whereArgs: [subjectId]);
  }

  Future<void> deleteSchool(String schoolId) async {
    final db = await _dbHelper.database;
    await db.delete('schools', where: 'id = ?', whereArgs: [schoolId]);
  }

  // ── Absensi per Kelas ──────────────────────────────────────────

  Future<String> insertStudent({
    required String classId,
    required String name,
    String? studentNumber,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final id = 'std_${DateTime.now().microsecondsSinceEpoch}';
    await db.insert('students', {
      'id': id,
      'class_id': classId,
      'name': name,
      'student_number': studentNumber,
      'sync_status': 'pending',
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> updateStudent({
    required String studentId,
    required String name,
    String? studentNumber,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'students',
      {
        'name': name,
        'student_number': studentNumber,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  Future<void> deleteStudent(String studentId) async {
    final db = await _dbHelper.database;
    await db.delete('students', where: 'id = ?', whereArgs: [studentId]);
  }

  Future<List<String>> getAttendanceDates(String classId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT DISTINCT substr(a.date, 1, 10) as d
      FROM attendance a
      INNER JOIN students s ON a.student_id = s.id
      WHERE s.class_id = ?
      ORDER BY d DESC
    ''', [classId]);
    return result.map((e) => e['d'] as String).toList();
  }

  Future<bool> hasAttendanceOnDate(String classId, String datePrefix) async {
    final db = await _dbHelper.database;
    final r = await db.rawQuery('''
      SELECT COUNT(*) as c FROM attendance a
      INNER JOIN students s ON a.student_id = s.id
      WHERE s.class_id = ? AND a.date LIKE ?
    ''', [classId, '$datePrefix%']);
    return ((r.first['c'] as int?) ?? 0) > 0;
  }

  Future<List<Map<String, dynamic>>> getAttendanceDetail({
    required String classId,
    required String datePrefix,
  }) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT s.id as student_id, s.name as student_name,
             s.student_number as student_number,
             a.status as status, a.date as date
      FROM students s
      LEFT JOIN attendance a
        ON a.student_id = s.id AND a.date LIKE ?
      WHERE s.class_id = ?
      ORDER BY s.name ASC
    ''', ['$datePrefix%', classId]);
  }

  Future<List<Map<String, dynamic>>> getAttendanceRecap(String classId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT s.id as student_id, s.name as student_name,
             s.student_number as student_number,
             COUNT(CASE WHEN a.status = 'Hadir' THEN 1 END) as hadir,
             COUNT(CASE WHEN a.status = 'Izin' THEN 1 END) as izin,
             COUNT(CASE WHEN a.status = 'Sakit' THEN 1 END) as sakit,
             COUNT(CASE WHEN a.status = 'Alpa' THEN 1 END) as alpa,
             COUNT(a.id) as total
      FROM students s
      LEFT JOIN attendance a ON a.student_id = s.id
      WHERE s.class_id = ?
      GROUP BY s.id, s.name, s.student_number
      ORDER BY s.name ASC
    ''', [classId]);
  }

  Future<void> deleteAttendanceByDate(String classId, String datePrefix) async {
    final db = await _dbHelper.database;
    await db.rawDelete('''
      DELETE FROM attendance WHERE id IN (
        SELECT a.id FROM attendance a
        INNER JOIN students s ON a.student_id = s.id
        WHERE s.class_id = ? AND a.date LIKE ?
      )
    ''', [classId, '$datePrefix%']);
  }
}
