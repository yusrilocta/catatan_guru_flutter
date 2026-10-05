import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../constants/app_colors.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final PreferredSizeWidget? bottom;
  final List<Widget>? extraActions;

  const AppTopBar({super.key, required this.title, this.bottom, this.extraActions});

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      bottom: bottom,
      actions: [
        if (extraActions != null) ...extraActions!,
        PopupMenuButton<String>(
          icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
          tooltip: 'Menu',
          onSelected: (value) {
            if (value == 'manage') context.push('/manage');
            if (value == 'settings') context.push('/settings');
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'manage',
              child: Row(
                children: [
                  Icon(LucideIcons.school, size: 16),
                  SizedBox(width: 10),
                  Text('Data Sekolah & Kelas'),
                ],
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(LucideIcons.settings, size: 16),
                  SizedBox(width: 10),
                  Text('Pengaturan'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SettingsShortcutButton extends StatelessWidget {
  const SettingsShortcutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Pengaturan',
      icon: const Icon(LucideIcons.settings, size: 20, color: AppColors.textSecondary),
      onPressed: () => context.push('/settings'),
    );
  }
}
