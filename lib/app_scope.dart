import 'package:flutter/widgets.dart';

import 'domain/repositories/repositories.dart';
import 'services/app_lock_service.dart';
import 'services/backup_service.dart';
import 'services/export_service.dart';
import 'services/health_sync_service.dart';
import 'services/notification_service.dart';

class AppDependencies {
  const AppDependencies({
    required this.profiles,
    required this.measurements,
    required this.reminders,
    required this.importPreferences,
    required this.medications,
    required this.medicationDoseLogs,
    required this.medicationPreferences,
    required this.appLock,
    required this.healthSync,
    required this.notifications,
    required this.exports,
    required this.backup,
  });

  final ProfileRepository profiles;
  final MeasurementRepository measurements;
  final ReminderRepository reminders;
  final ImportPreferencesRepository importPreferences;
  final MedicationRepository medications;
  final MedicationDoseLogRepository medicationDoseLogs;
  final MedicationPreferencesRepository medicationPreferences;
  final AppLockService appLock;
  final HealthSyncService? healthSync;
  final NotificationService notifications;
  final ExportService exports;
  final BackupService backup;
}

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.dependencies,
    required super.child,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope no está en el árbol de widgets');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
