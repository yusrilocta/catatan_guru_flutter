import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/onboarding_service.dart';
import '../../data/repositories/app_repository.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  int _currentStep = 0;

  // Step 1: Profil Guru
  final _teacherNameController = TextEditingController();
  final _teacherEmailController = TextEditingController();

  // Step 2: Sekolah & Kelas
  final _schoolNameController = TextEditingController();
  final _schoolAddressController = TextEditingController();
  final _classNameController = TextEditingController();
  final List<String> _classList = [];

  // Step 3: Mata Pelajaran (Fitur Penting Tambahan)
  final _subjectNameController = TextEditingController();
  final List<String> _subjectList = ['Matematika', 'Bahasa Indonesia'];

  bool _isSaving = false;

  @override
  void dispose() {
    _teacherNameController.dispose();
    _teacherEmailController.dispose();
    _schoolNameController.dispose();
    _schoolAddressController.dispose();
    _classNameController.dispose();
    _subjectNameController.dispose();
    super.dispose();
  }

  void _addClass() {
    final text = _classNameController.text.trim();
    if (text.isNotEmpty) {
      if (!_classList.contains(text)) {
        setState(() {
          _classList.add(text);
          _classNameController.clear();
        });
      } else {
        ShadToaster.of(context).show(
          const ShadToast.destructive(
            title: Text('Kelas sudah ada'),
            description: Text('Nama kelas tersebut sudah ditambahkan.'),
          ),
        );
      }
    }
  }

  void _addSubject() {
    final text = _subjectNameController.text.trim();
    if (text.isNotEmpty) {
      if (!_subjectList.contains(text)) {
        setState(() {
          _subjectList.add(text);
          _subjectNameController.clear();
        });
      }
    }
  }

  Future<void> _completeSetup() async {
    final teacherName = _teacherNameController.text.trim();
    final schoolName = _schoolNameController.text.trim();

    if (teacherName.isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast.destructive(
          title: Text('Nama Guru Wajib'),
          description: Text('Silakan masukkan nama Anda terlebih dahulu.'),
        ),
      );
      setState(() => _currentStep = 0);
      return;
    }

    if (_classList.isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast.destructive(
          title: Text('Kelas Wajib'),
          description: Text('Tambahkan minimal 1 kelas untuk mengajar.'),
        ),
      );
      setState(() => _currentStep = 1);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(appRepositoryProvider);

      // 1. Simpan user guru
      await repo.createTeacher(teacherName, _teacherEmailController.text.trim());

      // 2. Simpan sekolah
      final sName = schoolName.isEmpty ? 'Sekolah Saya' : schoolName;
      final schoolId = await repo.insertSchool(
        sName,
        address: _schoolAddressController.text.trim(),
      );

      // 3. Simpan kelas
      for (final className in _classList) {
        await repo.insertClass(
          schoolId: schoolId,
          name: className,
        );
      }

      // 4. Simpan mata pelajaran
      for (final subjectName in _subjectList) {
        await repo.insertSubject(subjectName);
      }

      // 5. Tandai onboarding selesai
      final onboarding = ref.read(onboardingServiceProvider);
      await onboarding.saveTeacherName(teacherName);
      await onboarding.completeOnboarding();

      // Refresh providers
      ref.invalidate(teacherProfileProvider);

      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Gagal Menyimpan'),
            description: Text(e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.graduationCap, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selamat Datang! 👋',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'Asisten Manajemen Pengajaran Guru',
                            style: TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mari lakukan pengaturan awal agar aplikasi siap digunakan untuk kegiatan mengajar Anda.',
                    style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),

            // Step Indicator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _StepTab(step: 0, label: '1. Profil Guru', activeStep: _currentStep),
                  const SizedBox(width: 8),
                  _StepTab(step: 1, label: '2. Kelas & Sekolah', activeStep: _currentStep),
                  const SizedBox(width: 8),
                  _StepTab(step: 2, label: '3. Mata Pelajaran', activeStep: _currentStep),
                ],
              ),
            ),

            // Step Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildCurrentStepContent(),
              ),
            ),

            // Footer Navigation Controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
                ],
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: ShadButton.outline(
                        onPressed: () => setState(() => _currentStep--),
                        child: const Text('Kembali'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ShadButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              if (_currentStep == 0) {
                                if (_teacherNameController.text.trim().isEmpty) {
                                  ShadToaster.of(context).show(
                                    const ShadToast.destructive(
                                      title: Text('Nama Wajib'),
                                      description: Text('Silakan isi nama guru.'),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => _currentStep = 1);
                              } else if (_currentStep == 1) {
                                if (_classList.isEmpty) {
                                  ShadToaster.of(context).show(
                                    const ShadToast.destructive(
                                      title: Text('Minimal 1 Kelas'),
                                      description: Text('Ketikkan nama kelas lalu tekan "Tambah Kelas".'),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => _currentStep = 2);
                              } else {
                                _completeSetup();
                              }
                            },
                      child: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(_currentStep == 2 ? 'Selesaikan Setup & Masuk' : 'Lanjut'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Identitas Guru',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Masukkan nama lengkap beserta gelar untuk identitas di kartu absensi & jurnal.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text('Nama Guru *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            ShadInput(
              controller: _teacherNameController,
              placeholder: const Text('Contoh: Budi Santoso, S.Pd.'),
            ),
            const SizedBox(height: 16),
            const Text('Email / Kontak (Opsional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            ShadInput(
              controller: _teacherEmailController,
              placeholder: const Text('Contoh: budi@guru.id'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sekolah & Kelas Mengajar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tambahkan tempat mengajar dan minimal 1 kelas yang Anda ampu.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            const Text('Nama Sekolah / Instansi (Opsional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            ShadInput(
              controller: _schoolNameController,
              placeholder: const Text('Contoh: SMP Negeri 1'),
            ),
            const SizedBox(height: 12),
            const Text('Alamat / Kota Sekolah (Opsional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            ShadInput(
              controller: _schoolAddressController,
              placeholder: const Text('Contoh: Jl. Merdeka No. 12'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Tambah Kelas Mengajar * (Min 1 Kelas)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 4),
            const Text(
              'Daftar nama siswa per kelas bisa ditambahkan kapan saja nanti dari menu utama.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ShadInput(
                    controller: _classNameController,
                    placeholder: const Text('Contoh: VIII A, IX B, 10 MIPA 1'),
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton(
                  onPressed: _addClass,
                  child: const Text('Tambah'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_classList.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusYellowBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.statusYellow.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.triangleAlert, size: 18, color: AppColors.statusYellow),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Belum ada kelas yang ditambahkan. Ketik nama kelas lalu tekan "Tambah".',
                        style: TextStyle(fontSize: 12, color: AppColors.statusYellow, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _classList.map((cls) {
                  return Chip(
                    backgroundColor: AppColors.secondary,
                    label: Text(cls, style: const TextStyle(fontWeight: FontWeight.w600)),
                    deleteIcon: const Icon(LucideIcons.x, size: 16),
                    onDeleted: () => setState(() => _classList.remove(cls)),
                  );
                }).toList(),
              ),
          ],
        );

      case 2:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mata Pelajaran yang Diampu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Daftarkan mata pelajaran yang Anda ajarkan agar siap dipilih saat menyusun jadwal & tugas.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ShadInput(
                    controller: _subjectNameController,
                    placeholder: const Text('Contoh: IPA, Fisika, Bahasa Inggris'),
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton(
                  onPressed: _addSubject,
                  child: const Text('Tambah'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _subjectList.map((subj) {
                return Chip(
                  backgroundColor: AppColors.secondary,
                  label: Text(subj, style: const TextStyle(fontWeight: FontWeight.w600)),
                  deleteIcon: const Icon(LucideIcons.x, size: 16),
                  onDeleted: () => setState(() => _subjectList.remove(subj)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.checkCircle2, color: AppColors.statusGreen, size: 20),
                      SizedBox(width: 8),
                      Text('Siap Dimulai!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Catatan siswa, jadwal detail, serta pembagian siswa tiap kelas bisa ditambahkan dengan fleksibel kapan saja lewat dashboard aplikasi.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }
}

class _StepTab extends StatelessWidget {
  final int step;
  final String label;
  final int activeStep;

  const _StepTab({required this.step, required this.label, required this.activeStep});

  @override
  Widget build(BuildContext context) {
    final isSelected = step == activeStep;
    final isDone = step < activeStep;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDone ? AppColors.statusGreenBg : AppColors.secondary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDone ? AppColors.statusGreen : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
