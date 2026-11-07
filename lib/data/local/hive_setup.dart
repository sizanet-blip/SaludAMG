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

Future<void> initHive() async {
  await Hive.initFlutter();
  registerHiveAdapters();
  await Hive.openBox<UserProfile>(HiveBoxes.profile);
  await Hive.openBox<BloodPressureModel>(HiveBoxes.readings);
  await Hive.openBox<ReminderConfig>(HiveBoxes.reminders);
  await Hive.openBox<ImportPreferences>(HiveBoxes.importPrefs);
  await Hive.openBox<Medication>(HiveBoxes.medications);
  await Hive.openBox<MedicationDoseLog>(HiveBoxes.medicationDoseLogs);
  await Hive.openBox<MedicationPreferences>(HiveBoxes.medicationPrefs);
  await Hive.openBox<AppLockConfig>(HiveBoxes.appLock);
}
