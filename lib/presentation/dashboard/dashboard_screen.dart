import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/models/schedule_model.dart';
import '../../data/models/assignment_model.dart';
import '../../data/repositories/app_repository.dart';

final todaySchedulesProvider = FutureProvider<List<ScheduleItem>>((ref) async {
  return ref.watch(appRepositoryProvider).getTodaySchedules();
});

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(appRepositoryProvider).getDashboardStats();
});

final upcomingAssignmentsProvider = FutureProvider<List<AssignmentItem>>((ref) async {
  return ref.watch(appRepositoryProvider).getUpcomingAssignments();
});

final studentsAttentionProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(appRepositoryProvider).getStudentsNeedingAttention();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(todaySchedulesProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final assignmentsAsync = ref.watch(upcomingAssignmentsProvider);
    final teacherAsync = ref.watch(teacherProfileProvider);

    final teacherName = teacherAsync.valueOrNull?['name'] as String? ?? 'Guru';

    final now = DateTime.now();
    final dateFormatted = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(
        title: 'Guru Asisten',
        extraActions: [
          SettingsShortcutButton(),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todaySchedulesProvider);
            ref.invalidate(dashboardStatsProvider);
            ref.invalidate(upcomingAssignmentsProvider);
            ref.invalidate(teacherProfileProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Greeting Header
                Text(
                  'Halo, $teacherName 👋',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormatted,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Quick Actions (Section 7)
                _buildQuickActions(context),
                const SizedBox(height: 20),

                // 3. Next Class / Ongoing Highlight Banner (Section 6)
                schedulesAsync.when(
                  data: (schedules) {
                    if (schedules.isNotEmpty) {
                      final nextSchedule = schedules.first;
                      return _buildUpcomingHeroCard(context, nextSchedule);
                    }
                    return _buildNoClassTodayCard();
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 20),

                // 4. Statistik Hari Ini (Section 8)
                statsAsync.when(
                  data: (stats) => _buildStatisticsSummary(stats),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 20),

                // 5. Timeline Jadwal Hari Ini (Section 6)
                const Text(
                  'Jadwal Hari Ini',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                schedulesAsync.when(
                  data: (schedules) => _buildScheduleList(context, schedules),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Text('Error: $err'),
                ),
                const SizedBox(height: 24),

                // 6. Tugas Mendekati Deadline (Section 10)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tugas Mendekati Deadline',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/tasks'),
                      child: const Text('Lihat Semua', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                assignmentsAsync.when(
                  data: (tasks) => _buildTaskList(tasks),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 24),

                // 7. Rekap Siswa Perlu Perhatian (Section 9)
                _buildStudentsNeedAttentionCard(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'label': 'Absensi', 'icon': LucideIcons.userCheck, 'route': '/attendance'},
      {'label': 'Catatan', 'icon': LucideIcons.notebookPen, 'route': '/notes'},
      {'label': 'Jadwal', 'icon': LucideIcons.calendar, 'route': '/schedule'},
      {'label': 'Tugas', 'icon': LucideIcons.clipboardList, 'route': '/tasks'},
      {'label': 'Jurnal', 'icon': LucideIcons.bookOpen, 'route': '/notes'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: actions.map((act) {
          return Expanded(
            child: InkWell(
              onTap: () => context.go(act['route'] as String),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(act['icon'] as IconData, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    act['label'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUpcomingHeroCard(BuildContext context, ScheduleItem schedule) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusYellowBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.clock, size: 14, color: AppColors.statusYellow),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Kelas Berikutnya',
                        style: TextStyle(
                          color: AppColors.statusYellow,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${schedule.startTime} - ${schedule.endTime}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${schedule.subjectName} — ${schedule.className}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${schedule.schoolName} • ${schedule.room ?? 'Ruang Kelas'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/attendance'),
                  icon: const Icon(LucideIcons.userCheck, size: 16),
                  label: const Text('Mulai Absensi', maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/notes'),
                  icon: const Icon(LucideIcons.bookOpen, size: 16, color: Colors.white),
                  label: const Text('Jurnal', style: TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoClassTodayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(LucideIcons.checkCheck, color: AppColors.statusGreen),
          SizedBox(width: 12),
          Text(
            'Tidak ada jadwal mengajar tersisa hari ini.',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSummary(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statItem('${stats['schedules'] ?? 0}', 'Jadwal'),
          _divider(),
          _statItem('${stats['classes'] ?? 0}', 'Kelas'),
          _divider(),
          _statItem('${stats['students'] ?? 0}', 'Siswa'),
          _divider(),
          _statItem('${stats['attendanceDone'] ?? 0}', 'Absensi'),
          _divider(),
          _statItem('${stats['activeTasks'] ?? 0}', 'Tugas'),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 24,
      color: AppColors.border,
    );
  }

  Widget _buildScheduleList(BuildContext context, List<ScheduleItem> schedules) {
    if (schedules.isEmpty) {
      return const Text(
        'Belum ada jadwal mengajar untuk hari ini.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }

    return Column(
      children: schedules.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      item.startTime,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      item.endTime,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
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
                      '${item.subjectName} • ${item.className}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.schoolName} (${item.room ?? 'Ruang Kelas'})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
                onPressed: () {},
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTaskList(List<AssignmentItem> tasks) {
    if (tasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Tidak ada tugas yang mendekati deadline.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return Column(
      children: tasks.map((t) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${t.subjectName ?? ''} — ${t.className ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.statusYellowBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    t.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusYellow,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStudentsNeedAttentionCard() {
    return Consumer(
      builder: (context, ref, _) {
        final attentionAsync = ref.watch(studentsAttentionProvider);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.alertCircle, size: 18, color: AppColors.statusYellow),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Siswa Perlu Perhatian',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              attentionAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Text(
                      'Belum ada siswa yang perlu perhatian. Data diambil dari catatan Perhatian/Perilaku & rekap Alpha.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    );
                  }
                  return Column(
                    children: items.map((item) {
                      final name = item['student_name'] as String? ?? '-';
                      final className = item['class_name'] as String? ?? '-';
                      final hadir = (item['hadir'] as int?) ?? 0;
                      final alpa = (item['alpa'] as int?) ?? 0;
                      final total = (item['total'] as int?) ?? 0;
                      final perhatian = (item['perhatian_count'] as int?) ?? 0;
                      final note = item['last_note'] as String?;
                      final hadirPct = total > 0 ? ((hadir / total) * 100).round() : 0;
                      return InkWell(
                        onTap: () => context.go('/notes'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.statusGreyBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$className • Hadir $hadirPct% | Alpha $alpa${perhatian > 0 ? ' | $perhatian catatan' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (note != null && note.isNotEmpty)
                                      Text(
                                        note,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
                error: (e, _) => Text('Error: $e', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ),
        );
      },
    );
  }
}
