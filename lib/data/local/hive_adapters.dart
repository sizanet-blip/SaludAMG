import 'package:hive/hive.dart';

import '../../domain/entities/app_lock_config.dart';
import '../../domain/entities/blood_pressure_model.dart';
import '../../domain/entities/import_preferences.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_dose_log.dart';
import '../../domain/entities/medication_preferences.dart';
import '../../domain/entities/reminder_config.dart';
import '../../domain/entities/sync_info.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/enums/health_enums.dart';
import 'hive_boxes.dart';

void registerHiveAdapters() {
  _register(HiveTypeIds.syncInfo, SyncInfoAdapter());
  _register(HiveTypeIds.userProfile, UserProfileAdapter());
  _register(HiveTypeIds.bloodPressure, BloodPressureAdapter());
  _register(HiveTypeIds.reminder, ReminderConfigAdapter());
  _register(HiveTypeIds.importPreferences, ImportPreferencesAdapter());
  _register(HiveTypeIds.medication, MedicationAdapter());
  _register(HiveTypeIds.medicationDoseLog, MedicationDoseLogAdapter());
  _register(HiveTypeIds.medicationPreferences, MedicationPreferencesAdapter());
  _register(HiveTypeIds.appLock, AppLockConfigAdapter());
}

void _register<T>(int typeId, TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(typeId)) {
    Hive.registerAdapter(adapter);
  }
}

Map<int, dynamic> _readFields(BinaryReader reader) {
  final count = reader.readByte();
  final fields = <int, dynamic>{};
  for (var i = 0; i < count; i++) {
    fields[reader.readByte()] = reader.read();
  }
  return fields;
}

void _writeFields(BinaryWriter writer, Map<int, dynamic> fields) {
  writer.writeByte(fields.length);
  for (final entry in fields.entries) {
    writer
      ..writeByte(entry.key)
      ..write(entry.value);
  }
}

T _enumAt<T>(List<T> values, dynamic raw, T fallback) {
  if (raw is int && raw >= 0 && raw < values.length) return values[raw];
  return fallback;
}

int _asInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

double? _asDouble(dynamic value) => value is num ? value.toDouble() : null;

String _asString(dynamic value, [String fallback = '']) {
  return value is String ? value : fallback;
}

DateTime? _asDate(dynamic value) => value is DateTime ? value : null;

bool _asBool(dynamic value, [bool fallback = false]) {
  return value is bool ? value : fallback;
}

List<int> _asIntList(dynamic value) {
  if (value is! List) return const [];
  return [for (final item in value) if (item is num) item.toInt()];
}

class SyncInfoAdapter extends TypeAdapter<SyncInfo> {
  @override
  int get typeId => HiveTypeIds.syncInfo;

  @override
  SyncInfo read(BinaryReader reader) {
    final fields = _readFields(reader);
    return SyncInfo(
      origin: _enumAt(ReadingOrigin.values, fields[0], ReadingOrigin.manual),
      source: _enumAt(ImportSource.values, fields[1], ImportSource.manual),
      syncedAt: _asDate(fields[2]),
      externalId: fields[3] is String ? fields[3] as String : null,
      sourceLabel: fields[4] is String ? fields[4] as String : null,
    );
  }

  @override
  void write(BinaryWriter writer, SyncInfo obj) {
    _writeFields(writer, {
      0: obj.origin.index,
      1: obj.source.index,
      2: obj.syncedAt,
      3: obj.externalId,
      4: obj.sourceLabel,
    });
  }
}

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  int get typeId => HiveTypeIds.userProfile;

  @override
  UserProfile read(BinaryReader reader) {
    final fields = _readFields(reader);
    return UserProfile(
      id: _asString(fields[0], 'me'),
      nickname: _asString(fields[1]),
      birthDate: _asDate(fields[2]),
      bloodType: _enumAt(BloodType.values, fields[3], BloodType.unknown),
      heightCm: _asDouble(fields[4]),
      referenceWeightKg: _asDouble(fields[5]),
      systolicReference: _asInt(fields[6], 120),
      diastolicReference: _asInt(fields[7], 80),
      restingPulseReference: _asInt(fields[8], 70),
      emergencyContactName: _asString(fields[9]),
      emergencyContactPhone: _asString(fields[10]),
      updatedAt: _asDate(fields[11]) ?? DateTime.now(),
      alertMarginPercent: _asInt(
        fields[12],
        UserProfile.defaultAlertMarginPercent,
      ),
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    _writeFields(writer, {
      0: obj.id,
      1: obj.nickname,
      2: obj.birthDate,
      3: obj.bloodType.index,
      4: obj.heightCm,
      5: obj.referenceWeightKg,
      6: obj.systolicReference,
      7: obj.diastolicReference,
      8: obj.restingPulseReference,
      9: obj.emergencyContactName,
      10: obj.emergencyContactPhone,
      11: obj.updatedAt,
      12: obj.alertMarginPercent,
    });
  }
}

