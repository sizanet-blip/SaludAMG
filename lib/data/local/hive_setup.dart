import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/app_lock_config.dart';
import '../../domain/entities/blood_pressure_model.dart';
import '../../domain/entities/import_preferences.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_dose_log.dart';
import '../../domain/entities/medication_preferences.dart';
import '../../domain/entities/reminder_config.dart';
import '../../domain/entities/user_profile.dart';
import 'hive_adapters.dart';
import 'hive_boxes.dart';

/// Clave AES de las cajas, guardada en el almacén seguro del sistema
/// (Android Keystore / Keychain de iOS). No sale del teléfono ni va en copias.
const _kHiveKey = 'saludamg_hive_key_v1';

HiveCipher? _cipher;

/// Arranque: abre los datos de [username] (la última cuenta que entró).
Future<void> initHive({String? username}) async {
  await Hive.initFlutter();
  registerHiveAdapters();
  _cipher = HiveAesCipher(await _loadOrCreateKey());
  await openDataBoxes(username);
}

/// Abre las cajas de la cuenta [username] y cierra las de la anterior.
/// Los datos de antes de separar por cuenta pasan a la primera cuenta que
/// las abre (en la práctica, quien ya usaba la app en este teléfono).
Future<void> openDataBoxes(String? username, {HiveCipher? cipher}) async {
  final key = cipher ?? _cipher;
  if (key == null) throw StateError('initHive() no se ha llamado');
  final previous = HiveBoxes.ownerSuffix;
  HiveBoxes.setOwner(username);
  if (previous != HiveBoxes.ownerSuffix) {
    await _closeOwnerBoxes(previous);
  }

  await openEncryptedBox<UserProfile>(
    HiveBoxes.profile,
    legacyName: HiveBoxes.legacyProfile,
    sharedName: HiveBoxes.sharedProfile,
    cipher: key,
  );
  await openEncryptedBox<BloodPressureModel>(
    HiveBoxes.readings,
    legacyName: HiveBoxes.legacyReadings,
    sharedName: HiveBoxes.sharedReadings,
    cipher: key,
  );
  await openEncryptedBox<ReminderConfig>(
    HiveBoxes.reminders,
    legacyName: HiveBoxes.legacyReminders,
    sharedName: HiveBoxes.sharedReminders,
    cipher: key,
  );
  await openEncryptedBox<ImportPreferences>(
    HiveBoxes.importPrefs,
    legacyName: HiveBoxes.legacyImportPrefs,
    sharedName: HiveBoxes.sharedImportPrefs,
    cipher: key,
  );
  await openEncryptedBox<Medication>(
    HiveBoxes.medications,
    legacyName: HiveBoxes.legacyMedications,
    sharedName: HiveBoxes.sharedMedications,
    cipher: key,
  );
  await openEncryptedBox<MedicationDoseLog>(
    HiveBoxes.medicationDoseLogs,
    legacyName: HiveBoxes.legacyMedicationDoseLogs,
    sharedName: HiveBoxes.sharedMedicationDoseLogs,
    cipher: key,
  );
  await openEncryptedBox<MedicationPreferences>(
    HiveBoxes.medicationPrefs,
    legacyName: HiveBoxes.legacyMedicationPrefs,
    sharedName: HiveBoxes.sharedMedicationPrefs,
    cipher: key,
  );
  await openEncryptedBox<AppLockConfig>(
    HiveBoxes.appLock,
    legacyName: HiveBoxes.legacyAppLock,
    sharedName: HiveBoxes.sharedAppLock,
    cipher: key,
  );
}

Future<void> _closeOwnerBoxes(String suffix) async {
  Future<void> close<T>(String base) async {
    final name = '$base$suffix';
    if (Hive.isBoxOpen(name)) await Hive.box<T>(name).close();
  }

  await close<UserProfile>(HiveBoxes.sharedProfile);
  await close<BloodPressureModel>(HiveBoxes.sharedReadings);
  await close<ReminderConfig>(HiveBoxes.sharedReminders);
  await close<ImportPreferences>(HiveBoxes.sharedImportPrefs);
  await close<Medication>(HiveBoxes.sharedMedications);
  await close<MedicationDoseLog>(HiveBoxes.sharedMedicationDoseLogs);
  await close<MedicationPreferences>(HiveBoxes.sharedMedicationPrefs);
  await close<AppLockConfig>(HiveBoxes.sharedAppLock);
}

Future<List<int>> _loadOrCreateKey() async {
  const storage = FlutterSecureStorage();
  final stored = await storage.read(key: _kHiveKey);
  if (stored != null && stored.isNotEmpty) return base64Decode(stored);
  final key = Hive.generateSecureKey();
  await storage.write(key: _kHiveKey, value: base64Encode(key));
  return key;
}

/// Abre la caja cifrada [name]. Si quedan cajas de versiones anteriores
/// (sin cifrar, o cifradas sin dueño), copia su contenido y solo entonces las
/// borra. Si se corta a mitad, la próxima vez se repite (mismas claves, no
/// duplica).
@visibleForTesting
Future<void> openEncryptedBox<T>(
  String name, {
  required String legacyName,
  required String sharedName,
  required HiveCipher cipher,
}) async {
  final box = Hive.isBoxOpen(name)
      ? Hive.box<T>(name)
      : await Hive.openBox<T>(name, encryptionCipher: cipher);
  await _migrateInto(box, legacyName, null);
  if (sharedName != name) await _migrateInto(box, sharedName, cipher);
}

Future<void> _migrateInto<T>(
  Box<T> target,
  String sourceName,
  HiveCipher? sourceCipher,
) async {
  if (!await Hive.boxExists(sourceName)) return;
  try {
    final source = Hive.isBoxOpen(sourceName)
        ? Hive.box<T>(sourceName)
        : await Hive.openBox<T>(sourceName, encryptionCipher: sourceCipher);
    if (target.isEmpty) {
      await target.putAll(Map<dynamic, T>.from(source.toMap()));
    } else {
      // Si ya hay datos de la cuenta, lo de origen no los pisa.
      for (final entry in source.toMap().entries) {
        if (!target.containsKey(entry.key)) {
          await target.put(entry.key, entry.value);
        }
      }
    }
    await target.flush();
    await source.deleteFromDisk();
  } catch (error, stack) {
    // No se borra el origen: se reintenta en el siguiente arranque.
    debugPrint('No se pudo migrar $sourceName: $error\n$stack');
  }
}
