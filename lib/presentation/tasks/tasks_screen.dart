import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/models/assignment_model.dart';
import '../../data/repositories/app_repository.dart';
import '../schedule/schedule_screen.dart';

final assignmentFilterProvider = StateProvider<String>((ref) => 'Semua');
final assignmentsProvider = FutureProvider.family<List<AssignmentItem>, String>((ref, filter) {
  return ref.watch(appRepositoryProvider).getAssignments(status: filter);
});

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  static const filters = ['Semua', 'Aktif', 'Selesai', 'Diarsipkan'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(assignmentFilterProvider);
    final tasksAsync = ref.watch(assignmentsProvider(filter));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        title: 'Tugas',
        extraActions: [
          IconButton(icon: const Icon(LucideIcons.plus), onPressed: () => _showAddTask(context)),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: filters.map((item) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterButton(
                  label: item,
                  selected: filter == item,
                  onTap: () => ref.read(assignmentFilterProvider.notifier).state = item,
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) => tasks.isEmpty
                  ? const Center(child: Text('Belum ada tugas.', style: TextStyle(color: AppColors.textSecondary)))
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(assignmentsProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) => _TaskCard(task: tasks[index]),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTask(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _TaskForm());
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ShadButton.outline(
      size: ShadButtonSize.sm,
      backgroundColor: selected ? AppColors.primary : null,
      foregroundColor: selected ? Colors.white : AppColors.textPrimary,
      onPressed: onTap,
      child: Text(label),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final AssignmentItem task;
  const _TaskCard({required this.task});

  ({String label, Color color, Color background}) _deadlineStyle() {
    final deadline = DateTime.tryParse(task.deadline);
    if (deadline == null) return (label: task.status, color: AppColors.textSecondary, background: AppColors.statusGreyBg);
    final date = DateTime(deadline.year, deadline.month, deadline.day);
    final today = DateTime.now();
    final current = DateTime(today.year, today.month, today.day);
    final days = date.difference(current).inDays;
    if (task.status == 'Selesai') return (label: 'Selesai', color: AppColors.statusGreen, background: AppColors.statusGreenBg);
    if (days < 0) return (label: 'Terlambat', color: AppColors.statusRed, background: AppColors.statusRedBg);
    if (days == 0) return (label: 'Deadline hari ini', color: AppColors.statusRed, background: AppColors.statusRedBg);
    if (days <= 2) return (label: days == 1 ? 'Deadline besok' : '$days hari lagi', color: AppColors.statusYellow, background: AppColors.statusYellowBg);
    return (label: '$days hari lagi', color: AppColors.infoBlue, background: AppColors.infoBlueBg);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = _deadlineStyle();
    final deadline = DateTime.tryParse(task.deadline);
    final formatted = deadline == null ? task.deadline : DateFormat('EEEE, d MMM yyyy', 'id_ID').format(deadline);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
            onSelected: (value) async {
              if (value == 'hapus') {
                await ref.read(appRepositoryProvider).deleteAssignment(task.id);
              } else {
                await ref.read(appRepositoryProvider).updateAssignmentStatus(task.id, value);
              }
              ref.invalidate(assignmentsProvider);
            },
            itemBuilder: (_) => [
              if (task.status != 'Selesai') const PopupMenuItem(value: 'Selesai', child: Text('Tandai Selesai')),
              if (task.status != 'Diarsipkan') const PopupMenuItem(value: 'Diarsipkan', child: Text('Arsipkan')),
              const PopupMenuItem(value: 'hapus', child: Text('Hapus', style: TextStyle(color: AppColors.statusRed))),
            ],
          ),
        ]),
        const SizedBox(height: 4),
        Text('${task.subjectName ?? '-'} — ${task.className ?? '-'}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        if (task.description != null && task.description!.isNotEmpty) ...[
          const SizedBox(height: 10), Text(task.description!, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          const Icon(LucideIcons.calendarClock, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text('Deadline: $formatted', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(6)),
            child: Text(style.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: style.color)),
          ),
        ]),
      ]),
    );
  }
}

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm();
  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  String? schoolId;
  String? classId;
  String? subjectId;
  DateTime deadline = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    titleController.dispose(); descriptionController.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schools = ref.watch(schoolsProvider);
    final classes = ref.watch(classesBySchoolProvider(schoolId));
    final subjects = ref.watch(subjectsProvider);
    return DraggableScrollableSheet(
      expand: false, initialChildSize: .88, maxChildSize: .96,
      builder: (context, scroll) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        child: ListView(controller: scroll, children: [
          const Text('Buat Tugas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ShadInput(controller: titleController, placeholder: const Text('Judul tugas *')),
          const SizedBox(height: 12),
          ShadInput(controller: descriptionController, placeholder: const Text('Instruksi / deskripsi (opsional)'), minLines: 3, maxLines: 5),
          const SizedBox(height: 12),
          schools.when(data: (data) => _select<String>(
            value: schoolId, placeholder: 'Pilih Sekolah', data: data,
            label: (x) => x['name'] as String, id: (x) => x['id'] as String,
            onChanged: (value) => setState(() { schoolId = value; classId = null; }),
          ), loading: () => const SizedBox(), error: (_, __) => const SizedBox()),
          const SizedBox(height: 12),
          classes.when(data: (data) => _select<String>(
            value: classId, placeholder: 'Pilih Kelas', data: data,
            label: (x) => x['name'] as String, id: (x) => x['id'] as String,
            onChanged: (value) => setState(() => classId = value),
          ), loading: () => const SizedBox(), error: (_, __) => const SizedBox()),
          const SizedBox(height: 12),
          subjects.when(data: (data) => _select<String>(
            value: subjectId, placeholder: 'Pilih Mata Pelajaran', data: data,
            label: (x) => x['name'] as String, id: (x) => x['id'] as String,
            onChanged: (value) => setState(() => subjectId = value),
          ), loading: () => const SizedBox(), error: (_, __) => const SizedBox()),
          const SizedBox(height: 12),
          ShadButton.outline(
            width: double.infinity,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Deadline'), Text(DateFormat('d MMMM yyyy', 'id_ID').format(deadline))]),
            onPressed: () async {
              final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)), initialDate: deadline);
              if (picked != null) setState(() => deadline = picked);
            },
          ),
          const SizedBox(height: 20),
          ShadButton(width: double.infinity, onPressed: _save, child: const Text('Simpan Tugas')),
        ]),
      ),
    );
  }

  Widget _select<T>({required T? value, required String placeholder, required List<Map<String, dynamic>> data, required String Function(Map<String, dynamic>) label, required T Function(Map<String, dynamic>) id, required ValueChanged<T?> onChanged}) {
    return ShadSelect<T>(
      initialValue: value, placeholder: Text(placeholder),
      selectedOptionBuilder: (context, selected) => Text(label(data.firstWhere((item) => id(item) == selected))),
      options: data.map((item) => ShadOption(value: id(item), child: Text(label(item)))).toList(), onChanged: onChanged,
    );
  }

  Future<void> _save() async {
    if (titleController.text.trim().isEmpty || schoolId == null || classId == null || subjectId == null) return;
    final title = titleController.text.trim();
    await ref.read(appRepositoryProvider).insertAssignment(
      schoolId: schoolId!, classId: classId!, subjectId: subjectId!, title: title,
      description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
      assignedDate: DateTime.now().toIso8601String(), deadline: deadline.toIso8601String(),
    );

    // Jadwalkan pengingat deadline
    await NotificationService.instance.scheduleDeadlineReminder(
      payloadId: '${title}_${deadline.toIso8601String()}',
      title: title,
      deadline: deadline,
    );

    ref.invalidate(assignmentsProvider);
    ref.invalidate(upcomingAssignmentsProvider);
    if (mounted) Navigator.pop(context);
  }
}

final upcomingAssignmentsProvider = FutureProvider<List<AssignmentItem>>((ref) {
  return ref.watch(appRepositoryProvider).getUpcomingAssignments();
});
