import 'dart:io';

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'app_scope.dart';
import 'data/local/hive_setup.dart';
import 'data/repositories/hive_repositories.dart';
import 'services/app_auth_service.dart';
import 'services/app_lock_service.dart';
import 'services/backup_service.dart';
import 'services/export_service.dart';
import 'services/health_sync_service.dart';
import 'services/notification_service.dart';
import 'services/temp_files.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES');
  await configureLocalTimezone();
  // Datos de la última cuenta que entró en este teléfono (si hay).
  final lastUser =
      AppAuthService.isConfigured ? await AppAuthService().username() : null;
  await initHive(username: lastUser);
  // Copias e informes compartidos en otra sesión: fuera del teléfono.
  await TempFiles.cleanOld();

  final notifications = NotificationService();
  final reminders = HiveReminderRepository();
  final medications = HiveMedicationRepository();
  final medicationDoseLogs = HiveMedicationDoseLogRepository();
  final medicationPreferences = HiveMedicationPreferencesRepository();
  final profiles = HiveProfileRepository();
  final measurements = HiveMeasurementRepository();
  final importPreferences = HiveImportPreferencesRepository();
  final appLock = AppLockService(HiveAppLockRepository());

  try {
    await notifications.initialize();
    await notifications.syncSchedule(reminders.current());
    await notifications.syncMedicationSchedule(
      medications: medications.getAll(),
      preferences: medicationPreferences.current(),
    );
  } catch (error, stack) {
    debugPrint('No se pudieron preparar los recordatorios: $error\n$stack');
  }

  HealthSyncService? healthSync;
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      final health = Health();
      await health.configure();
      healthSync = HealthSyncService(health);
    } catch (error, stack) {
      debugPrint('Salud del sistema no disponible: $error\n$stack');
    }
  }

  runApp(
    SaludAmgApp(
      dependencies: AppDependencies(
        profiles: profiles,
        measurements: measurements,
        reminders: reminders,
        importPreferences: importPreferences,
        medications: medications,
        medicationDoseLogs: medicationDoseLogs,
        medicationPreferences: medicationPreferences,
        appLock: appLock,
        healthSync: healthSync,
        notifications: notifications,
        exports: ExportService(),
        backup: BackupService(
          profiles: profiles,
          measurements: measurements,
          reminders: reminders,
          importPreferences: importPreferences,
          medications: medications,
          medicationDoseLogs: medicationDoseLogs,
          medicationPreferences: medicationPreferences,
        ),
      ),
    ),
  );
}
