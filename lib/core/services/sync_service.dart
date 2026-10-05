import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/database_helper.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(DatabaseHelper.instance);
});

final syncStatusProvider = FutureProvider<SyncSummary>((ref) {
  return ref.watch(syncServiceProvider).summary();
});

class SyncSummary {
  final int pending;
  final int synced;
  final int failed;
  const SyncSummary({required this.pending, required this.synced, required this.failed});
}

class SyncService {
  SyncService(this._helper);
  final DatabaseHelper _helper;

  static const _tables = [
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

  Future<SyncSummary> summary() async {
    final db = await _helper.database;
    int pending = 0;
    int synced = 0;
    int failed = 0;
    for (final t in _tables) {
      final hasColumn = await _hasSyncColumn(db, t);
      if (!hasColumn) continue;
      for (final status in ['pending', 'synced', 'failed']) {
        final c = await db.rawQuery('SELECT COUNT(*) as c FROM $t WHERE sync_status = ?', [status]);
        final n = (c.first['c'] as int?) ?? 0;
        if (status == 'pending') pending += n;
        if (status == 'synced') synced += n;
        if (status == 'failed') failed += n;
      }
    }
    return SyncSummary(pending: pending, synced: synced, failed: failed);
  }

  Future<List<Map<String, dynamic>>> pendingRows({int limit = 100}) async {
    final db = await _helper.database;
    final out = <Map<String, dynamic>>[];
    for (final t in _tables) {
      if (!await _hasSyncColumn(db, t)) continue;
      final rows = await db.query(t, where: 'sync_status = ?', whereArgs: ['pending'], limit: limit - out.length);
      for (final r in rows) {
        out.add({'table': t, ...r});
        if (out.length >= limit) return out;
      }
    }
    return out;
  }

  Future<void> markSynced(String table, String id) async {
    final db = await _helper.database;
    await db.update(table, {'sync_status': 'synced', 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markFailed(String table, String id) async {
    final db = await _helper.database;
    await db.update(table, {'sync_status': 'failed', 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> retryFailed() async {
    final db = await _helper.database;
    for (final t in _tables) {
      if (!await _hasSyncColumn(db, t)) continue;
      await db.update(t, {'sync_status': 'pending'}, where: 'sync_status = ?', whereArgs: ['failed']);
    }
  }

  Future<void> simulateSync() async {
    final db = await _helper.database;
    for (final t in _tables) {
      if (!await _hasSyncColumn(db, t)) continue;
      await db.update(t, {'sync_status': 'synced', 'updated_at': DateTime.now().toIso8601String()}, where: 'sync_status = ?', whereArgs: ['pending']);
    }
  }

  Future<bool> _hasSyncColumn(dynamic db, String table) async {
    final info = await db.rawQuery("PRAGMA table_info($table)");
    return info.any((c) => c['name'] == 'sync_status');
  }
}
