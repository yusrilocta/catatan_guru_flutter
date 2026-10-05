import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  throw UnimplementedError('onboardingServiceProvider not initialized');
});

class OnboardingService {
  final SharedPreferences _prefs;
  static const _keyOnboardingDone = 'onboarding_done';
  static const _keyTeacherName = 'teacher_name';

  OnboardingService(this._prefs);

  bool get isOnboardingDone => _prefs.getBool(_keyOnboardingDone) ?? false;
  String? get teacherName => _prefs.getString(_keyTeacherName);

  Future<void> saveTeacherName(String name) async {
    await _prefs.setString(_keyTeacherName, name);
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_keyOnboardingDone, true);
  }
}
