abstract final class HiveBoxes {
  static const profile = 'profile';
  static const readings = 'readings';
  static const reminders = 'reminders';
  static const importPrefs = 'import_prefs';
  static const medications = 'medications';
  static const medicationDoseLogs = 'medication_dose_logs';
  static const medicationPrefs = 'medication_prefs';
  static const appLock = 'app_lock';
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
