import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/services/onboarding_service.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../schedule/schedule_screen.dart';
import '../attendance/attendance_screen.dart';
import '../notes/notes_screen.dart';
import '../tasks/tasks_screen.dart';
import '../settings/settings_screen.dart';
import '../manage/manage_data_screen.dart';
import '../welcome/welcome_screen.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.blueGrey.shade300),
            const SizedBox(height: 12),
            Text('$title akan segera hadir', style: const TextStyle(color: Colors.blueGrey)),
          ],
        ),
      ),
    );
  }
}

GoRouter createRouter(OnboardingService onboardingService) {
  return GoRouter(
    initialLocation: onboardingService.isOnboardingDone ? '/dashboard' : '/welcome',
    redirect: (context, state) {
      final isDone = onboardingService.isOnboardingDone;
      final isWelcomeRoute = state.uri.path == '/welcome';

      if (!isDone && !isWelcomeRoute) {
        return '/welcome';
      }
      if (isDone && isWelcomeRoute) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/attendance', builder: (context, state) => const AttendanceScreen()),
          GoRoute(path: '/notes', builder: (context, state) => const NotesScreen()),
          GoRoute(path: '/schedule', builder: (context, state) => const ScheduleScreen()),
          GoRoute(path: '/tasks', builder: (context, state) => const TasksScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/manage', builder: (context, state) => const ManageDataScreen()),
        ],
      ),
    ],
  );
}

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const destinations = [
    (path: '/dashboard', label: 'Dashboard', icon: LucideIcons.house),
    (path: '/attendance', label: 'Absensi', icon: LucideIcons.userCheck),
    (path: '/notes', label: 'Catatan', icon: LucideIcons.notebookPen),
    (path: '/schedule', label: 'Jadwal', icon: LucideIcons.calendarDays),
    (path: '/tasks', label: 'Tugas', icon: LucideIcons.clipboardList),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    var selectedIndex = destinations.indexWhere((item) => item.path == location);
    if (selectedIndex < 0) selectedIndex = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => context.go(destinations[index].path),
        destinations: destinations
            .map((item) => NavigationDestination(icon: Icon(item.icon), label: item.label))
            .toList(),
      ),
    );
  }
}

class GuruAsistenApp extends StatelessWidget {
  final OnboardingService onboardingService;

  const GuruAsistenApp({super.key, required this.onboardingService});

  @override
  Widget build(BuildContext context) {
    return ShadApp.router(
      title: 'Guru Asisten',
      theme: AppTheme.shadcnTheme,
      routerConfig: createRouter(onboardingService),
    );
  }
}
