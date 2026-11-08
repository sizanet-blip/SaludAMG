/// Cajas cifradas (AES). Las antiguas sin cifrar (`legacy*`) se migran y se
/// borran al arrancar (ver `hive_setup.dart`).
abstract final class HiveBoxes {
  static const profile = 'profile_e';
  static const readings = 'readings_e';
  static const reminders = 'reminders_e';
  static const importPrefs = 'import_prefs_e';
  static const medications = 'medications_e';
  static const medicationDoseLogs = 'medication_dose_logs_e';
  static const medicationPrefs = 'medication_prefs_e';
  static const appLock = 'app_lock_e';

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
