import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/app_repository.dart';
import '../schedule/schedule_screen.dart';

final manageSchoolsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(appRepositoryProvider).getSchools();
});

final manageClassesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, schoolId) async {
  return ref.watch(appRepositoryProvider).getClassesBySchool(schoolId);
});

class ManageDataScreen extends ConsumerStatefulWidget {
  const ManageDataScreen({super.key});

  @override
  ConsumerState<ManageDataScreen> createState() => _ManageDataScreenState();
}

class _ManageDataScreenState extends ConsumerState<ManageDataScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Data'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Sekolah'),
            Tab(text: 'Kelas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SchoolsTab(),
          _ClassesTab(),
        ],
      ),
    );
  }
}

class _SchoolsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolsAsync = ref.watch(manageSchoolsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showSchoolDialog(context, ref),
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      body: schoolsAsync.when(
        data: (schools) {
          if (schools.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.school, size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 10),
                  const Text('Belum ada sekolah', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  ShadButton(child: const Text('Tambah Sekolah'), onPressed: () => _showSchoolDialog(context, ref)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(manageSchoolsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: schools.length,
              itemBuilder: (context, i) {
                final s = schools[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(LucideIcons.school, size: 20, color: AppColors.primary),
                    ),
                    title: Text(s['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text((s['address'] as String?) ?? '-', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: IconButton(
                      icon: const Icon(LucideIcons.pencil, size: 18, color: AppColors.textMuted),
                      onPressed: () => _showSchoolDialog(context, ref, existing: s),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showSchoolDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final addressCtrl = TextEditingController(text: existing?['address'] as String? ?? '');
    final isEdit = existing != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Sekolah' : 'Tambah Sekolah'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShadInput(controller: nameCtrl, placeholder: const Text('Nama Sekolah *')),
            const SizedBox(height: 10),
            ShadInput(controller: addressCtrl, placeholder: const Text('Alamat (opsional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ShadButton(
            child: Text(isEdit ? 'Simpan' : 'Tambah'),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final repo = ref.read(appRepositoryProvider);
              if (isEdit) {
                await repo.updateSchool(existing['id'] as String, name, address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim());
              } else {
                await repo.insertSchool(name, address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim());
              }
              ref.invalidate(manageSchoolsProvider);
              ref.invalidate(schoolsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}

class _ClassesTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends ConsumerState<_ClassesTab> {
  String _schoolFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final schoolsAsync = ref.watch(manageSchoolsProvider);
    final classesAsync = ref.watch(manageClassesProvider(_schoolFilter));

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showClassDialog(context, ref),
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: schoolsAsync.when(
              data: (schools) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: 'Semua', selected: _schoolFilter == 'all', onTap: () => setState(() => _schoolFilter = 'all')),
                      ...schools.map((s) => _FilterChip(
                            label: s['name'] as String,
                            selected: _schoolFilter == s['id'],
                            onTap: () => setState(() => _schoolFilter = s['id'] as String),
                          )),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ),
          Expanded(
            child: classesAsync.when(
              data: (classes) {
                if (classes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.users, size: 40, color: AppColors.textMuted),
                        const SizedBox(height: 10),
                        const Text('Belum ada kelas', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        ShadButton(child: const Text('Tambah Kelas'), onPressed: () => _showClassDialog(context, ref)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(manageClassesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: classes.length,
                    itemBuilder: (context, i) {
                      final c = classes[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(LucideIcons.users, size: 20, color: AppColors.primary),
                          ),
                          title: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          subtitle: Text(
                            '${(c['school_name'] as String?) ?? '-'}${(c['grade'] as String?) != null ? ' • Tingkat ${c['grade']}' : ''}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: IconButton(
                            icon: const Icon(LucideIcons.pencil, size: 18, color: AppColors.textMuted),
                            onPressed: () => _showClassDialog(context, ref, existing: c),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showClassDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final gradeCtrl = TextEditingController(text: existing?['grade'] as String? ?? '');
    String? selectedSchoolId = existing?['school_id'] as String?;
    final isEdit = existing != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final schoolsAsync = ref.watch(manageSchoolsProvider);

          return AlertDialog(
            title: Text(isEdit ? 'Edit Kelas' : 'Tambah Kelas'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadInput(controller: nameCtrl, placeholder: const Text('Nama Kelas *')),
                const SizedBox(height: 10),
                ShadInput(controller: gradeCtrl, placeholder: const Text('Tingkat (7, 8, 9, 10, dll)')),
                const SizedBox(height: 10),
                schoolsAsync.when(
                  data: (schools) {
                    if (schools.isEmpty) {
                      return const Text('Tambah sekolah terlebih dahulu', style: TextStyle(color: AppColors.statusRed, fontSize: 13));
                    }
                    return InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: ctx,
                          builder: (bCtx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('Pilih Sekolah', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                const Divider(height: 1),
                                Flexible(
                                  child: ListView(
                                    shrinkWrap: true,
                                    children: schools.map((s) => ListTile(
                                          title: Text(s['name'] as String),
                                          subtitle: Text((s['address'] as String?) ?? ''),
                                          trailing: selectedSchoolId == s['id'] ? const Icon(LucideIcons.check, size: 18) : null,
                                          onTap: () {
                                            Navigator.pop(bCtx);
                                            setDialogState(() => selectedSchoolId = s['id'] as String);
                                          },
                                        )).toList(),
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
                            Expanded(
                              child: Text(
                                selectedSchoolId == null
                                    ? 'Pilih Sekolah *'
                                    : schools.where((s) => s['id'] == selectedSchoolId).map((s) => s['name'] as String).firstOrNull ?? 'Pilih Sekolah',
                                style: TextStyle(color: selectedSchoolId == null ? AppColors.textMuted : AppColors.textPrimary),
                              ),
                            ),
                            const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
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
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ShadButton(
                child: Text(isEdit ? 'Simpan' : 'Tambah'),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  if (!isEdit && selectedSchoolId == null) return;
                  final repo = ref.read(appRepositoryProvider);
                  if (isEdit) {
                    await repo.updateClass(
                      classId: existing['id'] as String,
                      name: name,
                      grade: gradeCtrl.text.trim().isEmpty ? null : gradeCtrl.text.trim(),
                      schoolId: selectedSchoolId,
                    );
                  } else {
                    await repo.insertClass(
                      schoolId: selectedSchoolId!,
                      name: name,
                      grade: gradeCtrl.text.trim().isEmpty ? null : gradeCtrl.text.trim(),
                    );
                  }
                  ref.invalidate(manageClassesProvider);
                  ref.invalidate(manageSchoolsProvider);
                  ref.invalidate(classesBySchoolProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textPrimary)),
        selected: selected,
        selectedColor: AppColors.primary,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
