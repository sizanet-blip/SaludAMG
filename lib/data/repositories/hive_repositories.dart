import 'package:hive/hive.dart';

import '../../domain/entities/app_lock_config.dart';
import '../../domain/entities/blood_pressure_model.dart';
import '../../domain/entities/import_preferences.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_dose_log.dart';
import '../../domain/entities/medication_preferences.dart';
import '../../domain/entities/reminder_config.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/repositories.dart';
import '../local/hive_boxes.dart';

class HiveProfileRepository implements ProfileRepository {
  Box<UserProfile> get _box => Hive.box<UserProfile>(HiveBoxes.profile);

  @override
  UserProfile current() => _box.get(UserProfile.storageKey) ?? UserProfile.defaults();

  @override
  Future<void> save(UserProfile profile) => _box.put(UserProfile.storageKey, profile);
}

class HiveMeasurementRepository implements MeasurementRepository {
  Box<BloodPressureModel> get _box =>
      Hive.box<BloodPressureModel>(HiveBoxes.readings);

  @override
  List<BloodPressureModel> getAll() {
    final readings = _box.values.toList()
      ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return readings;
  }

  @override
  Future<void> save(BloodPressureModel reading) => _box.put(reading.id, reading);

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Future<int> saveImported(List<BloodPressureModel> readings) async {
    final externalIds = <String>{};
    final fingerprints = <String>{};
    for (final reading in _box.values) {
      final externalId = reading.syncInfo.externalId;
      if (externalId != null && externalId.isNotEmpty) {
        externalIds.add(externalId);
      }
      fingerprints.add(_fingerprint(reading));
    }

    var added = 0;
    for (final reading in readings) {
      final externalId = reading.syncInfo.externalId;
      if (externalId != null &&
          externalId.isNotEmpty &&
          externalIds.contains(externalId)) {
        continue;
      }
      final fingerprint = _fingerprint(reading);
      if (fingerprints.contains(fingerprint)) continue;

      await _box.put(reading.id, reading);
      if (externalId != null && externalId.isNotEmpty) {
        externalIds.add(externalId);
      }
      fingerprints.add(fingerprint);
      added++;
    }
    return added;
  }

  String _fingerprint(BloodPressureModel reading) {
    final ext = reading.syncInfo.externalId?.trim();
    if (ext != null && ext.isNotEmpty) return 'ext|$ext';
    return '${reading.measuredAt.millisecondsSinceEpoch}|'
        '${reading.systolic}|${reading.diastolic}|'
        '${reading.pulse}|${reading.restingPulse}|'
        '${reading.weightKg}|${reading.glucoseMgDl}|'
        '${reading.oxygenSaturation}|${reading.steps}|'
        '${reading.bodyTemperatureC}|${reading.hrvMs}';
  }
}

class HiveReminderRepository implements ReminderRepository {
  Box<ReminderConfig> get _box => Hive.box<ReminderConfig>(HiveBoxes.reminders);

  @override
  ReminderConfig current() =>
      _box.get(ReminderConfig.storageKey) ?? ReminderConfig.defaults();

  @override
  Future<void> save(ReminderConfig config) =>
      _box.put(ReminderConfig.storageKey, config);
}

class HiveImportPreferencesRepository implements ImportPreferencesRepository {
  Box<ImportPreferences> get _box =>
      Hive.box<ImportPreferences>(HiveBoxes.importPrefs);

  @override
  ImportPreferences current() =>
      _box.get(ImportPreferences.storageKey) ?? ImportPreferences.defaults();

  @override
  Future<void> save(ImportPreferences preferences) =>
      _box.put(ImportPreferences.storageKey, preferences);
}

class HiveMedicationRepository implements MedicationRepository {
  Box<Medication> get _box => Hive.box<Medication>(HiveBoxes.medications);

  @override
  List<Medication> getAll() {
    final items = _box.values.toList()
      ..sort((a, b) {
        final byActive = (b.active ? 1 : 0).compareTo(a.active ? 1 : 0);
        if (byActive != 0) return byActive;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return items;
  }

  @override
  Medication? getById(String id) => _box.get(id);

  @override
  Future<void> save(Medication medication) =>
      _box.put(medication.id, medication);

  @override
  Future<void> delete(String id) => _box.delete(id);
}

class HiveMedicationDoseLogRepository implements MedicationDoseLogRepository {
  Box<MedicationDoseLog> get _box =>
      Hive.box<MedicationDoseLog>(HiveBoxes.medicationDoseLogs);

  @override
  List<MedicationDoseLog> getAll() {
    final items = _box.values.toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return items;
  }

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
    return _box.values
        .where(
          (log) =>
              log.medicationId == medicationId &&
              !log.scheduledAt.isBefore(start) &&
              log.scheduledAt.isBefore(end),
        )
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  @override
  MedicationDoseLog? findForSlot(String medicationId, DateTime scheduledAt) {
    final key = scheduledAt.millisecondsSinceEpoch;
    for (final log in _box.values) {
      if (log.medicationId == medicationId &&
          log.scheduledAt.millisecondsSinceEpoch == key) {
        return log;
      }
    }
    return null;
  }

  @override
  Future<void> save(MedicationDoseLog log) => _box.put(log.id, log);

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Future<int> deleteForMedication(String medicationId) async {
    final keys = _box.keys.where((key) {
      final log = _box.get(key);
      return log?.medicationId == medicationId;
    }).toList();
    await _box.deleteAll(keys);
    return keys.length;
  }
}

class HiveMedicationPreferencesRepository
    implements MedicationPreferencesRepository {
  Box<MedicationPreferences> get _box =>
      Hive.box<MedicationPreferences>(HiveBoxes.medicationPrefs);

  @override
  MedicationPreferences current() =>
      _box.get(MedicationPreferences.storageKey) ??
      MedicationPreferences.defaults();

  @override
  Future<void> save(MedicationPreferences preferences) =>
      _box.put(MedicationPreferences.storageKey, preferences);
}

class HiveAppLockRepository implements AppLockRepository {
  Box<AppLockConfig> get _box => Hive.box<AppLockConfig>(HiveBoxes.appLock);

  @override
  AppLockConfig current() =>
      _box.get(AppLockConfig.storageKey) ?? AppLockConfig.defaults();

  @override
  Future<void> save(AppLockConfig config) =>
      _box.put(AppLockConfig.storageKey, config);
}