class BloodPressureAdapter extends TypeAdapter<BloodPressureModel> {
  @override
  int get typeId => HiveTypeIds.bloodPressure;

  @override
  BloodPressureModel read(BinaryReader reader) {
    final fields = _readFields(reader);
    final sync = fields[8];
    return BloodPressureModel(
      id: _asString(fields[0]),
      systolic: fields[1] is num ? (fields[1] as num).toInt() : null,
      diastolic: fields[2] is num ? (fields[2] as num).toInt() : null,
      pulse: fields[3] is num ? (fields[3] as num).toInt() : null,
      weightKg: _asDouble(fields[4]),
      measuredAt: _asDate(fields[5]) ?? DateTime.fromMillisecondsSinceEpoch(0),
      context: _enumAt(
        MeasurementContext.values,
        fields[6],
        MeasurementContext.unspecified,
      ),
      notes: _asString(fields[7]),
      syncInfo: sync is SyncInfo ? sync : const SyncInfo.manual(),
      restingPulse: fields[9] is num ? (fields[9] as num).toInt() : null,
      oxygenSaturation: _asDouble(fields[10]),
      bodyTemperatureC: _asDouble(fields[11]),
      glucoseMgDl: _asDouble(fields[12]),
      bodyFatPercent: _asDouble(fields[13]),
      bmi: _asDouble(fields[14]),
      steps: fields[15] is num ? (fields[15] as num).toInt() : null,
      sleepMinutes: fields[16] is num ? (fields[16] as num).toInt() : null,
      hrvMs: _asDouble(fields[17]),
      feeling: _asString(fields[18]),
    );
  }

  @override
  void write(BinaryWriter writer, BloodPressureModel obj) {
    _writeFields(writer, {
      0: obj.id,
      1: obj.systolic,
      2: obj.diastolic,
      3: obj.pulse,
      4: obj.weightKg,
      5: obj.measuredAt,
      6: obj.context.index,
      7: obj.notes,
      8: obj.syncInfo,
      9: obj.restingPulse,
      10: obj.oxygenSaturation,
      11: obj.bodyTemperatureC,
      12: obj.glucoseMgDl,
      13: obj.bodyFatPercent,
      14: obj.bmi,
      15: obj.steps,
      16: obj.sleepMinutes,
      17: obj.hrvMs,
      18: obj.feeling,
    });
  }
}

class ImportPreferencesAdapter extends TypeAdapter<ImportPreferences> {
  @override
  int get typeId => HiveTypeIds.importPreferences;

  @override
  ImportPreferences read(BinaryReader reader) {
    final fields = _readFields(reader);
    final defaults = ImportPreferences.defaults();
    return ImportPreferences(
      bloodPressure: _asBool(fields[0], defaults.bloodPressure),
      pulse: _asBool(fields[1], defaults.pulse),
      restingPulse: _asBool(fields[2], defaults.restingPulse),
      oxygen: _asBool(fields[3], defaults.oxygen),
      temperature: _asBool(fields[4], defaults.temperature),
      glucose: _asBool(fields[5], defaults.glucose),
      weight: _asBool(fields[6], defaults.weight),
      bodyFat: _asBool(fields[7], defaults.bodyFat),
      bmi: _asBool(fields[8], defaults.bmi),
      steps: _asBool(fields[9], defaults.steps),
      sleep: _asBool(fields[10], defaults.sleep),
      hrv: _asBool(fields[11], defaults.hrv),
    );
  }

  @override
  void write(BinaryWriter writer, ImportPreferences obj) {
    _writeFields(writer, {
      0: obj.bloodPressure,
      1: obj.pulse,
      2: obj.restingPulse,
      3: obj.oxygen,
      4: obj.temperature,
      5: obj.glucose,
      6: obj.weight,
      7: obj.bodyFat,
      8: obj.bmi,
      9: obj.steps,
      10: obj.sleep,
      11: obj.hrv,
    });
  }
}

class ReminderConfigAdapter extends TypeAdapter<ReminderConfig> {
  @override
  int get typeId => HiveTypeIds.reminder;

  @override
  ReminderConfig read(BinaryReader reader) {
    final fields = _readFields(reader);
    final minutes = _asIntList(fields[2]);
    return ReminderConfig(
      id: _asString(fields[0], 'main'),
      frequency: _enumAt(
        ReminderFrequency.values,
        fields[1],
        ReminderFrequency.daily,
      ),
      minutesFromMidnight: minutes.isEmpty ? const [8 * 60] : minutes,
      active: _asBool(fields[3]),
    );
  }

  @override
  void write(BinaryWriter writer, ReminderConfig obj) {
    _writeFields(writer, {
      0: obj.id,
      1: obj.frequency.index,
      2: obj.minutesFromMidnight,
      3: obj.active,
    });
  }
}

