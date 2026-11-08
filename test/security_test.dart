import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salud_amg/data/local/hive_adapters.dart';
import 'package:salud_amg/data/local/hive_boxes.dart';
import 'package:salud_amg/data/local/hive_setup.dart';
import 'package:salud_amg/domain/entities/app_lock_config.dart';
import 'package:salud_amg/domain/entities/blood_pressure_model.dart';
import 'package:salud_amg/domain/entities/sync_info.dart';
import 'package:salud_amg/domain/enums/health_enums.dart';
import 'package:salud_amg/services/app_auth_service.dart';

void main() {
  test('los datos antiguos sin cifrar pasan a la caja cifrada', () async {
    final dir = await Directory.systemTemp.createTemp('salud_amg_cifrado');
    Hive.init(dir.path);
    registerHiveAdapters();

    final legacy =
        await Hive.openBox<BloodPressureModel>(HiveBoxes.legacyReadings);
    await legacy.put(
      'r1',
      BloodPressureModel(
        id: 'r1',
        systolic: 125,
        diastolic: 80,
        pulse: 70,
        weightKg: 72.4,
        measuredAt: DateTime(2026, 11, 1, 9),
        context: MeasurementContext.unspecified,
        notes: 'antes de cifrar',
        syncInfo: const SyncInfo.manual(),
      ),
    );
    await legacy.close();

    final key = Hive.generateSecureKey();
    await openEncryptedBox<BloodPressureModel>(
      HiveBoxes.readings,
      HiveBoxes.legacyReadings,
      HiveAesCipher(key),
    );

    expect(await Hive.boxExists(HiveBoxes.legacyReadings), isFalse);
    final box = Hive.box<BloodPressureModel>(HiveBoxes.readings);
    expect(box.get('r1')?.notes, 'antes de cifrar');

    // En disco ya no se lee el texto en claro.
    await box.close();
    final raw = await File('${dir.path}/${HiveBoxes.readings}.hive')
        .readAsString(encoding: const Latin1Codec());
    expect(raw.contains('antes de cifrar'), isFalse);

    // Con la misma clave se vuelve a abrir bien.
    final again = await Hive.openBox<BloodPressureModel>(
      HiveBoxes.readings,
      encryptionCipher: HiveAesCipher(key),
    );
    expect(again.get('r1')?.systolic, 125);
    await Hive.close();
  });

  test('bloqueo activo con PIN, solo con huella o con ambos', () {
    const none = AppLockConfig(enabled: false, pinHash: '', useBiometrics: false);
    expect(none.isActive, isFalse);
    expect(none.copyWith(useBiometrics: true).isActive, isTrue);
    expect(none.copyWith(useBiometrics: true).pinActive, isFalse);
    expect(none.copyWith(enabled: true, pinHash: 'x').pinActive, isTrue);
    // PIN activado pero sin PIN guardado: no bloquea.
    expect(none.copyWith(enabled: true).isActive, isFalse);
  });

  test('errores de red en lenguaje claro', () {
    final sinRed = AppAuthService.friendlyError(
      const SocketException('Failed host lookup'),
    );
    expect(sinRed, contains('No hay conexión'));
    expect(sinRed, isNot(contains('SocketException')));
    expect(
      AppAuthService.friendlyError(TimeoutException('x')),
      contains('tarda demasiado'),
    );
  });
}
