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

Future<void> initHive() async {
  await Hive.initFlutter();
  registerHiveAdapters();
  final cipher = HiveAesCipher(await _loadOrCreateKey());

  await openEncryptedBox<UserProfile>(
    HiveBoxes.profile,
    HiveBoxes.legacyProfile,
    cipher,
  );
  await openEncryptedBox<BloodPressureModel>(
    HiveBoxes.readings,
    HiveBoxes.legacyReadings,
    cipher,
  );
  await openEncryptedBox<ReminderConfig>(
    HiveBoxes.reminders,
    HiveBoxes.legacyReminders,
    cipher,
  );
  await openEncryptedBox<ImportPreferences>(
    HiveBoxes.importPrefs,
    HiveBoxes.legacyImportPrefs,
    cipher,
  );
  await openEncryptedBox<Medication>(
    HiveBoxes.medications,
    HiveBoxes.legacyMedications,
    cipher,
  );
  await openEncryptedBox<MedicationDoseLog>(
    HiveBoxes.medicationDoseLogs,
    HiveBoxes.legacyMedicationDoseLogs,
    cipher,
  );
  await openEncryptedBox<MedicationPreferences>(
    HiveBoxes.medicationPrefs,
    HiveBoxes.legacyMedicationPrefs,
    cipher,
  );
  await openEncryptedBox<AppLockConfig>(
    HiveBoxes.appLock,
    HiveBoxes.legacyAppLock,
    cipher,
  );
}

Future<List<int>> _loadOrCreateKey() async {
  const storage = FlutterSecureStorage();
  final stored = await storage.read(key: _kHiveKey);
  if (stored != null && stored.isNotEmpty) return base64Decode(stored);
  final key = Hive.generateSecureKey();
  await storage.write(key: _kHiveKey, value: base64Encode(key));
  return key;
}

/// Abre la caja cifrada. Si aún existe la caja antigua sin cifrar (versiones
/// anteriores), copia su contenido y solo entonces la borra. Si se corta a
/// mitad, la próxima vez se repite (las claves son las mismas, no duplica).
@visibleForTesting
Future<void> openEncryptedBox<T>(
  String name,
  String legacyName,
  HiveCipher cipher,
) async {
  final box = await Hive.openBox<T>(name, encryptionCipher: cipher);
  if (!await Hive.boxExists(legacyName)) return;
  try {
    final legacy = await Hive.openBox<T>(legacyName);
    await box.putAll(Map<dynamic, T>.from(legacy.toMap()));
    await box.flush();
    await legacy.deleteFromDisk();
  } catch (error, stack) {
    // No se borra la antigua: se reintenta en el siguiente arranque.
    debugPrint('No se pudo migrar $legacyName: $error\n$stack');
  }
}
