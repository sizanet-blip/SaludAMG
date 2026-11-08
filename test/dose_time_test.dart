import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salud_amg/data/local/hive_adapters.dart';
import 'package:salud_amg/domain/entities/medication_dose_log.dart';
import 'package:salud_amg/domain/enums/health_enums.dart';

void main() {
  final scheduled = DateTime(2026, 11, 7, 22);
  final taken = DateTime(2026, 11, 8, 0, 30);

  test('la toma de las 22:00 tomada a las 00:30 cuenta para su día', () {
    final log = MedicationDoseLog(
      id: 'l1',
      medicationId: 'm1',
      scheduledAt: scheduled,
      status: DoseStatus.taken,
      recordedAt: DateTime(2026, 11, 8, 0, 31),
      takenAt: taken,
    );
    expect(log.effectiveTakenAt, taken);
    final back = MedicationDoseLog.fromJson(log.toJson());
    expect(back.takenAt, taken);
    expect(back.scheduledAt, scheduled);
  });

  test('registros antiguos sin hora real usan la de registro', () {
    final old = MedicationDoseLog.fromJson({
      'id': 'l0',
      'medicationId': 'm1',
      'scheduledAt': scheduled.toIso8601String(),
      'status': DoseStatus.taken.index,
      'recordedAt': DateTime(2026, 11, 7, 22, 5).toIso8601String(),
    });
    expect(old.takenAt, isNull);
    expect(old.effectiveTakenAt, DateTime(2026, 11, 7, 22, 5));
    final skipped = MedicationDoseLog.fromJson({
      ...old.toJson(),
      'status': DoseStatus.skipped.index,
    });
    expect(skipped.effectiveTakenAt, isNull);
  });

  test('Hive guarda la hora real de la toma', () async {
    final dir = await Directory.systemTemp.createTemp('salud_amg_tomas');
    Hive.init(dir.path);
    registerHiveAdapters();
    final box = await Hive.openBox<MedicationDoseLog>('tomas');
    await box.put(
      'l1',
      MedicationDoseLog(
        id: 'l1',
        medicationId: 'm1',
        scheduledAt: scheduled,
        status: DoseStatus.taken,
        recordedAt: taken,
        takenAt: taken,
      ),
    );
    await box.close();
    final again = await Hive.openBox<MedicationDoseLog>('tomas');
    expect(again.get('l1')?.takenAt, taken);
    await Hive.close();
  });
}
