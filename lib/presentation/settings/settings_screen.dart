import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/csv_backup_service.dart';
import '../../core/services/home_widget_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/sync_service.dart';
import '../../data/repositories/app_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExportingCsv = false;
  bool _isImportingCsv = false;

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncStatusProvider);
    final teacherAsync = ref.watch(teacherProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan & Sinkronisasi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: Backup & Restore Data Lokal (CSV)
          const Text('Backup & Restore Data Lokal (CSV)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
              'Ekspor seluruh data (siswa, jadwal, absensi, catatan, jurnal, dll) ke file CSV yang bisa dibuka di Excel / Google Sheets. Import kembali untuk memulihkan data ke perangkat lain.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          ShadCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ShadButton(
                          width: double.infinity,
                          onPressed: _isExportingCsv
                              ? null
                              : () async {
                                  setState(() => _isExportingCsv = true);
                                  try {
                                    final path = await ref
                                        .read(csvBackupServiceProvider)
                                        .exportAllToCsv();
                                    await ref
                                        .read(csvBackupServiceProvider)
                                        .shareExportedFile(path);
                                    if (context.mounted) {
                                      ShadToaster.of(context).show(const ShadToast(
                                          title: Text('Ekspor Berhasil'),
                                          description: Text(
                                              'File CSV siap dibagikan ke Email/Drive/WA.')));
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ShadToaster.of(context).show(
                                          ShadToast.destructive(
                                              title: const Text('Gagal Ekspor'),
                                              description: Text(e.toString())));
                                    }
                                  } finally {
                                    if (mounted)
                                      setState(() => _isExportingCsv = false);
                                  }
                                },
                          child: _isExportingCsv
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.download, size: 18),
                                    SizedBox(width: 8),
                                    Text('Ekspor Data'),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ShadButton.outline(
                          width: double.infinity,
                          onPressed: _isImportingCsv
                              ? null
                              : () async {
                                  setState(() => _isImportingCsv = true);
                                  try {
                                    final result = await ref
                                        .read(csvBackupServiceProvider)
                                        .importFromCsvPicker();
                                    if (context.mounted) {
                                      ShadToaster.of(context).show(ShadToast(
                                          title: const Text('Import Selesai'),
                                          description: Text(
                                              '${result.$1} baris data diimpor ke ${result.$2.join(', ')}')));
                                      ref.invalidate(teacherProfileProvider);
                                      ref.invalidate(syncStatusProvider);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ShadToaster.of(context).show(
                                          ShadToast.destructive(
                                              title: const Text('Gagal Import'),
                                              description: Text(e.toString())));
                                    }
                                  } finally {
                                    if (mounted)
                                      setState(() => _isImportingCsv = false);
                                  }
                                },
                          child: _isImportingCsv
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.upload, size: 18),
                                    SizedBox(width: 8),
                                    Text('Import CSV'),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                      'Catatan: Import akan menimpa data yang cocok (berdasarkan ID). Pastikan file CSV berasal dari ekspor aplikasi ini.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Local Database Summary
          const Text('Database Lokal (Offline-First)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Data utama tersimpan di SQLite perangkat.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          sync.when(
            data: (s) => ShadCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status Antrean',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _Chip(
                          label: 'Pending',
                          value: s.pending,
                          color: AppColors.statusYellow),
                      const SizedBox(width: 8),
                      _Chip(
                          label: 'Tersinkron',
                          value: s.synced,
                          color: AppColors.statusGreen),
                      const SizedBox(width: 8),
                      _Chip(
                          label: 'Gagal',
                          value: s.failed,
                          color: AppColors.statusRed),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                          child: ShadButton(
                              child: const Text('Sinkronkan (mock)'),
                              onPressed: () async {
                                await ref
                                    .read(syncServiceProvider)
                                    .simulateSync();
                                ref.invalidate(syncStatusProvider);
                                if (context.mounted)
                                  ShadToaster.of(context).show(const ShadToast(
                                      title: Text('Berhasil'),
                                      description: Text(
                                          'Antrean ditandai tersinkron.')));
                              })),
                      const SizedBox(width: 10),
                      Expanded(
                          child: ShadButton.outline(
                              child: const Text('Ulangi gagal'),
                              onPressed: () async {
                                await ref
                                    .read(syncServiceProvider)
                                    .retryFailed();
                                ref.invalidate(syncStatusProvider);
                                if (context.mounted)
                                  ShadToaster.of(context).show(const ShadToast(
                                      title: Text('Berhasil'),
                                      description: Text(
                                          'Item gagal dikembalikan ke pending.')));
                              })),
                    ]),
                  ],
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 16),

          // Section 3: Widget Refresh
          ShadButton.outline(
            width: double.infinity,
            onPressed: () async {
              try {
                await ref.read(homeWidgetServiceProvider).updateWidgets();
                if (context.mounted) {
                  ShadToaster.of(context).show(const ShadToast(
                      title: Text('Widget Diperbarui'),
                      description:
                          Text('Data widget kelas & tugas telah di-refresh.')));
                }
              } catch (e) {
                if (context.mounted) {
                  ShadToaster.of(context).show(ShadToast.destructive(
                      title: const Text('Gagal Refresh'),
                      description: Text(e.toString())));
                }
              }
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.refreshCw, size: 18),
                SizedBox(width: 8),
                Text('Refresh Widget Home Screen'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 4: Local Notifications
          ShadCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Notifikasi Lokal',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text(
                        'Perlu izin POST_NOTIFICATIONS untuk pengingat jadwal dan deadline.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 10),
                    ShadButton.outline(
                      child: const Text('Minta izin notifikasi'),
                      onPressed: () async {
                        final granted = await NotificationService.instance
                            .requestPermission();
                        if (context.mounted) {
                          ShadToaster.of(context).show(ShadToast(
                              title: Text(
                                  granted ? 'Izin diberikan' : 'Izin ditolak'),
                              description: Text(granted
                                  ? 'Pengingat tugas & jadwal aktif.'
                                  : 'Aktifkan izin di pengaturan sistem.')));
                        }
                      },
                    ),
                  ]),
            ),
          ),
          const SizedBox(height: 16),

          // Section 5: Teacher Profile
          teacherAsync.when(
            data: (teacher) {
              final name = teacher?['name'] as String? ?? '-';
              final email = (teacher?['email'] as String?)?.isNotEmpty == true
                  ? teacher!['email'] as String
                  : '-';
              return ShadCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Profil Guru',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      _FieldRow(label: 'Nama', value: name),
                      const Divider(height: 20),
                      _FieldRow(label: 'Email', value: email),
                      const Divider(height: 20),
                      const _FieldRow(
                          label: 'Penyimpanan',
                          value: 'SQLite Lokal + CSV Backup'),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.25))),
            child: Column(children: [
              Text('$value',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18, color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: color, fontWeight: FontWeight.w600))
            ])));
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13))),
      Expanded(
          child: Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)))
    ]);
  }
}
