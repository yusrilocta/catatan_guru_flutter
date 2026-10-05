import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static bool _ffiInitialized = false;

  DatabaseHelper._init();

  static void initDesktop() {
    if (_ffiInitialized) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }
  }

  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('guru_asisten.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (isDesktop) initDesktop();
    final String path;
    if (isDesktop) {
      final docsDir = await getApplicationDocumentsDirectory();
      final dbDir = Directory(join(docsDir.path, 'guru_asisten'));
      if (!await dbDir.exists()) await dbDir.create(recursive: true);
      path = join(dbDir.path, filePath);
      return await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 1, onCreate: _createDB),
      );
    }
    final dbPath = await getDatabasesPath();
    path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT';
    const textNullable = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    // Users
    await db.execute('''
      CREATE TABLE users (
        id $idType,
        name $textType,
        email $textType,
        created_at $textType
      )
    ''');

    // Schools
    await db.execute('''
      CREATE TABLE schools (
        id $idType,
        user_id $textNullable,
        name $textType,
        address $textNullable,
        sync_status $textType DEFAULT 'pending',
        created_at $textType,
        updated_at $textType,
        deleted_at $textNullable
      )
    ''');

    // Academic Years
    await db.execute('''
      CREATE TABLE academic_years (
        id $idType,
        school_id $textType,
        name $textType,
        start_date $textType,
        end_date $textType,
        is_active $integerType DEFAULT 1,
        sync_status $textType DEFAULT 'pending',
        created_at $textType,
        updated_at $textType,
        FOREIGN KEY (school_id) REFERENCES schools (id) ON DELETE CASCADE
      )
    ''');

    // Classes
    await db.execute('''
      CREATE TABLE classes (
        id $idType,
        school_id $textType,
        academic_year_id $textNullable,
        name $textType,
        grade $textNullable,
        sync_status $textType DEFAULT 'pending',
        created_at $textType,
        updated_at $textType,
        FOREIGN KEY (school_id) REFERENCES schools (id) ON DELETE CASCADE
      )
    ''');

    // Students
    await db.execute('''
      CREATE TABLE students (
        id $idType,
        class_id $textType,
        name $textType,
        student_number $textNullable,
        sync_status $textType DEFAULT 'pending',
        created_at $textType,
        updated_at $textType,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
      )
    ''');

    // Subjects
    await db.execute('''
      CREATE TABLE subjects (
        id $idType,
        name $textType,
        code $textNullable,
        sync_status $textType DEFAULT 'pending',
        created_at $textType,
        updated_at $textType
      )
    ''');

    // Schedules
    await db.execute('''
      CREATE TABLE schedules (
        id $idType,
        school_id $textType,
        class_id $textType,
        subject_id $textType,
        day $integerType, -- 1 = Senin, 7 = Minggu
        start_time $textType, -- e.g. "07:30"
        end_time $textType, -- e.g. "09:00"
        room $textNullable,
        notes $textNullable,
        sync_status $textType DEFAULT 'pending',
        created_at $textType,
        updated_at $textType,
        FOREIGN KEY (school_id) REFERENCES schools (id) ON DELETE CASCADE,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    // Attendance
    await db.execute('''
      CREATE TABLE attendance (
        id $idType,
        student_id $textType,
        schedule_id $textNullable,
        date $textType,
        status $textType, -- Hadir, Izin, Sakit, Alpa, Terlambat
        notes $textNullable,
        sync_status $textType DEFAULT 'pending',
        created_at $textType,
        updated_at $textType,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    // Student Notes
    await db.execute('''
      CREATE TABLE student_notes (
        id $idType,
        student_id $textType,
        category $textType, -- Akademik, Perilaku, Tugas, Prestasi, Positif, Perhatian, Umum
        content $textType,
        date $textType,
        sync_status $textType DEFAULT 'pending',
        created_at $textType,
        updated_at $textType,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    // Assignments
    await db.execute('''
      CREATE TABLE assignments (
        id $idType,
        school_id $textType,
        class_id $textType,
        subject_id $textType,
        title $textType,
        description $textNullable,
        assigned_date $textType,
        deadline $textType,
        status $textType DEFAULT 'Aktif', -- Aktif, Mendekati deadline, Terlambat, Selesai, Diarsipkan
        sync_status $textType DEFAULT 'pending',
        created_at $textType,
        updated_at $textType
      )
    ''');

    // Teaching Sessions (Jurnal Mengajar)
    await db.execute('''
      CREATE TABLE teaching_sessions (
        id $idType,
        schedule_id $textType,
        date $textType,
        material $textType,
        objective $textNullable,
        activity $textNullable,
        notes $textNullable,
        status $textType DEFAULT 'Selesai',
        sync_status $textType DEFAULT 'pending',
        created_at $textType,
        updated_at $textType,
        FOREIGN KEY (schedule_id) REFERENCES schedules (id) ON DELETE CASCADE
      )
    ''');

    // Academic Calendar
    await db.execute('''
      CREATE TABLE academic_calendar (
        id $idType,
        school_id $textNullable,
        date $textType,
        event_type $textType, -- Libur, UTS, UAS, Kegiatan, dll
        title $textType,
        description $textNullable,
        sync_status $textType DEFAULT 'pending',
        created_at $textType,
        updated_at $textType
      )
    ''');

  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
