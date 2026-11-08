import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salud_amg/app.dart';
import 'package:salud_amg/app_scope.dart';
import 'package:salud_amg/domain/entities/app_lock_config.dart';
import 'package:salud_amg/domain/entities/blood_pressure_model.dart';
import 'package:salud_amg/domain/entities/import_preferences.dart';
import 'package:salud_amg/domain/entities/medication.dart';
import 'package:salud_amg/domain/entities/medication_dose_log.dart';
import 'package:salud_amg/domain/entities/medication_preferences.dart';
import 'package:salud_amg/domain/entities/reminder_config.dart';
import 'package:salud_amg/domain/entities/sync_info.dart';
import 'package:salud_amg/domain/enums/health_enums.dart';
import 'package:salud_amg/domain/entities/user_profile.dart';
import 'package:salud_amg/domain/repositories/repositories.dart';
import 'package:salud_amg/presentation/screens/measurement_form_screen.dart';
import 'package:salud_amg/services/app_lock_service.dart';
import 'package:salud_amg/services/backup_service.dart';
import 'package:salud_amg/services/export_service.dart';
import 'package:salud_amg/services/notification_service.dart';

class _MemoryProfiles implements ProfileRepository {
  UserProfile _profile = UserProfile.defaults();

  @override
  UserProfile current() => _profile;

  @override
  Future<void> save(UserProfile profile) async => _profile = profile;
}

class _MemoryMeasurements implements MeasurementRepository {
  final List<BloodPressureModel> _items = [];

  @override
  List<BloodPressureModel> getAll() => List.unmodifiable(_items);

  @override
  Future<void> save(BloodPressureModel reading) async {
    _items.removeWhere((item) => item.id == reading.id);
    _items.add(reading);
  }

  @override
  Future<void> delete(String id) async => _items.removeWhere((item) => item.id == id);

  @override
  Future<int> saveImported(List<BloodPressureModel> readings) async {
    for (final reading in readings) {
      await save(reading);
    }
    return readings.length;
  }
}

class _MemoryReminders implements ReminderRepository {
  ReminderConfig _config = ReminderConfig.defaults();

  @override
  ReminderConfig current() => _config;

  @override
  Future<void> save(ReminderConfig config) async => _config = config;
}

class _MemoryImportPrefs implements ImportPreferencesRepository {
  ImportPreferences _prefs = ImportPreferences.defaults();

  @override
  ImportPreferences current() => _prefs;

  @override
  Future<void> save(ImportPreferences preferences) async => _prefs = preferences;
}

class _MemoryMedications implements MedicationRepository {
  final List<Medication> _items = [];

  @override
  List<Medication> getAll() => List.unmodifiable(_items);

  @override
  Medication? getById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<void> save(Medication medication) async {
    _items.removeWhere((item) => item.id == medication.id);
    _items.add(medication);
  }

  @override
  Future<void> delete(String id) async =>
      _items.removeWhere((item) => item.id == id);
}

class _MemoryDoseLogs implements MedicationDoseLogRepository {
  final List<MedicationDoseLog> _items = [];

  @override
  List<MedicationDoseLog> getAll() => List.unmodifiable(_items);

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
    return _items
        .where(
          (log) =>
              log.medicationId == medicationId &&
              !log.scheduledAt.isBefore(start) &&
              log.scheduledAt.isBefore(end),
        )
        .toList();
  }

  @override
  MedicationDoseLog? findForSlot(String medicationId, DateTime scheduledAt) {
    final key = scheduledAt.millisecondsSinceEpoch;
    for (final log in _items) {
      if (log.medicationId == medicationId &&
          log.scheduledAt.millisecondsSinceEpoch == key) {
        return log;
      }
    }
    return null;
  }

  @override
  Future<void> save(MedicationDoseLog log) async {
    _items.removeWhere((item) => item.id == log.id);
    _items.add(log);
  }

  @override
  Future<void> delete(String id) async =>
      _items.removeWhere((item) => item.id == id);

  @override
  Future<int> deleteForMedication(String medicationId) async {
    final before = _items.length;
    _items.removeWhere((item) => item.medicationId == medicationId);
    return before - _items.length;
  }
}

