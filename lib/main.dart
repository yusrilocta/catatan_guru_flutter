import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/onboarding_service.dart';
import 'data/datasources/local/database_helper.dart';
import 'presentation/app/app.dart';

@pragma('vm:entry-point')
void widgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  DatabaseHelper.initDesktop();
  await HomeWidgetService().updateWidgets();
}

@pragma('vm:entry-point')
void workmanagerCallback() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID');
    DatabaseHelper.initDesktop();
    await HomeWidgetService().updateWidgets();
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  DatabaseHelper.initDesktop();

  await NotificationService.instance.initialize();
  final prefs = await SharedPreferences.getInstance();
  final onboardingService = OnboardingService(prefs);

  try {
    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    await HomeWidgetService().updateWidgets();
  } catch (_) {}

  try {
    await Workmanager().initialize(workmanagerCallback, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      'guru-asisten-widget-refresh',
      'refreshWidgets',
      frequency: const Duration(minutes: 30),
    );
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [
        onboardingServiceProvider.overrideWithValue(onboardingService),
      ],
      child: GuruAsistenApp(onboardingService: onboardingService),
    ),
  );
}
