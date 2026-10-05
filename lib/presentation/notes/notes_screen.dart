import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/models/schedule_model.dart';
import '../../data/models/student_model.dart';
import '../../data/models/note_model.dart';
import '../../data/repositories/app_repository.dart';

final notesTabProvider = StateProvider<int>((ref) => 0); // 0 = Catatan Siswa, 1 = Jurnal Mengajar
final selectedNoteClassProvider = StateProvider<String?>((ref) => null);
final selectedNoteStudentProvider = StateProvider<String?>((ref) => null);

final classesForNotesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(appRepositoryProvider).getClassesBySchool('all');
});

final studentsForNotesProvider = FutureProvider.family<List<StudentItem>, String>((ref, classId) async {
  return ref.watch(appRepositoryProvider).getStudentsByClass(classId);
});

final studentNotesProvider = FutureProvider.family<List<StudentNoteItem>, String>((ref, studentId) async {
  return ref.watch(appRepositoryProvider).getStudentNotes(studentId: studentId);
});

final todaySessionsProvider = FutureProvider<List<TeachingSessionItem>>((ref) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  return ref.watch(appRepositoryProvider).getTeachingSessions(date: today);
});

final allSessionsProvider = FutureProvider<List<TeachingSessionItem>>((ref) async {
  return ref.watch(appRepositoryProvider).getTeachingSessions();
});

final todaySchedulesForNotesProvider = FutureProvider<List<ScheduleItem>>((ref) async {
  return ref.watch(appRepositoryProvider).getTodaySchedules();
});

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  static const noteCategories = [
    'Akademik',
    'Perilaku',
    'Tugas',
    'Prestasi',
    'Positif',
    'Perhatian',
    'Umum',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(notesTabProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        title: 'Catatan & Jurnal',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => ref.read(notesTabProvider.notifier).state = 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: tabIndex == 0 ? AppColors.card : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: tabIndex == 0 ? Border.all(color: AppColors.border) : null,
                            boxShadow: tabIndex == 0
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                : null,
                          ),
                          child: Text(
                            'Catatan Siswa',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tabIndex == 0 ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => ref.read(notesTabProvider.notifier).state = 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: tabIndex == 1 ? AppColors.card : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: tabIndex == 1 ? Border.all(color: AppColors.border) : null,
                            boxShadow: tabIndex == 1
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                : null,
                          ),
                          child: Text(
                            'Jurnal Mengajar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tabIndex == 1 ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: tabIndex == 0 ? _StudentNotesTab() : _TeachingJournalTab(),
      ),
    );
  }
}