class _MemoryMedPrefs implements MedicationPreferencesRepository {
  MedicationPreferences _prefs = MedicationPreferences.defaults();

  @override
  MedicationPreferences current() => _prefs;

  @override
  Future<void> save(MedicationPreferences preferences) async =>
      _prefs = preferences;
}

class _MemoryAppLock implements AppLockRepository {
  AppLockConfig _config = AppLockConfig.defaults();

  @override
  AppLockConfig current() => _config;

  @override
  Future<void> save(AppLockConfig config) async => _config = config;
}

void main() {
  testWidgets('el resumen vacío muestra el CTA de medición', (tester) async {
    final profiles = _MemoryProfiles();
    final measurements = _MemoryMeasurements();
    final reminders = _MemoryReminders();
    final importPreferences = _MemoryImportPrefs();
    final medications = _MemoryMedications();
    final doseLogs = _MemoryDoseLogs();
    final medPrefs = _MemoryMedPrefs();
    await tester.pumpWidget(
      SaludAmgApp(
        dependencies: AppDependencies(
          profiles: profiles,
          measurements: measurements,
          reminders: reminders,
          importPreferences: importPreferences,
          medications: medications,
          medicationDoseLogs: doseLogs,
          medicationPreferences: medPrefs,
          appLock: AppLockService(_MemoryAppLock()),
          healthSync: null,
          notifications: NotificationService(),
          exports: ExportService(),
          backup: BackupService(
            profiles: profiles,
            measurements: measurements,
            reminders: reminders,
            importPreferences: importPreferences,
            medications: medications,
            medicationDoseLogs: doseLogs,
            medicationPreferences: medPrefs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // La pantalla de inicio es un menú: el aviso está dentro de Resumen.
    await tester.tap(find.text('Resumen'));
    await tester.pumpAndSettle();
    expect(find.text('Añadir medición'), findsOneWidget);
  });

  group('copia cifrada', () {
    BackupService service() => BackupService(
          profiles: _MemoryProfiles(),
          measurements: _MemoryMeasurements(),
          reminders: _MemoryReminders(),
          importPreferences: _MemoryImportPrefs(),
          medications: _MemoryMedications(),
          medicationDoseLogs: _MemoryDoseLogs(),
          medicationPreferences: _MemoryMedPrefs(),
        );
    final plain = utf8.encode('{"app":"SaludAMG","readings":[]}');

    test('se abre con la contraseña correcta', () async {
      final envelope = await service().encryptPayload(plain, 'clave-1');
      expect(envelope['mac'], isNotNull);
      final back = await service().decryptPayload(envelope, 'clave-1');
      expect(back['app'], 'SaludAMG');
    });

    test('si alguien la modifica, no se acepta', () async {
      final envelope = await service().encryptPayload(plain, 'clave-1');
      final data = base64Decode(envelope['data'] as String);
      data[0] ^= 1;
      envelope['data'] = base64Encode(data);
      await expectLater(
        service().decryptPayload(envelope, 'clave-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('contraseña incorrecta', () async {
      final envelope = await service().encryptPayload(plain, 'clave-1');
      await expectLater(
        service().decryptPayload(envelope, 'otra'),
        throwsA(isA<StateError>()),
      );
    });
  });

  test('PIN con sal propia; el formato antiguo sigue valiendo y se actualiza',
      () async {
    final repo = _MemoryAppLock();
    final lock = AppLockService(repo);
    final a = AppLockService.hashPin('2580');
    final b = AppLockService.hashPin('2580');
    expect(a, isNot(b)); // misma clave, distinto guardado
    final config = AppLockConfig.defaults().copyWith(enabled: true, pinHash: a);
    expect(lock.verifyPin('2580', config), isTrue);
    expect(lock.verifyPin('0000', config), isFalse);

    // PIN guardado por versiones anteriores.
    final legacy = sha256.convert(utf8.encode('saludamg|1234')).toString();
    await repo.save(
      AppLockConfig.defaults().copyWith(enabled: true, pinHash: legacy),
    );
    expect(lock.verifyPin('1234', repo.current()), isTrue);
    await lock.upgradePinIfLegacy('1234');
    expect(AppLockService.isLegacyHash(repo.current().pinHash), isFalse);
    expect(lock.verifyPin('1234', repo.current()), isTrue);
  });

  group('restaurar copia', () {
    late _MemoryMeasurements measurements;
    late _MemoryMedications medications;
    late BackupService backup;

    setUp(() async {
      measurements = _MemoryMeasurements();
      medications = _MemoryMedications();
      backup = BackupService(
        profiles: _MemoryProfiles(),
        measurements: measurements,
        reminders: _MemoryReminders(),
        importPreferences: _MemoryImportPrefs(),
        medications: medications,
        medicationDoseLogs: _MemoryDoseLogs(),
        medicationPreferences: _MemoryMedPrefs(),
      );
      await measurements.save(_reading(id: 'previa'));
    });

    test('un archivo dañado no borra nada', () async {
      await expectLater(
        backup.restoreFromMap({
          'app': 'SaludAMG',
          'readings': [
            {'id': 'buena', 'systolic': 120, 'diastolic': 80},
            {'id': 'mala', 'systolic': 'no es un número'},
          ],
          'medications': <Object>[],
        }),
        throwsA(isA<StateError>()),
      );
      expect(measurements.getAll().map((r) => r.id), ['previa']);
    });

    test('un archivo correcto sustituye las mediciones', () async {
      final message = await backup.restoreFromMap({
        'app': 'SaludAMG',
        'readings': [
          {'id': 'nueva', 'systolic': 125, 'diastolic': 82},
        ],
      });
      expect(measurements.getAll().map((r) => r.id), ['nueva']);
      expect(message, contains('1 mediciones'));
    });
  });

  testWidgets('editar sin tocar conserva los valores importados tal cual',
      (tester) async {
    await initializeDateFormatting('es_ES');
    final measurements = _MemoryMeasurements();
    final profiles = _MemoryProfiles();
    final reminders = _MemoryReminders();
    final importPreferences = _MemoryImportPrefs();
    final medications = _MemoryMedications();
    final doseLogs = _MemoryDoseLogs();
    final medPrefs = _MemoryMedPrefs();
    // Peso con 2 decimales y HRV fuera del rango de entrada manual (1–400).
    final original = _reading(id: 'r1', weightKg: 72.46, hrvMs: 450);
    await measurements.save(original);

    await tester.pumpWidget(
      AppScope(
        dependencies: AppDependencies(
          profiles: profiles,
          measurements: measurements,
          reminders: reminders,
          importPreferences: importPreferences,
          medications: medications,
          medicationDoseLogs: doseLogs,
          medicationPreferences: medPrefs,
          appLock: AppLockService(_MemoryAppLock()),
          healthSync: null,
          notifications: NotificationService(),
          exports: ExportService(),
          backup: BackupService(
            profiles: profiles,
            measurements: measurements,
            reminders: reminders,
            importPreferences: importPreferences,
            medications: medications,
            medicationDoseLogs: doseLogs,
            medicationPreferences: medPrefs,
          ),
        ),
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) => MeasurementFormScreen(existing: original),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final save = find.text('Guardar medición');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();

    final saved = measurements.getAll().single;
    expect(saved.weightKg, 72.46);
    expect(saved.hrvMs, 450);
    expect(saved.systolic, 130);
    expect(saved.diastolic, 85);
  });
}

BloodPressureModel _reading({
  required String id,
  double? weightKg,
  double? hrvMs,
}) {
  return BloodPressureModel(
    id: id,
    systolic: 130,
    diastolic: 85,
    pulse: 70,
    weightKg: weightKg,
    hrvMs: hrvMs,
    measuredAt: DateTime(2026, 11, 1, 9, 30),
    context: MeasurementContext.unspecified,
    notes: '',
    syncInfo: const SyncInfo.manual(),
  );
}
