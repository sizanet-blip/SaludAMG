import '../entities/app_lock_config.dart';
import '../entities/blood_pressure_model.dart';
import '../entities/import_preferences.dart';
import '../entities/medication.dart';
import '../entities/medication_dose_log.dart';
import '../entities/medication_preferences.dart';
import '../entities/reminder_config.dart';
import '../entities/user_profile.dart';

abstract class ProfileRepository {
  UserProfile current();
  Future<void> save(UserProfile profile);
}

abstract class MeasurementRepository {
  List<BloodPressureModel> getAll();
  Future<void> save(BloodPressureModel reading);
  Future<void> delete(String id);

  /// Guarda importaciones nuevas. Devuelve cuántas se añadieron de verdad.
  Future<int> saveImported(List<BloodPressureModel> readings);
}

abstract class ReminderRepository {
  ReminderConfig current();
  Future<void> save(ReminderConfig config);
}

abstract class ImportPreferencesRepository {
  ImportPreferences current();
  Future<void> save(ImportPreferences preferences);
}

abstract class MedicationRepository {
  List<Medication> getAll();
  Medication? getById(String id);
  Future<void> save(Medication medication);
  Future<void> delete(String id);
}

abstract class MedicationDoseLogRepository {
  List<MedicationDoseLog> getAll();
  List<MedicationDoseLog> forMedicationOnDay(String medicationId, DateTime day);
  List<MedicationDoseLog> forMedicationInRange(
    String medicationId,
    DateTime start,
    DateTime end,
  );
  MedicationDoseLog? findForSlot(String medicationId, DateTime scheduledAt);
  Future<void> save(MedicationDoseLog log);
  Future<void> delete(String id);
  Future<int> deleteForMedication(String medicationId);
}

abstract class MedicationPreferencesRepository {
  MedicationPreferences current();
  Future<void> save(MedicationPreferences preferences);
}

abstract class AppLockRepository {
  AppLockConfig current();
  Future<void> save(AppLockConfig config);
}