class _StudentNotesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedClassId = ref.watch(selectedNoteClassProvider);
    final selectedStudentId = ref.watch(selectedNoteStudentProvider);
    final classesAsync = ref.watch(classesForNotesProvider);

    return Column(
      children: [
        // Class & Student Filter
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: AppColors.card,
          child: Column(
            children: [
              classesAsync.when(
                data: (classes) => _ClassSelector(
                  key: ValueKey('class-$selectedClassId-${classes.length}'),
                  classes: classes,
                  selectedId: selectedClassId,
                  onChanged: (id) {
                    ref.read(selectedNoteClassProvider.notifier).state = id;
                    ref.read(selectedNoteStudentProvider.notifier).state = null;
                  },
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              if (selectedClassId != null) ...[
                const SizedBox(height: 10),
                ref.watch(studentsForNotesProvider(selectedClassId)).when(
                  data: (students) => _StudentSelector(
                    key: ValueKey('student-$selectedStudentId-${students.length}'),
                    students: students,
                    selectedId: selectedStudentId,
                    onChanged: (id) => ref.read(selectedNoteStudentProvider.notifier).state = id,
                  ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // Notes List or Add Form
        Expanded(
          child: selectedStudentId == null
              ? const Center(
                  child: Text('Pilih siswa untuk melihat/membuat catatan', style: TextStyle(color: AppColors.textSecondary)),
                )
              : _NotesList(studentId: selectedStudentId),
        ),
      ],
    );
  }
}

class _ClassSelector extends StatelessWidget {
  final List<Map<String, dynamic>> classes;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _ClassSelector({super.key, required this.classes, required this.selectedId, required this.onChanged});

  void _openSheet(BuildContext context) {
    final label = selectedId == null
        ? 'Pilih Kelas'
        : classes.where((c) => c['id'] == selectedId).map((c) => c['name'] as String).join();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Pilih Kelas ($label)', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: const Text('Pilih Kelas'),
                    subtitle: const Text('Tampilkan tanpa filter'),
                    trailing: selectedId == null ? const Icon(LucideIcons.check, size: 18) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onChanged(null);
                    },
                  ),
                  ...classes.map((c) => ListTile(
                        title: Text(c['name'] as String),
                        subtitle: Text((c['school_name'] as String?) ?? ''),
                        trailing: selectedId == c['id'] ? const Icon(LucideIcons.check, size: 18) : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          onChanged(c['id'] as String);
                        },
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = selectedId == null
        ? 'Pilih Kelas'
        : classes.where((c) => c['id'] == selectedId).map((c) => c['name'] as String).join();
    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label.isEmpty ? 'Pilih Kelas' : label)),
            const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _StudentSelector extends StatelessWidget {
  final List<StudentItem> students;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _StudentSelector({super.key, required this.students, required this.selectedId, required this.onChanged});

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Pilih Siswa', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: const Text('Pilih Siswa'),
                    trailing: selectedId == null ? const Icon(LucideIcons.check, size: 18) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onChanged(null);
                    },
                  ),
                  ...students.map((s) => ListTile(
                        title: Text(s.name),
                        subtitle: s.studentNumber == null ? null : Text(s.studentNumber!),
                        trailing: selectedId == s.id ? const Icon(LucideIcons.check, size: 18) : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          onChanged(s.id);
                        },
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final match = students.where((s) => s.id == selectedId);
    final label = selectedId == null ? 'Pilih Siswa' : (match.isEmpty ? 'Pilih Siswa' : match.first.name);
    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _NotesList extends ConsumerStatefulWidget {
  final String studentId;

  const _NotesList({required this.studentId});

  @override
  ConsumerState<_NotesList> createState() => _NotesListState();
}

class _NotesListState extends ConsumerState<_NotesList> {
  final TextEditingController contentController = TextEditingController();
  String selectedCategory = 'Umum';
  bool showAddForm = false;

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(studentNotesProvider(widget.studentId));

    return notesAsync.when(
      data: (notes) {
        return Column(
          children: [
            // Add Note Form
            if (showAddForm)
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Tambah Catatan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const Spacer(),
                        ShadButton.outline(
                          size: ShadButtonSize.sm,
                          child: const Text('Batal'),
                          onPressed: () => setState(() => showAddForm = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ShadSelect<String>(
                      initialValue: selectedCategory,
                      selectedOptionBuilder: (context, value) => Text(value),
                      options: NotesScreen.noteCategories.map((c) => ShadOption(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => selectedCategory = val ?? 'Umum'),
                    ),
                    const SizedBox(height: 12),
                    ShadInput(
                      controller: contentController,
                      placeholder: const Text('Tulis catatan di sini...'),
                      minLines: 4,
                      maxLines: 6,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ShadButton(
                          child: const Text('Simpan'),
                          onPressed: () => _saveNote(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Notes List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notes.length + (showAddForm ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index == notes.length && !showAddForm) {
                    return Center(
                      child: ShadButton.outline(
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Icon(LucideIcons.plus, size: 16), SizedBox(width: 8), Text('Tambah Catatan')],
                        ),
                        onPressed: () => setState(() => showAddForm = true),
                      ),
                    );
                  }
                  final note = notes[index];
                  return _NoteCard(
                    note: note,
                    onEdit: () {
                      contentController.text = note.content;
                      selectedCategory = note.category;
                      setState(() => showAddForm = true);
                    },
                    onDelete: () => _deleteNote(note.id),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _saveNote(BuildContext context) async {
    if (contentController.text.trim().isEmpty) return;

    await ref.read(appRepositoryProvider).addStudentNote(
      studentId: widget.studentId,
      category: selectedCategory,
      content: contentController.text.trim(),
    );

    contentController.clear();
    setState(() => showAddForm = false);
    ref.invalidate(studentNotesProvider);
    if (mounted) {
      ShadToaster.of(context).show(const ShadToast(title: Text('Berhasil'), description: Text('Catatan disimpan.')));
    }
  }

  Future<void> _deleteNote(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Catatan'),
        content: const Text('Yakin ingin menghapus catatan ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: AppColors.statusRed))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(appRepositoryProvider).deleteStudentNote(noteId);
      ref.invalidate(studentNotesProvider);
      if (mounted) {
        ShadToaster.of(context).show(const ShadToast(title: Text('Berhasil'), description: Text('Catatan dihapus.')));
      }
    }
  }
}

class _NoteCard extends StatelessWidget {
  final StudentNoteItem note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteCard({required this.note, required this.onEdit, required this.onDelete});

  Color _categoryColor(String category) {
    return switch (category) {
      'Akademik' => Colors.blue,
      'Perilaku' => Colors.orange,
      'Tugas' => Colors.purple,
      'Prestasi' => Colors.amber,
      'Positif' => AppColors.statusGreen,
      'Perhatian' => AppColors.statusRed,
      _ => AppColors.textMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(note.date);
    final formattedDate = date != null ? DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(date) : note.date;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _categoryColor(note.category).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  note.category,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _categoryColor(note.category)),
                ),
              ),
              const Spacer(),
              Text(formattedDate, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(note.content, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.edit2, size: 16, color: AppColors.textMuted),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.statusRed),
                onPressed: onDelete,
                tooltip: 'Hapus',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeachingJournalTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TeachingJournalTab> createState() => _TeachingJournalTabState();
}

class _TeachingJournalTabState extends ConsumerState<_TeachingJournalTab> {
  final TextEditingController materialController = TextEditingController();
  final TextEditingController objectiveController = TextEditingController();
  final TextEditingController activityController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  String? selectedScheduleId;
  bool showAddForm = false;

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(todaySessionsProvider);
    final schedulesAsync = ref.watch(todaySchedulesForNotesProvider);

    return Column(
      children: [
        // Schedule Selector for new session
        if (!showAddForm)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: AppColors.card,
            child: schedulesAsync.when(
              data: (schedules) {
                if (schedules.isEmpty) {
                  return const Text('Tidak ada jadwal hari ini.', style: TextStyle(color: AppColors.textSecondary));
                }
                final match = schedules.where((s) => s.id == selectedScheduleId);
                final label = match.isEmpty
                    ? 'Pilih jadwal untuk jurnal hari ini'
                    : '${match.first.subjectName} - ${match.first.className} (${match.first.startTime})';
                return InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Pilih Jadwal', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            const Divider(height: 1),
                            Flexible(
                              child: ListView(
                                shrinkWrap: true,
                                children: schedules
                                    .map((s) => ListTile(
                                          title: Text('${s.subjectName} - ${s.className}'),
                                          subtitle: Text('${s.startTime} - ${s.endTime}'),
                                          trailing: selectedScheduleId == s.id
                                              ? const Icon(LucideIcons.check, size: 18)
                                              : null,
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            setState(() => selectedScheduleId = s.id);
                                          },
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(label)),
                        const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ),

        const Divider(height: 1),

        Expanded(
          child: sessionsAsync.when(
            data: (sessions) {
              if (sessions.isEmpty && !showAddForm) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.bookOpen, size: 48, color: AppColors.textMuted),
                      SizedBox(height: 12),
                      Text('Belum ada jurnal hari ini', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sessions.length + (showAddForm ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == sessions.length && showAddForm) {
                    return _SessionForm(
                      scheduleId: selectedScheduleId,
                      onCancel: () => setState(() => showAddForm = false),
                      onSave: (session) async {
                        if (selectedScheduleId == null) return;
                        await ref.read(appRepositoryProvider).addTeachingSession(
                          scheduleId: selectedScheduleId!,
                          date: DateTime.now().toIso8601String().substring(0, 10),
                          material: session['material']!,
                          objective: session['objective'],
                          activity: session['activity'],
                          notes: session['notes'],
                        );
                        setState(() => showAddForm = false);
                        ref.invalidate(todaySessionsProvider);
                        if (mounted) {
                          ShadToaster.of(context).show(const ShadToast(title: Text('Berhasil'), description: Text('Jurnal disimpan.')));
                        }
                      },
                    );
                  }

                  final session = sessions[index];
                  return _SessionCard(
                    session: session,
                    onEdit: () {
                      materialController.text = session.material;
                      objectiveController.text = session.objective ?? '';
                      activityController.text = session.activity ?? '';
                      notesController.text = session.notes ?? '';
                      selectedScheduleId = session.scheduleId;
                      setState(() => showAddForm = true);
                    },
                    onDelete: () => _deleteSession(session.id),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),

        // Add Button
        if (!showAddForm && selectedScheduleId != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.card,
            child: ShadButton(
              width: double.infinity,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Icon(LucideIcons.plus, size: 18), SizedBox(width: 8), Text('Buat Jurnal Baru')],
              ),
              onPressed: () => setState(() => showAddForm = true),
            ),
          ),
      ],
    );
  }

  Future<void> _deleteSession(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Jurnal'),
        content: const Text('Yakin ingin menghapus jurnal ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: AppColors.statusRed))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(appRepositoryProvider).deleteTeachingSession(sessionId);
      ref.invalidate(todaySessionsProvider);
      if (mounted) {
        ShadToaster.of(context).show(const ShadToast(title: Text('Berhasil'), description: Text('Jurnal dihapus.')));
      }
    }
  }
}

class _SessionCard extends StatelessWidget {
  final TeachingSessionItem session;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SessionCard({required this.session, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(session.date);
    final formattedDate = date != null ? DateFormat('d MMM yyyy', 'id_ID').format(date) : session.date;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(formattedDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  session.scheduleName ?? 'Jurnal Mengajar',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Materi:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(session.material, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          if (session.objective != null && session.objective!.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Tujuan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(session.objective!, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          ],
          if (session.activity != null && session.activity!.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Aktivitas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(session.activity!, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          ],
          if (session.notes != null && session.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Catatan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(session.notes!, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(icon: const Icon(LucideIcons.edit2, size: 16, color: AppColors.textMuted), onPressed: onEdit, tooltip: 'Edit'),
              IconButton(icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.statusRed), onPressed: onDelete, tooltip: 'Hapus'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionForm extends ConsumerStatefulWidget {
  final String? scheduleId;
  final VoidCallback onCancel;
  final Function(Map<String, String?>) onSave;

  const _SessionForm({required this.scheduleId, required this.onCancel, required this.onSave});

  @override
  ConsumerState<_SessionForm> createState() => _SessionFormState();
}

class _SessionFormState extends ConsumerState<_SessionForm> {
  final materialController = TextEditingController();
  final objectiveController = TextEditingController();
  final activityController = TextEditingController();
  final notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Buat Jurnal Baru', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const Spacer(),
              ShadButton.outline(size: ShadButtonSize.sm, onPressed: widget.onCancel, child: const Text('Batal')),
            ],
          ),
          const SizedBox(height: 16),
          ShadInput(
            controller: materialController,
            placeholder: const Text('Materi yang diajarkan *'),
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 12),
          ShadInput(
            controller: objectiveController,
            placeholder: const Text('Tujuan Pembelajaran (Opsional)'),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          ShadInput(
            controller: activityController,
            placeholder: const Text('Aktivitas (Opsional)'),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          ShadInput(
            controller: notesController,
            placeholder: const Text('Catatan Kelas (Opsional)'),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ShadButton(
                child: const Text('Simpan Jurnal'),
                onPressed: () {
                  if (materialController.text.trim().isEmpty) return;
                  widget.onSave({
                    'material': materialController.text.trim(),
                    'objective': objectiveController.text.trim().isEmpty ? null : objectiveController.text.trim(),
                    'activity': activityController.text.trim().isEmpty ? null : activityController.text.trim(),
                    'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}