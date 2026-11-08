import 'package:flutter_test/flutter_test.dart';
import 'package:salud_amg/app.dart';
import 'package:salud_amg/app_scope.dart';
import 'package:salud_amg/domain/entities/app_lock_config.dart';
import 'package:salud_amg/domain/entities/blood_pressure_model.dart';
import 'package:salud_amg/domain/entities/import_preferences.dart';
import 'package:salud_amg/domain/entities/medication.dart';
import 'package:salud_amg/domain/entities/medication_dose_log.dart';
import 'package:salud_amg/domain/entities/medication_preferences.dart';
import 'package:salud_amg/domain/entities/reminder_config.dart';
import 'package:salud_amg/domain/entities/user_profile.dart';
import 'package:salud_amg/domain/repositories/repositories.dart';
import 'package:salud_amg/services/app_lock_service.dart';
import 'package:salud_amg/services/backup_service.dart';
import 'package:salud_amg/services/export_service.dart';
import 'package:salud_amg/services/notification_service.dart';

class _MemoryProfiles implements ProfileRepository {
  UserProfile _profile = UserProfile.defaults();

  @override
  UserProfile current() => _profile;

  @override
  Future<void> save(UserProfile profile) async => _profile = profile;
}

class _MemoryMeasurements implements MeasurementRepository {
  final List<BloodPressureModel> _items = [];

  @override
  List<BloodPressureModel> getAll() => List.unmodifiable(_items);

  @override
  Future<void> save(BloodPressureModel reading) async {
    _items.removeWhere((item) => item.id == reading.id);
    _items.add(reading);
  }

  @override
  Future<void> delete(String id) async => _items.removeWhere((item) => item.id == id);

  @override
  Future<int> saveImported(List<BloodPressureModel> readings) async {
    for (final reading in readings) {
      await save(reading);
    }
    return readings.length;
  }
}

class _MemoryReminders implements ReminderRepository {
  ReminderConfig _config = ReminderConfig.defaults();

  @override
  ReminderConfig current() => _config;

  @override
  Future<void> save(ReminderConfig config) async => _config = config;
}

class _MemoryImportPrefs implements ImportPreferencesRepository {
  ImportPreferences _prefs = ImportPreferences.defaults();

  @override
  ImportPreferences current() => _prefs;

  @override
  Future<void> save(ImportPreferences preferences) async => _prefs = preferences;
}

class _MemoryMedications implements MedicationRepository {
  final List<Medication> _items = [];

  @override
  List<Medication> getAll() => List.unmodifiable(_items);

  @override
  Medication? getById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<void> save(Medication medication) async {
    _items.removeWhere((item) => item.id == medication.id);
    _items.add(medication);
  }

  @override
  Future<void> delete(String id) async =>
      _items.removeWhere((item) => item.id == id);
}

class _MemoryDoseLogs implements MedicationDoseLogRepository {
  final List<MedicationDoseLog> _items = [];

  @override
  List<MedicationDoseLog> getAll() => List.unmodifiable(_items);

  @override
  List<MedicationDoseLog> forMedicationOnDay(
    String medicationId,
    DateTime day,
  ) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return forMedicationInRange(medicationId, start, end);
  }

  @override
  List<MedicationDoseLog> forMedicationInRange(
    String medicationId,
    DateTime start,
    DateTime end,
  ) {
    return _items
        .where(
          (log) =>
              log.medicationId == medicationId &&
              !log.scheduledAt.isBefore(start) &&
              log.scheduledAt.isBefore(end),
        )
        .toList();
  }

  @override
  MedicationDoseLog? findForSlot(String medicationId, DateTime scheduledAt) {
    final key = scheduledAt.millisecondsSinceEpoch;
    for (final log in _items) {
      if (log.medicationId == medicationId &&
          log.scheduledAt.millisecondsSinceEpoch == key) {
        return log;
      }
    }
    return null;
  }

  @override
  Future<void> save(MedicationDoseLog log) async {
    _items.removeWhere((item) => item.id == log.id);
    _items.add(log);
  }

  @override
  Future<void> delete(String id) async =>
      _items.removeWhere((item) => item.id == id);

  @override
  Future<int> deleteForMedication(String medicationId) async {
    final before = _items.length;
    _items.removeWhere((item) => item.medicationId == medicationId);
    return before - _items.length;
  }
}

class _MemoryMedPrefs implements MedicationPreferencesRepository {
  MedicationPreferences _prefs = MedicationPreferences.defaults();

  @override
  MedicationPreferences current() => _prefs;

  @override
  Future<void> save(MedicationPreferences preferences) async =>
      _prefs = preferences;
}

class _MemoryAppLock implements AppLockRepository {
  AppLockConfig _config = AppLockConfig.defaults();

  @override
  AppLockConfig current() => _config;

  @override
  Future<void> save(AppLockConfig config) async => _config = config;
}

void main() {
  testWidgets('el resumen vacío muestra el CTA de medición', (tester) async {
    final profiles = _MemoryProfiles();
    final measurements = _MemoryMeasurements();
    final reminders = _MemoryReminders();
    final importPreferences = _MemoryImportPrefs();
    final medications = _MemoryMedications();
    final doseLogs = _MemoryDoseLogs();
    final medPrefs = _MemoryMedPrefs();
    await tester.pumpWidget(
      SaludAmgApp(
        dependencies: AppDependencies(
          profiles: profiles,
          measurements: measurements,
          reminders: reminders,
          importPreferences: importPreferences,
          medications: medications,
          medicationDoseLogs: doseLogs,
          medicationPreferences: medPrefs,
          appLock: AppLockService(_MemoryAppLock()),
          healthSync: null,
          notifications: NotificationService(),
          exports: ExportService(),
          backup: BackupService(
            profiles: profiles,
            measurements: measurements,
            reminders: reminders,
            importPreferences: importPreferences,
            medications: medications,
            medicationDoseLogs: doseLogs,
            medicationPreferences: medPrefs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // La pantalla de inicio es un menú: el aviso está dentro de Resumen.
    await tester.tap(find.text('Resumen'));
    await tester.pumpAndSettle();
    expect(find.text('Añadir medición'), findsOneWidget);
  });
}
