import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/models/student_model.dart';
import '../../data/repositories/app_repository.dart';

final allClassesForAttendanceProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(appRepositoryProvider).getClassesBySchool('all');
});

final studentsByClassProvider = FutureProvider.family<List<StudentItem>, String>((ref, classId) async {
  return ref.watch(appRepositoryProvider).getStudentsByClass(classId);
});

final attendanceRecapProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, classId) async {
  return ref.watch(appRepositoryProvider).getAttendanceRecap(classId);
});

final attendanceDatesProvider = FutureProvider.family<List<String>, String>((ref, classId) async {
  return ref.watch(appRepositoryProvider).getAttendanceDates(classId);
});

final attendanceDetailProvider = FutureProvider.family<List<Map<String, dynamic>>, ({String classId, String date})>((ref, args) async {
  return ref.watch(appRepositoryProvider).getAttendanceDetail(classId: args.classId, datePrefix: args.date);
});

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(allClassesForAttendanceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(title: 'Absensi'),
      body: SafeArea(
        child: classesAsync.when(
          data: (classes) {
            if (classes.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.users, size: 40, color: AppColors.textMuted),
                    SizedBox(height: 10),
                    Text('Belum ada kelas. Tambah kelas dulu di Pengaturan awal.', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(allClassesForAttendanceProvider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: classes.length,
                itemBuilder: (context, index) {
                  final cls = classes[index];
                  return _ClassCard(cls: cls);
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _ClassCard extends ConsumerWidget {
  final Map<String, dynamic> cls;
  const _ClassCard({required this.cls});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classId = cls['id'] as String;
    final className = cls['name'] as String;
    final schoolName = (cls['school_name'] as String?) ?? '-';
    final studentsAsync = ref.watch(studentsByClassProvider(classId));

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final todayDetailAsync = ref.watch(attendanceDetailProvider((classId: classId, date: todayStr)));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _ClassAttendanceDetailPage(classId: classId, className: className, schoolName: schoolName),
              ));
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(LucideIcons.users, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(className, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(schoolName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        studentsAsync.when(
                          data: (students) => Text('${students.length} siswa', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mulai absensi hari ini',
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(LucideIcons.play, size: 16, color: Colors.white),
                    ),
                    onPressed: () => _openAttendanceSession(context, ref, classId, className),
                  ),
                  const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              children: [
                const Divider(height: 1),
                const SizedBox(height: 10),
                todayDetailAsync.when(
                  data: (rows) {
                    if (rows.isEmpty) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Belum absen hari ini — tap Play untuk mulai.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      );
                    }
                    int hadir = 0, izin = 0, alpa = 0;
                    for (final r in rows) {
                      final s = r['status'] as String?;
                      if (s == 'Hadir') {
                        hadir++;
                      } else if (s == 'Izin') izin++;
                      else if (s == 'Alpa') alpa++;
                      else if (s == 'Sakit') izin++;
                    }
                    final total = rows.length;
                    return Row(
                      children: [
                        _MiniStat(color: AppColors.statusGreen, label: 'Hadir', value: hadir),
                        const SizedBox(width: 6),
                        _MiniStat(color: AppColors.infoBlue, label: 'Izin', value: izin),
                        const SizedBox(width: 6),
                        _MiniStat(color: AppColors.statusRed, label: 'Alpha', value: alpa),
                        const Spacer(),
                        Text('$total siswa', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    );
                  },
                  loading: () => const SizedBox(height: 20, child: LinearProgressIndicator()),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 8),
                studentsAsync.when(
                  data: (students) {
                    if (students.isEmpty) {
                      return const Align(alignment: Alignment.centerLeft, child: Text('Belum ada siswa di kelas ini.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)));
                    }
                    final preview = students.take(4).toList();
                    return Column(
                      children: [
                        ...preview.map((s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  CircleAvatar(radius: 14, backgroundColor: AppColors.secondary, child: Text(s.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(s.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                  if (s.studentNumber != null) Text(s.studentNumber!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ),
                            )),
                        if (students.length > 4)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('+ ${students.length - 4} siswa lainnya — tap untuk lihat detail & rekap', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAttendanceSession(BuildContext context, WidgetRef ref, String classId, String className) async {
    final students = await ref.read(appRepositoryProvider).getStudentsByClass(classId);
    if (!context.mounted) return;
    if (students.isEmpty) {
      ShadToaster.of(context).show(const ShadToast(title: Text('Kelas kosong'), description: Text('Tambah siswa dulu sebelum absen.')));
      return;
    }
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final hasToday = await ref.read(appRepositoryProvider).hasAttendanceOnDate(classId, todayStr);
    if (!context.mounted) return;
    if (hasToday) {
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Absensi hari ini sudah ada'),
          content: const Text('Ingin timpa absensi hari ini?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Timpa')),
          ],
        ),
      );
      if (overwrite != true) return;
      await ref.read(appRepositoryProvider).deleteAttendanceByDate(classId, todayStr);
    }
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AttendanceSessionSheet(classId: classId, className: className, students: students),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  const _MiniStat({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$value $label', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _ClassAttendanceDetailPage extends ConsumerStatefulWidget {
  final String classId;
  final String className;
  final String schoolName;
  const _ClassAttendanceDetailPage({required this.classId, required this.className, required this.schoolName});

  @override
  ConsumerState<_ClassAttendanceDetailPage> createState() => _ClassAttendanceDetailPageState();
}

class _ClassAttendanceDetailPageState extends ConsumerState<_ClassAttendanceDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDate = DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsByClassProvider(widget.classId));
    final datesAsync = ref.watch(attendanceDatesProvider(widget.classId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.className, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(widget.schoolName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mulai absensi hari ini',
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(LucideIcons.play, size: 16, color: Colors.white),
            ),
            onPressed: () => _startSession(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
            onSelected: (v) {
              if (v == 'add_student') _showAddStudentDialog();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'add_student', child: Row(children: [Icon(LucideIcons.userPlus, size: 16), SizedBox(width: 8), Text('Tambah Siswa')])),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Daftar Siswa'),
            Tab(text: 'Detail'),
            Tab(text: 'Rekap'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          studentsAsync.when(
            data: (students) {
              if (students.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Belum ada siswa', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      ShadButton(onPressed: _showAddStudentDialog, child: const Text('Tambah Siswa')),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: students.length,
                itemBuilder: (context, i) {
                  final s = students[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 18, backgroundColor: AppColors.secondary, child: Text(s.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              if (s.studentNumber != null) Text(s.studentNumber!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(LucideIcons.ellipsisVertical, size: 16),
                          onSelected: (v) {
                            if (v == 'edit') _showEditStudentDialog(s);
                            if (v == 'delete') _deleteStudent(s.id);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Hapus')),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: datesAsync.when(
                  data: (dates) {
                    if (dates.isEmpty) {
                      return const Text('Belum ada data absensi', style: TextStyle(color: AppColors.textSecondary, fontSize: 13));
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: dates.map((d) {
                          final selected = d == _selectedDate;
                          final label = _formatDate(d);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textPrimary)),
                              selected: selected,
                              selectedColor: AppColors.primary,
                              onSelected: (_) => setState(() => _selectedDate = d),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final detailAsync = ref.watch(attendanceDetailProvider((classId: widget.classId, date: _selectedDate)));
                    return detailAsync.when(
                      data: (rows) {
                        if (rows.isEmpty) return const Center(child: Text('Tidak ada data', style: TextStyle(color: AppColors.textSecondary)));
                        final hasAnyStatus = rows.any((r) => r['status'] != null);
                        if (!hasAnyStatus) return Center(child: Text('Belum absen pada ${_formatDate(_selectedDate)}', style: const TextStyle(color: AppColors.textSecondary)));
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: rows.length,
                          itemBuilder: (context, i) {
                            final r = rows[i];
                            final status = r['status'] as String? ?? '-';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                              child: Row(
                                children: [
                                  Expanded(child: Text(r['student_name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                  _StatusBadge(status: status),
                                  const SizedBox(width: 8),
                                  Text(_formatDate((r['date'] as String?)?.substring(0, 10) ?? ''), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    );
                  },
                ),
              ),
            ],
          ),
          Consumer(
            builder: (context, ref, _) {
              final recapAsync = ref.watch(attendanceRecapProvider(widget.classId));
              return recapAsync.when(
                data: (rows) {
                  if (rows.isEmpty) return const Center(child: Text('Belum ada data rekap', style: TextStyle(color: AppColors.textSecondary)));
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      final hadir = (r['hadir'] as int?) ?? 0;
                      final izin = (r['izin'] as int?) ?? 0;
                      final sakit = (r['sakit'] as int?) ?? 0;
                      final alpa = (r['alpa'] as int?) ?? 0;
                      final total = (r['total'] as int?) ?? 0;
                      final izinTotal = izin + sakit;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['student_name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            if (r['student_number'] != null) Text(r['student_number'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _MiniStat(color: AppColors.statusGreen, label: 'Hadir', value: hadir),
                                _MiniStat(color: AppColors.infoBlue, label: 'Izin', value: izinTotal),
                                _MiniStat(color: AppColors.statusRed, label: 'Alpha', value: alpa),
                                Text('$total presensi', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return DateFormat('d MMM yyyy', 'id_ID').format(d);
    } catch (_) {
      return iso;
    }
  }

  Future<void> _startSession() async {
    final students = await ref.read(appRepositoryProvider).getStudentsByClass(widget.classId);
    if (!mounted) return;
    if (students.isEmpty) {
      ShadToaster.of(context).show(const ShadToast(title: Text('Kelas kosong'), description: Text('Tambah siswa dulu.')));
      return;
    }
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final hasToday = await ref.read(appRepositoryProvider).hasAttendanceOnDate(widget.classId, todayStr);
    if (!mounted) return;
    if (hasToday) {
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Absensi hari ini sudah ada'),
          content: const Text('Timpa absensi hari ini?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Timpa')),
          ],
        ),
      );
      if (overwrite != true) return;
      await ref.read(appRepositoryProvider).deleteAttendanceByDate(widget.classId, todayStr);
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AttendanceSessionSheet(classId: widget.classId, className: widget.className, students: students),
    );
  }

  void _showAddStudentDialog() {
    final nameCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Siswa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShadInput(controller: nameCtrl, placeholder: const Text('Nama siswa *')),
            const SizedBox(height: 10),
            ShadInput(controller: numCtrl, placeholder: const Text('NIS (opsional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ShadButton(
            child: const Text('Simpan'),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ref.read(appRepositoryProvider).insertStudent(classId: widget.classId, name: nameCtrl.text.trim(), studentNumber: numCtrl.text.trim().isEmpty ? null : numCtrl.text.trim());
              ref.invalidate(studentsByClassProvider);
              ref.invalidate(allClassesForAttendanceProvider);
              ref.invalidate(attendanceRecapProvider);
              if (mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showEditStudentDialog(StudentItem s) {
    final nameCtrl = TextEditingController(text: s.name);
    final numCtrl = TextEditingController(text: s.studentNumber ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Siswa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShadInput(controller: nameCtrl, placeholder: const Text('Nama siswa *')),
            const SizedBox(height: 10),
            ShadInput(controller: numCtrl, placeholder: const Text('NIS')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ShadButton(
            child: const Text('Simpan'),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ref.read(appRepositoryProvider).updateStudent(studentId: s.id, name: nameCtrl.text.trim(), studentNumber: numCtrl.text.trim().isEmpty ? null : numCtrl.text.trim());
              ref.invalidate(studentsByClassProvider);
              if (mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStudent(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Hapus siswa?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: AppColors.statusRed))) ]));
    if (ok == true) {
      await ref.read(appRepositoryProvider).deleteStudent(id);
      ref.invalidate(studentsByClassProvider);
      ref.invalidate(allClassesForAttendanceProvider);
      ref.invalidate(attendanceRecapProvider);
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  Color _color() {
    return switch (status) {
      'Hadir' => AppColors.statusGreen,
      'Izin' => AppColors.infoBlue,
      'Sakit' => AppColors.infoBlue,
      'Alpa' => AppColors.statusRed,
      'Alpha' => AppColors.statusRed,
      _ => AppColors.textMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: c.withValues(alpha: 0.25))),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

class _AttendanceSessionSheet extends ConsumerStatefulWidget {
  final String classId;
  final String className;
  final List<StudentItem> students;
  const _AttendanceSessionSheet({required this.classId, required this.className, required this.students});

  @override
  ConsumerState<_AttendanceSessionSheet> createState() => _AttendanceSessionSheetState();
}

class _AttendanceSessionSheetState extends ConsumerState<_AttendanceSessionSheet> {
  late Map<String, String> statuses;

  @override
  void initState() {
    super.initState();
    statuses = {for (final s in widget.students) s.id: 'Hadir'};
  }

  @override
  Widget build(BuildContext context) {
    final todayLabel = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Absensi — ${widget.className}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(todayLabel, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(LucideIcons.x, size: 18), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: widget.students.length,
                itemBuilder: (context, i) {
                  final s = widget.students[i];
                  final status = statuses[s.id]!;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 16, backgroundColor: AppColors.secondary, child: Text(s.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 10),
                        Expanded(child: Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: status,
                              isDense: true,
                              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                              items: const [
                                DropdownMenuItem(value: 'Hadir', child: Text('Hadir')),
                                DropdownMenuItem(value: 'Izin', child: Text('Izin')),
                                DropdownMenuItem(value: 'Alpa', child: Text('Alpha')),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => statuses[s.id] = v);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]),
              child: ShadButton(
                width: double.infinity,
                child: const Text('Simpan Absensi'),
                onPressed: () async {
                  final now = DateTime.now().toIso8601String();
                  await ref.read(appRepositoryProvider).saveAttendance(scheduleId: null, date: now, studentStatuses: statuses);
                  ref.invalidate(attendanceDatesProvider);
                  ref.invalidate(attendanceDetailProvider);
                  ref.invalidate(attendanceRecapProvider);
                  ref.invalidate(studentsByClassProvider);
                  ref.invalidate(allClassesForAttendanceProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ShadToaster.of(context).show(const ShadToast(title: Text('Berhasil'), description: Text('Absensi disimpan.')));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
