import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salud_amg/data/local/hive_adapters.dart';
import 'package:salud_amg/data/local/hive_boxes.dart';
import 'package:salud_amg/domain/entities/blood_pressure_model.dart';
import 'package:salud_amg/domain/entities/import_preferences.dart';
import 'package:salud_amg/domain/entities/medication.dart';
import 'package:salud_amg/domain/entities/sync_info.dart';
import 'package:salud_amg/domain/entities/user_profile.dart';
import 'package:salud_amg/domain/enums/health_enums.dart';
import 'package:salud_amg/services/health_sample_pairing.dart';

void main() {
  final at = DateTime(2026, 10, 23, 8, 15);
  final prefsBpPulseWeight = ImportPreferences.defaults().copyWith(weight: true);

  RawHealthSample sample({
    required HealthSampleKind kind,
    required double value,
    required DateTime moment,
    String name = 'Health Connect',
    String id = 'com.google.android.apps.healthdata',
    bool apple = false,
    String? uuid,
  }) {
    return RawHealthSample(
      kind: kind,
      value: value,
      at: moment,
      uuid: uuid ?? '$kind-${moment.millisecondsSinceEpoch}',
      sourceName: name,
      sourceId: id,
      platformIsApple: apple,
    );
  }

  test('empareja sistólica y diastólica y añade pulso y peso si están activos', () {
    final readings = pairHealthSamples(
      [
        sample(kind: HealthSampleKind.systolic, value: 128, moment: at, uuid: 's1'),
        sample(kind: HealthSampleKind.diastolic, value: 82, moment: at, uuid: 'd1'),
        sample(
          kind: HealthSampleKind.pulse,
          value: 74,
          moment: at.add(const Duration(minutes: 2)),
        ),
        sample(
          kind: HealthSampleKind.weight,
          value: 81.24,
          moment: at.add(const Duration(minutes: 10)),
        ),
        sample(
          kind: HealthSampleKind.oxygen,
          value: 97,
          moment: at.add(const Duration(minutes: 1)),
        ),
      ],
      prefs: prefsBpPulseWeight,
      syncedAt: DateTime(2026, 10, 23, 9),
      idFactory: () => 'id-1',
    );

    expect(readings, hasLength(1));
    expect(readings.single.pressureLabel, '128/82');
    expect(readings.single.pulse, 74);
    expect(readings.single.weightKg, 81.2);
    expect(readings.single.oxygenSaturation, isNull);
    expect(readings.single.syncInfo.origin, ReadingOrigin.imported);
    expect(readings.single.syncInfo.externalId, 's1|d1');
  });

  test('no junta tensión separada por más de 90 segundos', () {
    final readings = pairHealthSamples(
      [
        sample(kind: HealthSampleKind.systolic, value: 120, moment: at),
        sample(
          kind: HealthSampleKind.diastolic,
          value: 80,
          moment: at.add(const Duration(minutes: 3)),
        ),
      ],
      prefs: ImportPreferences.defaults(),
    );

    expect(readings, isEmpty);
  });

  test('con O₂ activo adjunta la saturación cercana', () {
    final readings = pairHealthSamples(
      [
        sample(kind: HealthSampleKind.systolic, value: 120, moment: at, uuid: 's'),
        sample(kind: HealthSampleKind.diastolic, value: 80, moment: at, uuid: 'd'),
        sample(kind: HealthSampleKind.oxygen, value: 98.4, moment: at),
      ],
      prefs: ImportPreferences.defaults().copyWith(oxygen: true, pulse: false),
      idFactory: () => 'o2',
    );

    expect(readings.single.oxygenSaturation, 98.4);
    expect(readings.single.pulse, isNull);
  });

  test('reconoce OHealth y Samsung Health por el nombre de la fuente', () {
    expect(
      detectImportSource(
        platformIsApple: false,
        sourceName: 'OHealth',
        sourceId: 'com.oplus.health',
      ),
      ImportSource.oHealth,
    );
    expect(
      detectImportSource(
        platformIsApple: false,
        sourceName: 'Samsung Health',
        sourceId: 'com.sec.android.app.shealth',
      ),
      ImportSource.samsungHealth,
    );
  });

  test('aviso de pedir al médico con lead, anual y Ya pedí', () {
    final med = Medication(
      id: 'm-doc',
      name: 'Enalapril',
      dose: '10 mg',
      notes: '',
      startDate: DateTime(2026, 1, 1),
      endDate: null,
      minutesFromMidnight: const [8 * 60],
      active: true,
      stockRemaining: null,
      reorderThreshold: null,
      weekdays: const [],
      doctorRequestDate: DateTime(2026, 10, 20),
      doctorRepeat: DoctorRequestRepeat.yearly,
      doctorLeadDays: 14,
      updatedAt: at,
    );
    expect(med.doctorNotifyDate, DateTime(2026, 10, 6));
    expect(med.needsDoctorRequestReminder(DateTime(2026, 10, 5)), isFalse);
    expect(med.needsDoctorRequestReminder(DateTime(2026, 10, 6)), isTrue);
    expect(med.needsDoctorRequestReminder(DateTime(2026, 10, 20)), isTrue);

    final nextYear = med.afterDoctorRequestDone();
    expect(nextYear.doctorRequestDate, DateTime(2027, 10, 20));
    expect(nextYear.needsDoctorRequestReminder(DateTime(2026, 10, 20)), isFalse);

    final once = med.copyWith(doctorRepeat: DoctorRequestRepeat.once);
    expect(once.afterDoctorRequestDone().doctorRequestDate, isNull);

    final months = med.copyWith(
      doctorRepeat: DoctorRequestRepeat.everyMonths,
      doctorRepeatEvery: 6,
      doctorRequestDate: DateTime(2026, 1, 31),
    );
    expect(
      months.afterDoctorRequestDone().doctorRequestDate,
      DateTime(2026, 7, 31),
    );
  });

  test('medicación vigente con fin indefinido y stock bajo', () {
    final med = Medication(
      id: 'm1',
      name: 'Enalapril',
      dose: '10 mg',
      notes: '',
      startDate: DateTime(2026, 10, 1),
      endDate: null,
      minutesFromMidnight: const [8 * 60],
      active: true,
      stockRemaining: 3,
      reorderThreshold: 5,
      unitsPerDose: 1,
      weekdays: const [],
      updatedAt: at,
    );
    expect(med.isActiveOn(DateTime(2026, 10, 23)), isTrue);
    expect(med.isActiveOn(DateTime(2026, 9, 30)), isFalse);
    expect(
      med.needsReorder(trackStock: true, reorderReminders: true),
      isTrue,
    );
    final ended = Medication(
      id: 'm2',
      name: 'Temporal',
      dose: '',
      notes: '',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 10),
      minutesFromMidnight: const [8 * 60],
      active: true,
      stockRemaining: null,
      reorderThreshold: null,
      weekdays: const [],
      updatedAt: at,
    );
    expect(ended.isActiveOn(DateTime(2026, 10, 10)), isTrue);
    expect(ended.isActiveOn(DateTime(2026, 10, 11)), isFalse);

    final weekdaysOnly = Medication(
      id: 'm3',
      name: 'L-V',
      dose: '',
      notes: '',
      startDate: DateTime(2026, 10, 1),
      endDate: null,
      minutesFromMidnight: const [8 * 60],
      active: true,
      stockRemaining: null,
      reorderThreshold: null,
      weekdays: const [1, 2, 3, 4, 5],
      updatedAt: at,
    );
    // 23/10/2026 es viernes; 24/10/2026 sábado
    expect(weekdaysOnly.isActiveOn(DateTime(2026, 10, 23)), isTrue);
    expect(weekdaysOnly.isActiveOn(DateTime(2026, 10, 24)), isFalse);
  });

  test('con tensión activa conserva peso lejano como ficha huérfana', () {
    var id = 0;
    final readings = pairHealthSamples(
      [
        sample(kind: HealthSampleKind.systolic, value: 120, moment: at, uuid: 's'),
        sample(kind: HealthSampleKind.diastolic, value: 80, moment: at, uuid: 'd'),
        sample(
          kind: HealthSampleKind.weight,
          value: 80,
          moment: at.add(const Duration(hours: 8)),
          uuid: 'w',
        ),
      ],
      prefs: ImportPreferences.defaults().copyWith(weight: true, pulse: false),
      idFactory: () => 'id-${id++}',
    );

    expect(readings, hasLength(2));
    expect(readings.any((r) => r.hasPressure), isTrue);
    expect(
      readings.any((r) => !r.hasPressure && r.weightKg == 80),
      isTrue,
    );
  });

  test('sin tensión: una ficha por tipo y día, no una sola por día', () {
    var id = 0;
    final readings = pairHealthSamples(
      [
        sample(kind: HealthSampleKind.weight, value: 80, moment: at, uuid: 'w'),
        sample(
          kind: HealthSampleKind.glucose,
          value: 95,
          moment: at.add(const Duration(hours: 2)),
          uuid: 'g',
        ),
      ],
      prefs: ImportPreferences.defaults().copyWith(
        bloodPressure: false,
        pulse: false,
        weight: true,
        glucose: true,
      ),
      idFactory: () => 'id-${id++}',
    );

    expect(readings, hasLength(2));
  });

  test('aviso solo si se sale del margen ±% sobre la referencia', () {
    final profile = UserProfile.defaults(); // margen 10 % → 120±12, 80±8, 70±7
    final mild = BloodPressureModel(
      id: '1',
      systolic: 125,
      diastolic: 82,
      pulse: 72,
      weightKg: null,
      measuredAt: at,
      context: MeasurementContext.morningFasting,
      notes: '',
      syncInfo: const SyncInfo.manual(),
    );
    final high = BloodPressureModel(
      id: '2',
      systolic: 145,
      diastolic: 92,
      pulse: 70,
      weightKg: null,
      measuredAt: at,
      context: MeasurementContext.morningFasting,
      notes: '',
      syncInfo: const SyncInfo.manual(),
    );
    expect(profile.levelFor(mild), ReferenceLevel.within);
    expect(profile.levelFor(high), ReferenceLevel.above);
  });

  test('Hive conserva extras de una medición importada', () async {
    final directory = await Directory.systemTemp.createTemp('salud_amg_test');
    Hive.init(directory.path);
    registerHiveAdapters();
    final readings = await Hive.openBox<BloodPressureModel>(HiveBoxes.readings);
    final prefsBox = await Hive.openBox<ImportPreferences>(HiveBoxes.importPrefs);

    await prefsBox.put(
      ImportPreferences.storageKey,
      ImportPreferences.defaults().copyWith(glucose: true, steps: true),
    );
    await readings.put(
      'r1',
      BloodPressureModel(
        id: 'r1',
        systolic: 118,
        diastolic: 76,
        pulse: null,
        weightKg: 70.5,
        measuredAt: at,
        context: MeasurementContext.beforeSleep,
        notes: 'sin síntomas',
        syncInfo: const SyncInfo(
          origin: ReadingOrigin.imported,
          source: ImportSource.oHealth,
          sourceLabel: 'OHealth',
          externalId: 'ext-1',
        ),
        glucoseMgDl: 95,
        steps: 4200,
        oxygenSaturation: 97,
      ),
    );

    await readings.close();
    await prefsBox.close();
    final readingsAgain = await Hive.openBox<BloodPressureModel>(HiveBoxes.readings);
    final prefsAgain = await Hive.openBox<ImportPreferences>(HiveBoxes.importPrefs);

    final stored = readingsAgain.get('r1');
    expect(stored?.glucoseMgDl, 95);
    expect(stored?.steps, 4200);
    expect(stored?.oxygenSaturation, 97);
    expect(prefsAgain.get(ImportPreferences.storageKey)?.glucose, isTrue);
    expect(prefsAgain.get(ImportPreferences.storageKey)?.bloodPressure, isTrue);
    expect(prefsAgain.get(ImportPreferences.storageKey)?.temperature, isFalse);

    await Hive.close();
    await directory.delete(recursive: true);
  });
}
