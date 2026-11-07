import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/entities/blood_pressure_model.dart';
import '../domain/entities/import_preferences.dart';
import '../domain/entities/medication.dart';
import '../domain/entities/medication_dose_log.dart';
import '../domain/entities/medication_preferences.dart';
import '../domain/entities/reminder_config.dart';
import '../domain/entities/sync_info.dart';
import '../domain/entities/user_profile.dart';
import '../domain/enums/health_enums.dart';
import '../domain/repositories/repositories.dart';

/// Copia de seguridad JSON local (exportar / restaurar), opcionalmente cifrada.
class BackupService {
  const BackupService({
    required this.profiles,
    required this.measurements,
    required this.reminders,
    required this.importPreferences,
    required this.medications,
    required this.medicationDoseLogs,
    required this.medicationPreferences,
  });

  final ProfileRepository profiles;
  final MeasurementRepository measurements;
  final ReminderRepository reminders;
  final ImportPreferencesRepository importPreferences;
  final MedicationRepository medications;
  final MedicationDoseLogRepository medicationDoseLogs;
  final MedicationPreferencesRepository medicationPreferences;

  /// [password] vacío = JSON en claro. Con contraseña = AES-256 cifrado.
  Future<void> exportBackup({String password = ''}) async {
    final payload = {
      'version': 1,
      'app': 'SaludAMG',
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': _profileToJson(profiles.current()),
      'readings': [
        for (final reading in measurements.getAll()) _readingToJson(reading),
      ],
      'reminders': _reminderToJson(reminders.current()),
      'importPreferences': _importPrefsToJson(importPreferences.current()),
      'medications': [
        for (final med in medications.getAll()) med.toJson(),
      ],
      'doseLogs': [
        for (final log in medicationDoseLogs.getAll()) log.toJson(),
      ],
      'medicationPreferences': medicationPreferences.current().toJson(),
    };

    final plain = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .split('.')
        .first;
    final directory = await getTemporaryDirectory();
    late final List<int> bytes;
    late final String name;
    late final String mime;

    if (password.trim().isEmpty) {
      bytes = plain;
      name = 'saludamg_backup_$stamp.json';
      mime = 'application/json';
    } else {
      final envelope = await _encryptPayload(plain, password.trim());
      bytes = utf8.encode(jsonEncode(envelope));
      name = 'saludamg_backup_$stamp.saludamg.json';
      mime = 'application/json';
    }

    final file = File('${directory.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mime)],
        subject: 'Copia de seguridad SaludAMG',
        text: password.trim().isEmpty
            ? 'Respaldo local de ficha, mediciones y medicaciones.'
            : 'Respaldo cifrado de SaludAMG. Necesitas la contraseña para abrirlo.',
      ),
    );
  }

  /// Restaura desde un JSON. Si está cifrado, [password] es obligatoria.
  Future<String> restoreFromPicker({String password = ''}) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty) {
      return 'Restauración cancelada.';
    }
    final file = files.first;
    final raw = await file.readAsBytes();
    final decoded = jsonDecode(utf8.decode(raw));
    if (decoded is! Map<String, dynamic>) {
      throw StateError('El archivo no es una copia válida.');
    }

    Map<String, dynamic> payload;
    if (decoded['encrypted'] == true) {
      if (password.trim().isEmpty) {
        throw StateError('Esta copia está cifrada. Introduce la contraseña.');
      }
      payload = await _decryptPayload(decoded, password.trim());
    } else {
      payload = decoded;
    }
    return restoreFromMap(payload);
  }

  Future<Map<String, dynamic>> _encryptPayload(
    List<int> plain,
    String password,
  ) async {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final key = enc.Key(await _deriveKeyAsync(password, salt));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = enc.Encrypter(enc.AES(key)).encryptBytes(plain, iv: iv);
    return {
      'encrypted': true,
      'app': 'SaludAMG',
      'alg': 'AES-256-CBC',
      'salt': base64Encode(salt),
      'iv': iv.base64,
      'data': encrypted.base64,
    };
  }

  Future<Map<String, dynamic>> _decryptPayload(
    Map<String, dynamic> envelope,
    String password,
  ) async {
    try {
      final salt = base64Decode(envelope['salt'] as String);
      final iv = enc.IV.fromBase64(envelope['iv'] as String);
      final key = enc.Key(await _deriveKeyAsync(password, salt));
      final decrypted = enc.Encrypter(enc.AES(key)).decryptBytes(
        enc.Encrypted.fromBase64(envelope['data'] as String),
        iv: iv,
      );
      final payload = jsonDecode(utf8.decode(decrypted));
      if (payload is! Map<String, dynamic>) {
        throw StateError('Contenido inválido.');
      }
      return payload;
    } catch (_) {
      throw StateError('Contraseña incorrecta o archivo dañado.');
    }
  }

  Future<Uint8List> _deriveKeyAsync(String password, List<int> salt) {
    return compute(_deriveKeyIsolate, <String, Object>{
      'password': password,
      'salt': salt,
    });
  }

  Future<String> restoreFromMap(Map<String, dynamic> payload) async {
    if (payload['app'] != null && payload['app'] != 'SaludAMG') {
      throw StateError('El archivo no es de SaludAMG.');
    }

    final profileMap = payload['profile'];
    if (profileMap is Map<String, dynamic>) {
      await profiles.save(_profileFromJson(profileMap));
    }

    // Listas: si la clave existe (aunque vacía), reemplaza por completo.
    if (payload.containsKey('readings')) {
      for (final existing in measurements.getAll()) {
        await measurements.delete(existing.id);
      }
      final readingsRaw = payload['readings'];
      if (readingsRaw is List) {
        for (final item in readingsRaw) {
          if (item is Map<String, dynamic>) {
            await measurements.save(_readingFromJson(item));
          }
        }
      }
    }

    final remindersMap = payload['reminders'];
    if (remindersMap is Map<String, dynamic>) {
      await reminders.save(_reminderFromJson(remindersMap));
    }

    final importMap = payload['importPreferences'];
    if (importMap is Map<String, dynamic>) {
      await importPreferences.save(_importPrefsFromJson(importMap));
    }

    if (payload.containsKey('medications')) {
      for (final existing in medications.getAll()) {
        await medications.delete(existing.id);
      }
      final medsRaw = payload['medications'];
      if (medsRaw is List) {
        for (final item in medsRaw) {
          if (item is Map<String, dynamic>) {
            await medications.save(Medication.fromJson(item));
          }
        }
      }
    }

    if (payload.containsKey('doseLogs')) {
      for (final existing in medicationDoseLogs.getAll()) {
        await medicationDoseLogs.delete(existing.id);
      }
      final logsRaw = payload['doseLogs'];
      if (logsRaw is List) {
        for (final item in logsRaw) {
          if (item is Map<String, dynamic>) {
            await medicationDoseLogs.save(MedicationDoseLog.fromJson(item));
          }
        }
      }
    }

    final medPrefs = payload['medicationPreferences'];
    if (medPrefs is Map<String, dynamic>) {
      await medicationPreferences.save(MedicationPreferences.fromJson(medPrefs));
    }

    final readingCount = measurements.getAll().length;
    final medCount = medications.getAll().length;
    return 'Restaurado: $readingCount mediciones, $medCount medicaciones.';
  }

  Map<String, dynamic> _profileToJson(UserProfile p) => {
        'id': p.id,
        'nickname': p.nickname,
        'birthDate': p.birthDate?.toIso8601String(),
        'bloodType': p.bloodType.index,
        'heightCm': p.heightCm,
        'referenceWeightKg': p.referenceWeightKg,
        'systolicReference': p.systolicReference,
        'diastolicReference': p.diastolicReference,
        'restingPulseReference': p.restingPulseReference,
        'alertMarginPercent': p.alertMarginPercent,
        'emergencyContactName': p.emergencyContactName,
        'emergencyContactPhone': p.emergencyContactPhone,
        'updatedAt': p.updatedAt.toIso8601String(),
      };

  UserProfile _profileFromJson(Map<String, dynamic> json) {
    final typeIndex = (json['bloodType'] as num?)?.toInt() ?? 0;
    return UserProfile(
      id: json['id'] as String? ?? UserProfile.storageKey,
      nickname: json['nickname'] as String? ?? '',
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.tryParse(json['birthDate'] as String),
      bloodType: typeIndex >= 0 && typeIndex < BloodType.values.length
          ? BloodType.values[typeIndex]
          : BloodType.unknown,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      referenceWeightKg: (json['referenceWeightKg'] as num?)?.toDouble(),
      systolicReference: (json['systolicReference'] as num?)?.toInt() ?? 120,
      diastolicReference: (json['diastolicReference'] as num?)?.toInt() ?? 80,
      restingPulseReference:
          (json['restingPulseReference'] as num?)?.toInt() ?? 70,
      alertMarginPercent: (json['alertMarginPercent'] as num?)?.toInt() ??
          UserProfile.defaultAlertMarginPercent,
      emergencyContactName: json['emergencyContactName'] as String? ?? '',
      emergencyContactPhone: json['emergencyContactPhone'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> _readingToJson(BloodPressureModel r) => {
        'id': r.id,
        'systolic': r.systolic,
        'diastolic': r.diastolic,
        'pulse': r.pulse,
        'restingPulse': r.restingPulse,
        'oxygenSaturation': r.oxygenSaturation,
        'bodyTemperatureC': r.bodyTemperatureC,
        'glucoseMgDl': r.glucoseMgDl,
        'weightKg': r.weightKg,
        'bodyFatPercent': r.bodyFatPercent,
        'bmi': r.bmi,
        'steps': r.steps,
        'sleepMinutes': r.sleepMinutes,
        'hrvMs': r.hrvMs,
        'measuredAt': r.measuredAt.toIso8601String(),
        'context': r.context.index,
        'notes': r.notes,
        'feeling': r.feeling,
        'syncInfo': {
          'origin': r.syncInfo.origin.index,
          'source': r.syncInfo.source.index,
          'syncedAt': r.syncInfo.syncedAt?.toIso8601String(),
          'externalId': r.syncInfo.externalId,
          'sourceLabel': r.syncInfo.sourceLabel,
        },
      };

  BloodPressureModel _readingFromJson(Map<String, dynamic> json) {
    final sync = json['syncInfo'];
    final syncMap = sync is Map<String, dynamic> ? sync : <String, dynamic>{};
    final originIndex = (syncMap['origin'] as num?)?.toInt() ?? 0;
    final sourceIndex = (syncMap['source'] as num?)?.toInt() ?? 0;
    final contextIndex = (json['context'] as num?)?.toInt() ?? 0;
    return BloodPressureModel(
      id: json['id'] as String? ?? '',
      systolic: (json['systolic'] as num?)?.toInt(),
      diastolic: (json['diastolic'] as num?)?.toInt(),
      pulse: (json['pulse'] as num?)?.toInt(),
      restingPulse: (json['restingPulse'] as num?)?.toInt(),
      oxygenSaturation: (json['oxygenSaturation'] as num?)?.toDouble(),
      bodyTemperatureC: (json['bodyTemperatureC'] as num?)?.toDouble(),
      glucoseMgDl: (json['glucoseMgDl'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble(),
      bmi: (json['bmi'] as num?)?.toDouble(),
      steps: (json['steps'] as num?)?.toInt(),
      sleepMinutes: (json['sleepMinutes'] as num?)?.toInt(),
      hrvMs: (json['hrvMs'] as num?)?.toDouble(),
      measuredAt: DateTime.tryParse(json['measuredAt'] as String? ?? '') ??
          DateTime.now(),
      context: contextIndex >= 0 && contextIndex < MeasurementContext.values.length
          ? MeasurementContext.values[contextIndex]
          : MeasurementContext.unspecified,
      notes: json['notes'] as String? ?? '',
      feeling: json['feeling'] as String? ?? '',
      syncInfo: SyncInfo(
        origin: originIndex >= 0 && originIndex < ReadingOrigin.values.length
            ? ReadingOrigin.values[originIndex]
            : ReadingOrigin.manual,
        source: sourceIndex >= 0 && sourceIndex < ImportSource.values.length
            ? ImportSource.values[sourceIndex]
            : ImportSource.manual,
        syncedAt: syncMap['syncedAt'] == null
            ? null
            : DateTime.tryParse(syncMap['syncedAt'] as String),
        externalId: syncMap['externalId'] as String?,
        sourceLabel: syncMap['sourceLabel'] as String?,
      ),
    );
  }

  Map<String, dynamic> _reminderToJson(ReminderConfig c) => {
        'id': c.id,
        'frequency': c.frequency.index,
        'minutesFromMidnight': c.minutesFromMidnight,
        'active': c.active,
      };

  ReminderConfig _reminderFromJson(Map<String, dynamic> json) {
    final freq = (json['frequency'] as num?)?.toInt() ?? 0;
    final minutes = json['minutesFromMidnight'];
    return ReminderConfig(
      id: json['id'] as String? ?? ReminderConfig.storageKey,
      frequency: freq >= 0 && freq < ReminderFrequency.values.length
          ? ReminderFrequency.values[freq]
          : ReminderFrequency.daily,
      minutesFromMidnight: minutes is List
          ? [for (final m in minutes) if (m is num) m.toInt()]
          : const [8 * 60],
      active: json['active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _importPrefsToJson(ImportPreferences p) => {
        'bloodPressure': p.bloodPressure,
        'pulse': p.pulse,
        'restingPulse': p.restingPulse,
        'oxygen': p.oxygen,
        'temperature': p.temperature,
        'glucose': p.glucose,
        'weight': p.weight,
        'bodyFat': p.bodyFat,
        'bmi': p.bmi,
        'steps': p.steps,
        'sleep': p.sleep,
        'hrv': p.hrv,
      };

  ImportPreferences _importPrefsFromJson(Map<String, dynamic> json) {
    final d = ImportPreferences.defaults();
    return ImportPreferences(
      bloodPressure: json['bloodPressure'] as bool? ?? d.bloodPressure,
      pulse: json['pulse'] as bool? ?? d.pulse,
      restingPulse: json['restingPulse'] as bool? ?? d.restingPulse,
      oxygen: json['oxygen'] as bool? ?? d.oxygen,
      temperature: json['temperature'] as bool? ?? d.temperature,
      glucose: json['glucose'] as bool? ?? d.glucose,
      weight: json['weight'] as bool? ?? d.weight,
      bodyFat: json['bodyFat'] as bool? ?? d.bodyFat,
      bmi: json['bmi'] as bool? ?? d.bmi,
      steps: json['steps'] as bool? ?? d.steps,
      sleep: json['sleep'] as bool? ?? d.sleep,
      hrv: json['hrv'] as bool? ?? d.hrv,
    );
  }
}

/// KDF en isolate para no congelar la UI (120k × SHA-256).
Uint8List _deriveKeyIsolate(Map<String, Object> args) {
  final password = args['password'] as String;
  final salt = (args['salt'] as List).cast<int>();
  var block = utf8.encode(password) + salt;
  for (var i = 0; i < 120000; i++) {
    block = sha256.convert(block).bytes;
  }
  return Uint8List.fromList(block);
}