class MedicationAdapter extends TypeAdapter<Medication> {
  @override
  int get typeId => HiveTypeIds.medication;

  @override
  Medication read(BinaryReader reader) {
    final fields = _readFields(reader);
    final minutes = _asIntList(fields[6]);
    return Medication(
      id: _asString(fields[0]),
      name: _asString(fields[1]),
      dose: _asString(fields[2]),
      notes: _asString(fields[3]),
      startDate: _asDate(fields[4]) ?? DateTime.now(),
      endDate: _asDate(fields[5]),
      minutesFromMidnight: minutes.isEmpty ? const [8 * 60] : minutes,
      active: _asBool(fields[7], true),
      stockRemaining: fields[8] is num ? (fields[8] as num).toInt() : null,
      reorderThreshold: fields[9] is num ? (fields[9] as num).toInt() : null,
      updatedAt: _asDate(fields[10]) ?? DateTime.now(),
      unitsPerDose: _asInt(fields[11], 1).clamp(1, 99),
      weekdays: _asIntList(fields[12]),
      doctorRequestDate: _asDate(fields[13]),
      doctorRepeat: _enumAt(
        DoctorRequestRepeat.values,
        fields[14],
        DoctorRequestRepeat.once,
      ),
      doctorRepeatEvery: _asInt(fields[15], 6).clamp(1, 60),
      doctorLeadDays: _asInt(fields[16], 0).clamp(0, 90),
    );
  }

  @override
  void write(BinaryWriter writer, Medication obj) {
    _writeFields(writer, {
      0: obj.id,
      1: obj.name,
      2: obj.dose,
      3: obj.notes,
      4: obj.startDate,
      5: obj.endDate,
      6: obj.minutesFromMidnight,
      7: obj.active,
      8: obj.stockRemaining,
      9: obj.reorderThreshold,
      10: obj.updatedAt,
      11: obj.unitsPerDose,
      12: obj.weekdays,
      13: obj.doctorRequestDate,
      14: obj.doctorRepeat.index,
      15: obj.doctorRepeatEvery,
      16: obj.doctorLeadDays,
    });
  }
}

class MedicationDoseLogAdapter extends TypeAdapter<MedicationDoseLog> {
  @override
  int get typeId => HiveTypeIds.medicationDoseLog;

  @override
  MedicationDoseLog read(BinaryReader reader) {
    final fields = _readFields(reader);
    return MedicationDoseLog(
      id: _asString(fields[0]),
      medicationId: _asString(fields[1]),
      scheduledAt: _asDate(fields[2]) ?? DateTime.now(),
      status: _enumAt(DoseStatus.values, fields[3], DoseStatus.taken),
      recordedAt: _asDate(fields[4]) ?? DateTime.now(),
      takenAt: _asDate(fields[5]),
    );
  }

  @override
  void write(BinaryWriter writer, MedicationDoseLog obj) {
    _writeFields(writer, {
      0: obj.id,
      1: obj.medicationId,
      2: obj.scheduledAt,
      3: obj.status.index,
      4: obj.recordedAt,
      5: obj.takenAt,
    });
  }
}

class MedicationPreferencesAdapter extends TypeAdapter<MedicationPreferences> {
  @override
  int get typeId => HiveTypeIds.medicationPreferences;

  @override
  MedicationPreferences read(BinaryReader reader) {
    final fields = _readFields(reader);
    final defaults = MedicationPreferences.defaults();
    return MedicationPreferences(
      trackDoses: _asBool(fields[0], defaults.trackDoses),
      trackStock: _asBool(fields[1], defaults.trackStock),
      reorderReminders: _asBool(fields[2], defaults.reorderReminders),
      showHomeButton: _asBool(fields[3], defaults.showHomeButton),
      doctorRequestReminders:
          _asBool(fields[4], defaults.doctorRequestReminders),
    );
  }

  @override
  void write(BinaryWriter writer, MedicationPreferences obj) {
    _writeFields(writer, {
      0: obj.trackDoses,
      1: obj.trackStock,
      2: obj.reorderReminders,
      3: obj.showHomeButton,
      4: obj.doctorRequestReminders,
    });
  }
}

class AppLockConfigAdapter extends TypeAdapter<AppLockConfig> {
  @override
  int get typeId => HiveTypeIds.appLock;

  @override
  AppLockConfig read(BinaryReader reader) {
    final fields = _readFields(reader);
    return AppLockConfig(
      enabled: _asBool(fields[0]),
      pinHash: _asString(fields[1]),
      useBiometrics: _asBool(fields[2]),
    );
  }

  @override
  void write(BinaryWriter writer, AppLockConfig obj) {
    _writeFields(writer, {
      0: obj.enabled,
      1: obj.pinHash,
      2: obj.useBiometrics,
    });
  }
}
