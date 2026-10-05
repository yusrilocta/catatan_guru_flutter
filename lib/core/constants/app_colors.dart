import 'package:flutter/material.dart';

class AppColors {
  // Primary Shadcn Slate / Zinc theme palette
  static const Color primary = Color(0xFF0F172A); // slate-900
  static const Color primaryForeground = Color(0xFFF8FAFC);
  
  static const Color secondary = Color(0xFFF1F5F9); // slate-100
  static const Color secondaryForeground = Color(0xFF0F172A);

  static const Color background = Color(0xFFFAFAFA);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color input = Color(0xFFE2E8F0);
  
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Status Colors (from Spec Section 36)
  static const Color statusGreen = Color(0xFF16A34A); // Hadir, Selesai, Synced
  static const Color statusGreenBg = Color(0xFFDCFCE7);

  static const Color statusYellow = Color(0xFFD97706); // Mendekati deadline, Perlu perhatian, Pending
  static const Color statusYellowBg = Color(0xFFFEF3C7);

  static const Color statusRed = Color(0xFFDC2626); // Alpa, Terlambat, Bentrok, Failed
  static const Color statusRedBg = Color(0xFFFEE2E2);

  static const Color statusGrey = Color(0xFF6B7280); // Belum dilakukan, Tidak aktif
  static const Color statusGreyBg = Color(0xFFF3F4F6);

  static const Color infoBlue = Color(0xFF2563EB); // Izin / Informational
  static const Color infoBlueBg = Color(0xFFDBEAFE);
}
