import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../domain/entities/blood_pressure_model.dart';
import '../domain/entities/import_preferences.dart';
import 'health_sample_pairing.dart';

/// Lee de Apple Salud / Health Connect solo los tipos marcados en [ImportPreferences].
class HealthSyncService {
  HealthSyncService(this._health);

  final Health _health;

  String get platformLabel =>
      Platform.isIOS ? 'Apple Salud' : 'Health Connect';

  List<HealthDataType> typesFor(ImportPreferences prefs) {
    final types = <HealthDataType>[];
    if (prefs.bloodPressure) {
      types.addAll([
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      ]);
    }
    if (prefs.pulse) types.add(HealthDataType.HEART_RATE);
    if (prefs.restingPulse) types.add(HealthDataType.RESTING_HEART_RATE);
    if (prefs.oxygen) types.add(HealthDataType.BLOOD_OXYGEN);
    if (prefs.temperature) types.add(HealthDataType.BODY_TEMPERATURE);
    if (prefs.glucose) types.add(HealthDataType.BLOOD_GLUCOSE);
    if (prefs.weight) types.add(HealthDataType.WEIGHT);
    if (prefs.bodyFat) types.add(HealthDataType.BODY_FAT_PERCENTAGE);
    if (prefs.bmi) types.add(HealthDataType.BODY_MASS_INDEX);
    if (prefs.steps) types.add(HealthDataType.STEPS);
    if (prefs.sleep) types.add(HealthDataType.SLEEP_ASLEEP);
    if (prefs.hrv) {
      if (Platform.isIOS) {
        types.add(HealthDataType.HEART_RATE_VARIABILITY_SDNN);
      } else {
        types.add(HealthDataType.HEART_RATE_VARIABILITY_RMSSD);
      }
    }
    return types;
  }

  Future<List<BloodPressureModel>> importRange({
    required DateTime from,
    required DateTime to,
    required ImportPreferences prefs,
  }) async {
    if (!to.isAfter(from)) {
      throw HealthSyncException('El periodo no es válido.');
    }
    if (!prefs.hasAnySelected) {
      throw HealthSyncException(
        'Activa al menos un dato en el menú → Datos a medir.',
      );
    }

    final types = typesFor(prefs);
    if (types.isEmpty) {
      throw HealthSyncException('No hay tipos de salud seleccionados.');
    }

    try {
      final permissions =
          List<HealthDataAccess>.filled(types.length, HealthDataAccess.READ);
      final granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );
      if (!granted) {
        throw HealthSyncException(
          'No se ha concedido permiso para los datos seleccionados.',
        );
      }

      if (Platform.isAndroid &&
          from.isBefore(DateTime.now().subtract(const Duration(days: 30)))) {
        try {
          await _health.requestHealthDataHistoryAuthorization();
        } catch (error) {
          debugPrint('Historial de Health Connect no autorizado: $error');
        }
      }

      final points = await _health.getHealthDataFromTypes(
        types: types,
        startTime: from,
        endTime: to,
      );
      final unique = _health.removeDuplicates(points);
      return pairHealthSamples(
        unique.map(_toSample).whereType<RawHealthSample>().toList(),
        prefs: prefs,
      );
    } on HealthSyncException {
      rethrow;
    } catch (error) {
      throw HealthSyncException(
        'No se ha podido leer $platformLabel. Comprueba permisos e instalación. ($error)',
      );
    }
  }

  RawHealthSample? _toSample(HealthDataPoint point) {
    final kind = switch (point.type) {
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC => HealthSampleKind.systolic,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC => HealthSampleKind.diastolic,
      HealthDataType.HEART_RATE => HealthSampleKind.pulse,
      HealthDataType.RESTING_HEART_RATE => HealthSampleKind.restingPulse,
      HealthDataType.BLOOD_OXYGEN => HealthSampleKind.oxygen,
      HealthDataType.BODY_TEMPERATURE => HealthSampleKind.temperature,
      HealthDataType.BLOOD_GLUCOSE => HealthSampleKind.glucose,
      HealthDataType.WEIGHT => HealthSampleKind.weight,
      HealthDataType.BODY_FAT_PERCENTAGE => HealthSampleKind.bodyFat,
      HealthDataType.BODY_MASS_INDEX => HealthSampleKind.bmi,
      HealthDataType.STEPS => HealthSampleKind.steps,
      HealthDataType.SLEEP_ASLEEP => HealthSampleKind.sleep,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN ||
      HealthDataType.HEART_RATE_VARIABILITY_RMSSD =>
        HealthSampleKind.hrv,
      _ => null,
    };
    if (kind == null) return null;
    final raw = point.value;
    if (raw is! NumericHealthValue) return null;
    return RawHealthSample(
      kind: kind,
      value: _normalizeHealthValue(kind, raw.numericValue.toDouble()),
      at: point.dateFrom,
      uuid: point.uuid,
      sourceName: point.sourceName,
      sourceId: point.sourceId,
      platformIsApple: point.sourcePlatform == HealthPlatformType.appleHealth,
    );
  }

  /// SpO₂ a veces llega 0–1; glucosa a veces en mmol/L.
  double _normalizeHealthValue(HealthSampleKind kind, double value) {
    if (kind == HealthSampleKind.oxygen && value > 0 && value <= 1.0) {
      return value * 100;
    }
    if (kind == HealthSampleKind.glucose && value > 0 && value < 30) {
      return value * 18.0182;
    }
    if (kind == HealthSampleKind.bodyFat && value > 0 && value <= 1.0) {
      return value * 100;
    }
    return value;
  }
}

class HealthSyncException implements Exception {
  HealthSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}
