import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/datasources/local/database_helper.dart';

final csvBackupServiceProvider = Provider<CsvBackupService>((ref) {
  return CsvBackupService();
});

class CsvBackupService {
  static const _exportTables = [
    'users',
    'schools',
    'classes',
    'students',
    'subjects',
    'schedules',
    'attendance',
    'student_notes',
    'assignments',
    'teaching_sessions',
    'academic_calendar',
  ];

  Future<String> exportAllToCsv() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final stamp = '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}';

    final dir = await getTemporaryDirectory();
    final fileName = 'guru_asisten_backup_$stamp.csv';
    final file = File(p.join(dir.path, fileName));

    final sink = file.openWrite();
    try {
      for (final table in _exportTables) {
        final rows = await db.query(table);
        final columns = rows.isNotEmpty ? rows.first.keys.toList() : await _columnsOf(db, table);
        sink.writeln('##TABLE:$table');
        if (columns.isEmpty) {
          sink.writeln('');
          continue;
        }
        sink.writeln(_escapeCsvRow(columns));
        for (final r in rows) {
          final row = <String>[for (final c in columns) r[c]?.toString() ?? ''];
          sink.writeln(_escapeCsvRow(row));
        }
        sink.writeln('');
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    return file.path;
  }

  String _escapeCsvRow(List<String> row) {
    final escaped = row.map((cell) {
      final needsQuote = cell.contains(',') || cell.contains('"') || cell.contains('\n');
      final escapedCell = cell.replaceAll('"', '""');
      return needsQuote ? '"$escapedCell"' : escapedCell;
    }).toList();
    return escaped.join(',');
  }

  Future<void> shareExportedFile(String path) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Backup data Guru Asisten (CSV)'));
  }

  Future<(int, List<String>)> importFromCsvPicker() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (files.isEmpty) return (0, <String>[]);
    final picked = files.first;

    String content;
    try {
      content = await picked.xFile.readAsString();
    } catch (_) {
      final bytes = await picked.xFile.readAsBytes();
      content = utf8.decode(bytes);
    }
    return importFromCsvString(content);
  }

  Future<(int, List<String>)> importFromCsvString(String content) async {
    final db = await DatabaseHelper.instance.database;
    final lines = const LineSplitter().convert(content);
    String? currentTable;
    List<String>? columns;
    List<List<String>> buffer = [];
    int imported = 0;
    final tablesTouched = <String>[];

    Future<void> flushBuffer() async {
      final current = currentTable;
      final cols = columns;
      if (current == null || cols == null || buffer.isEmpty) {
        buffer = [];
        return;
      }
      if (!_exportTables.contains(current)) {
        buffer = [];
        return;
      }
      final batch = db.batch();
      for (final row in buffer) {
        final map = <String, dynamic>{};
        for (int i = 0; i < cols.length; i++) {
          map[cols[i]] = i < row.length ? row[i] : null;
        }
        if (!map.containsKey('id') || (map['id'] as String?)?.isEmpty == true) continue;
        batch.insert(current, map);
      }
      await batch.commit(noResult: true, continueOnError: true);
      imported += buffer.length;
      if (!tablesTouched.contains(current)) tablesTouched.add(current);
      buffer = [];
    }

    List<String> currentChunk = [];
    for (final line in lines) {
      if (line.startsWith('##TABLE:')) {
        await flushBuffer();
        currentTable = line.substring('##TABLE:'.length).trim();
        columns = null;
        currentChunk = [];
        continue;
      }
      if (currentTable == null) continue;
      if (line.trim().isEmpty) {
        if (currentChunk.isNotEmpty) {
          final parsed = _parseCsvChunk(currentChunk);
          if (columns == null) {
            columns = parsed.first;
            buffer.addAll(parsed.skip(1));
          } else {
            buffer.addAll(parsed);
          }
          currentChunk = [];
        }
        await flushBuffer();
        continue;
      }
      currentChunk.add(line);
    }
    if (currentChunk.isNotEmpty) {
      final parsed = _parseCsvChunk(currentChunk);
      if (columns == null) {
        columns = parsed.first;
        buffer.addAll(parsed.skip(1));
      } else {
        buffer.addAll(parsed);
      }
    }
    await flushBuffer();
    return (imported, List<String>.from(tablesTouched));
  }

  List<List<String>> _parseCsvChunk(List<String> lines) {
    final content = lines.join('\n');
    final result = <List<String>>[];
    String field = '';
    bool inQuotes = false;
    List<String> currentRow = [];

    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            field += '"';
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field += char;
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          currentRow.add(field);
          field = '';
        } else if (char == '\n') {
          currentRow.add(field);
          result.add(currentRow);
          currentRow = [];
          field = '';
        } else {
          field += char;
        }
      }
    }
    if (field.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(field);
      result.add(currentRow);
    }
    return result;
  }

  Future<List<String>> _columnsOf(dynamic db, String table) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      return info.map((c) => c['name'] as String).toList();
    } catch (_) {
      return [];
    }
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}