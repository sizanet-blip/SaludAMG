import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Nombres de las cajas de datos.
///
/// Cada cuenta AMG tiene las suyas (sufijo con un resumen del usuario, sin el
/// nombre en claro). Están cifradas (AES). Las antiguas se migran al arrancar
/// o al entrar (ver `hive_setup.dart`):
/// sin cifrar (`legacy*`) → cifradas sin dueño (`*_e`) → de la cuenta.
abstract final class HiveBoxes {
  static var _owner = '';

  /// Sufijo de la cuenta activa ('' sin cuenta, p. ej. compilación sin panel).
  static String get ownerSuffix => _owner;

  static String suffixFor(String? username) {
    final user = username?.trim().toLowerCase() ?? '';
    if (user.isEmpty) return '';
    final digest = sha256.convert(utf8.encode('saludamg|$user')).toString();
    return '_${digest.substring(0, 16)}';
  }

  static void setOwner(String? username) => _owner = suffixFor(username);

  static String get profile => '$sharedProfile$_owner';
  static String get readings => '$sharedReadings$_owner';
  static String get reminders => '$sharedReminders$_owner';
  static String get importPrefs => '$sharedImportPrefs$_owner';
  static String get medications => '$sharedMedications$_owner';
  static String get medicationDoseLogs => '$sharedMedicationDoseLogs$_owner';
  static String get medicationPrefs => '$sharedMedicationPrefs$_owner';
  static String get appLock => '$sharedAppLock$_owner';

  /// Cifradas, de antes de separar por cuenta.
  static const sharedProfile = 'profile_e';
  static const sharedReadings = 'readings_e';
  static const sharedReminders = 'reminders_e';
  static const sharedImportPrefs = 'import_prefs_e';
  static const sharedMedications = 'medications_e';
  static const sharedMedicationDoseLogs = 'medication_dose_logs_e';
  static const sharedMedicationPrefs = 'medication_prefs_e';
  static const sharedAppLock = 'app_lock_e';

  /// Sin cifrar, de las primeras versiones.
  static const legacyProfile = 'profile';
  static const legacyReadings = 'readings';
  static const legacyReminders = 'reminders';
  static const legacyImportPrefs = 'import_prefs';
  static const legacyMedications = 'medications';
  static const legacyMedicationDoseLogs = 'medication_dose_logs';
  static const legacyMedicationPrefs = 'medication_prefs';
  static const legacyAppLock = 'app_lock';
}

/// Identificadores de adaptador. No reutilizar un número ya publicado.
abstract final class HiveTypeIds {
  static const syncInfo = 1;
  static const userProfile = 2;
  static const bloodPressure = 3;
  static const reminder = 4;
  static const importPreferences = 5;
  static const medication = 6;
  static const medicationDoseLog = 7;
  static const medicationPreferences = 8;
  static const appLock = 9;
}
