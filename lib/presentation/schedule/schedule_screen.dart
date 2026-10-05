import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/models/schedule_model.dart';
import '../../data/repositories/app_repository.dart';

final scheduleSchoolFilterProvider = StateProvider<String>((ref) => 'all');
final allSchedulesProvider = FutureProvider.family<List<ScheduleItem>, String>((ref, schoolId) async {
  return ref.watch(appRepositoryProvider).getAllSchedules(schoolId: schoolId);
});

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  static final dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolFilter = ref.watch(scheduleSchoolFilterProvider);
    final schedulesAsync = ref.watch(allSchedulesProvider(schoolFilter));
    final schoolsAsync = ref.watch(schoolsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        title: 'Jadwal Mengajar',
        extraActions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _showAddScheduleBottomSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  const Icon(LucideIcons.filter, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: schoolsAsync.when(
                      data: (schools) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'Semua Sekolah',
                                selected: schoolFilter == 'all',
                                onSelected: () => ref.read(scheduleSchoolFilterProvider.notifier).state = 'all',
                              ),
                              ...schools.map((s) {
                                final id = s['id'] as String;
                                return _FilterChip(
                                  label: s['name'] as String,
                                  selected: schoolFilter == id,
                                  onSelected: () => ref.read(scheduleSchoolFilterProvider.notifier).state = id,
                                );
                              }),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: schedulesAsync.when(
                data: (schedules) {
                  if (schedules.isEmpty) {
                    return const Center(
                      child: Text(
                        'Belum ada jadwal mengajar.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: schedules.length,
                    itemBuilder: (context, index) {
                      final item = schedules[index];
                      return _ScheduleCard(
                        item: item,
                        dayName: dayNames[item.day - 1],
                        onTap: () => _showScheduleActionMenu(context, item),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddScheduleBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddScheduleBottomSheet(),
    );
  }

  void _showScheduleActionMenu(BuildContext context, ScheduleItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ScheduleActionSheet(item: item),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ShadBadge(
        backgroundColor: selected ? AppColors.primary : AppColors.secondary,
        foregroundColor: selected ? Colors.white : AppColors.textPrimary,
        child: InkWell(
          onTap: onSelected,
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final ScheduleItem item;
  final String dayName;
  final VoidCallback onTap;

  const _ScheduleCard({required this.item, required this.dayName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    dayName,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    item.startTime,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.subjectName} — ${item.className}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.schoolName} • ${item.room ?? 'Ruang Kelas'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.startTime} - ${item.endTime}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class ScheduleActionSheet extends ConsumerWidget {
  final ScheduleItem item;

  const ScheduleActionSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.subjectName} — ${item.className}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _ActionTile(icon: LucideIcons.userCheck, label: 'Absensi', onTap: () {
              Navigator.pop(context);
              context.go('/attendance');
            }),
            _ActionTile(icon: LucideIcons.notebookPen, label: 'Catatan Siswa', onTap: () {
              Navigator.pop(context);
              context.go('/notes');
            }),
            _ActionTile(icon: LucideIcons.bookOpen, label: 'Jurnal Mengajar', onTap: () {
              Navigator.pop(context);
              context.go('/notes');
            }),
            _ActionTile(icon: LucideIcons.clipboardList, label: 'Berikan Tugas', onTap: () {
              Navigator.pop(context);
              context.go('/tasks');
            }),
            _ActionTile(icon: LucideIcons.copy, label: 'Duplikasikan Jadwal', onTap: () {
              Navigator.pop(context);
              _showDuplicateDialog(context, ref, item);
            }),
            _ActionTile(icon: LucideIcons.trash2, label: 'Hapus Jadwal', isDestructive: true, onTap: () {
              Navigator.pop(context);
              _confirmDelete(context, ref, item.id);
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _showDuplicateDialog(BuildContext context, WidgetRef ref, ScheduleItem item) async {
    int targetDay = DateTime.now().weekday;
    TimeOfDay? newStartTime;
    TimeOfDay? newEndTime;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Duplikasikan Jadwal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: targetDay,
                decoration: const InputDecoration(labelText: 'Hari'),
                items: List.generate(7, (i) => DropdownMenuItem(value: i + 1, child: Text(ScheduleScreen.dayNames[i]))),
                onChanged: (v) => setState(() => targetDay = v ?? targetDay),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(DateTime.parse('2024-01-01 ${item.startTime}')));
                        if (t != null) setState(() => newStartTime = t);
                      },
                      child: Text(newStartTime != null ? '${newStartTime!.hour}:${newStartTime!.minute.toString().padLeft(2, '0')}' : 'Mulai (sama)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(DateTime.parse('2024-01-01 ${item.endTime}')));
                        if (t != null) setState(() => newEndTime = t);
                      },
                      child: Text(newEndTime != null ? '${newEndTime!.hour}:${newEndTime!.minute.toString().padLeft(2, '0')}' : 'Selesai (sama)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Duplikat')),
          ],
        ),
      ),
    );

    if (!confirmed!) return;
    final repo = ref.read(appRepositoryProvider);
    await repo.duplicateSchedule(
      scheduleId: item.id,
      targetDay: targetDay,
      newStartTime: newStartTime != null ? '${newStartTime!.hour.toString().padLeft(2, '0')}:${newStartTime!.minute.toString().padLeft(2, '0')}' : null,
      newEndTime: newEndTime != null ? '${newEndTime!.hour.toString().padLeft(2, '0')}:${newEndTime!.minute.toString().padLeft(2, '0')}' : null,
    );
    ref.invalidate(allSchedulesProvider);
    if (context.mounted) ShadToaster.of(context).show(const ShadToast(title: Text('Berhasil'), description: Text('Jadwal diduplikat.')));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Jadwal?'),
        content: const Text('Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: AppColors.statusRed))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(appRepositoryProvider).deleteSchedule(id);
      ref.invalidate(allSchedulesProvider);
      if (context.mounted) ShadToaster.of(context).show(const ShadToast(title: Text('Berhasil'), description: Text('Jadwal dihapus.')));
    }
  }
}

class _ActionTile extends ConsumerWidget {
  final IconData icon;
  final String label;
  final Widget Function(BuildContext, WidgetRef)? builder;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _ActionTile({required this.icon, required this.label, this.onTap, this.isDestructive = false}) : builder = null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = isDestructive ? AppColors.statusRed : AppColors.textPrimary;
    if (builder != null) return builder!(context, ref);
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

class AddScheduleBottomSheet extends ConsumerStatefulWidget {
  const AddScheduleBottomSheet({super.key});

  @override
  ConsumerState<AddScheduleBottomSheet> createState() => _AddScheduleBottomSheetState();
}

class _AddScheduleBottomSheetState extends ConsumerState<AddScheduleBottomSheet> {
  String? selectedSchoolId;
  String? selectedClassId;
  String? selectedSubjectId;
  int selectedDay = DateTime.now().weekday;
  TimeOfDay startTime = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay endTime = const TimeOfDay(hour: 9, minute: 0);
  final roomController = TextEditingController();
  final notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final schoolsAsync = ref.watch(schoolsProvider);
    final classesAsync = ref.watch(classesBySchoolProvider(selectedSchoolId));
    final subjectsAsync = ref.watch(subjectsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              const Text('Tambah Jadwal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              schoolsAsync.when(
                data: (schools) => ShadSelect<String>(
                  placeholder: const Text('Pilih Sekolah'),
                  initialValue: selectedSchoolId,
                  selectedOptionBuilder: (context, value) => Text(schools.firstWhere((s) => s['id'] == value)['name'] as String),
                  options: schools.map((s) => ShadOption(value: s['id'] as String, child: Text(s['name'] as String))).toList(),
                  onChanged: (val) => setState(() { selectedSchoolId = val; selectedClassId = null; }),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Gagal memuat sekolah'),
              ),
              const SizedBox(height: 12),
              classesAsync.when(
                data: (classes) => ShadSelect<String>(
                  placeholder: const Text('Pilih Kelas'),
                  initialValue: selectedClassId,
                  selectedOptionBuilder: (context, value) => Text(classes.firstWhere((c) => c['id'] == value)['name'] as String),
                  options: classes.map((c) => ShadOption(value: c['id'] as String, child: Text(c['name'] as String))).toList(),
                  onChanged: (val) => setState(() => selectedClassId = val),
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 12),
              subjectsAsync.when(
                data: (subjects) => ShadSelect<String>(
                  placeholder: const Text('Pilih Mata Pelajaran'),
                  initialValue: selectedSubjectId,
                  selectedOptionBuilder: (context, value) => Text(subjects.firstWhere((s) => s['id'] == value)['name'] as String),
                  options: subjects.map((s) => ShadOption(value: s['id'] as String, child: Text(s['name'] as String))).toList(),
                  onChanged: (val) => setState(() => selectedSubjectId = val),
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 12),
              ShadSelect<int>(
                placeholder: const Text('Pilih Hari'),
                initialValue: selectedDay,
                selectedOptionBuilder: (context, value) => Text(ScheduleScreen.dayNames[value - 1]),
                options: List.generate(7, (i) => i + 1).map((d) => ShadOption(value: d, child: Text(ScheduleScreen.dayNames[d - 1]))).toList(),
                onChanged: (val) => setState(() => selectedDay = val ?? 1),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      child: Text('Mulai: ${startTime.format(context)}'),
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: startTime);
                        if (t != null) setState(() => startTime = t);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShadButton.outline(
                      child: Text('Selesai: ${endTime.format(context)}'),
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: endTime);
                        if (t != null) setState(() => endTime = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ShadInput(controller: roomController, placeholder: const Text('Ruang Kelas (Opsional)')),
              const SizedBox(height: 12),
              ShadInput(controller: notesController, placeholder: const Text('Catatan (Opsional)')),
              const SizedBox(height: 20),
              ShadButton(
                child: const Text('Simpan Jadwal'),
                onPressed: () => _saveSchedule(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveSchedule(BuildContext context) async {
    if (selectedSchoolId == null || selectedClassId == null || selectedSubjectId == null) {
      ShadToaster.of(context).show(
        const ShadToast.destructive(title: Text('Lengkapi Data'), description: Text('Sekolah, kelas, dan mata pelajaran wajib diisi.')),
      );
      return;
    }

    final repo = ref.read(appRepositoryProvider);
    final conflict = await repo.checkScheduleConflict(
      schoolId: selectedSchoolId!,
      day: selectedDay,
      startTime: _formatTime(startTime),
      endTime: _formatTime(endTime),
      excludeId: null,
    );

    if (conflict.isNotEmpty && context.mounted) {
      final conflictItem = ScheduleItem.fromMap(conflict.first);
      final confirmed = await _showConflictDialog(context, conflictItem);
      if (!confirmed) return;
    }

    final scheduleId = await repo.insertSchedule(
      schoolId: selectedSchoolId!,
      classId: selectedClassId!,
      subjectId: selectedSubjectId!,
      day: selectedDay,
      startTime: _formatTime(startTime),
      endTime: _formatTime(endTime),
      room: roomController.text.isEmpty ? null : roomController.text,
      notes: notesController.text.isEmpty ? null : notesController.text,
    );

    await NotificationService.instance.scheduleScheduleReminder(
      payloadId: scheduleId,
      subjectName: 'Jadwal Mengajar',
      className: 'Kelas terjadwal',
      day: selectedDay,
      startTime: _formatTime(startTime),
    );

    if (context.mounted) {
      ref.invalidate(allSchedulesProvider);
      Navigator.of(context).pop();
    }
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<bool> _showConflictDialog(BuildContext context, ScheduleItem conflict) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(LucideIcons.alertTriangle, color: AppColors.statusYellow), SizedBox(width: 8), Text('Jadwal Bentrok')]),
        content: Text('Anda sudah memiliki jadwal ${conflict.subjectName} — ${conflict.className} pada pukul ${conflict.startTime}-${conflict.endTime}. Simpan tetap?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan Tetap', style: TextStyle(color: AppColors.statusRed))),
        ],
      ),
    );
    return result ?? false;
  }
}

final schoolsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(appRepositoryProvider).getSchools();
});

final classesBySchoolProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, schoolId) async {
  if (schoolId == null) return [];
  return ref.watch(appRepositoryProvider).getClassesBySchool(schoolId);
});

final subjectsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(appRepositoryProvider).getSubjects();
});
