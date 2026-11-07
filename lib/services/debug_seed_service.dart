import 'dart:math';

import '../core/utils/ids.dart';
import '../domain/entities/blood_pressure_model.dart';
import '../domain/entities/sync_info.dart';
import '../domain/enums/health_enums.dart';
import '../domain/repositories/repositories.dart';

/// Genera y limpia mediciones ficticias para debug.
class DebugSeedService {
  const DebugSeedService(this._measurements);

  final MeasurementRepository _measurements;

  static const notesMarker = 'Datos de prueba (debug)';
  static const externalIdPrefix = 'debug-seed:';

  /// Crea ~2 tomas al día durante [days] días (por defecto 21).
  Future<int> seedRandomDays({int days = 21}) async {
    final random = Random();
    final now = DateTime.now();
    final contexts = MeasurementContext.values
        .where((c) => c != MeasurementContext.unspecified)
        .toList();
    var baseWeight = 72.0 + random.nextDouble() * 8;
    var created = 0;

    for (var dayOffset = days - 1; dayOffset >= 0; dayOffset--) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: dayOffset));
      final takes = 1 + random.nextInt(2);
      for (var t = 0; t < takes; t++) {
        final morning = t == 0;
        final hour = morning ? 7 + random.nextInt(3) : 20 + random.nextInt(3);
        final measuredAt = DateTime(
          day.year,
          day.month,
          day.day,
          hour,
          random.nextInt(60),
        );
        if (measuredAt.isAfter(now)) continue;

        final systolic = 108 + random.nextInt(35);
        final diastolic = 68 + random.nextInt(22);
        final pulse = 58 + random.nextInt(35);
        baseWeight += (random.nextDouble() - 0.5) * 0.35;
        final weight = double.parse(baseWeight.toStringAsFixed(1));
        final id = newLocalId();

        final reading = BloodPressureModel(
          id: id,
          systolic: systolic,
          diastolic: diastolic,
          pulse: pulse,
          restingPulse: morning ? 52 + random.nextInt(18) : null,
          oxygenSaturation: 95 + random.nextDouble() * 4,
          bodyTemperatureC: 36.2 + random.nextDouble() * 1.1,
          glucoseMgDl: morning ? 85 + random.nextDouble() * 35 : null,
          weightKg: weight,
          bodyFatPercent: 18 + random.nextDouble() * 8,
          bmi: double.parse((weight / (1.75 * 1.75)).toStringAsFixed(1)),
          steps: morning ? null : 3500 + random.nextInt(9000),
          sleepMinutes: morning ? 360 + random.nextInt(150) : null,
          hrvMs: 25 + random.nextDouble() * 40,
          measuredAt: measuredAt,
          context: morning
              ? MeasurementContext.morningFasting
              : contexts[random.nextInt(contexts.length)],
          notes: notesMarker,
          syncInfo: SyncInfo(
            origin: ReadingOrigin.manual,
            source: ImportSource.manual,
            externalId: '$externalIdPrefix$id',
            sourceLabel: 'Datos de prueba',
          ),
        );
        await _measurements.save(reading);
        created++;
      }
    }
    return created;
  }

  /// Borra solo mediciones marcadas como de prueba. No toca las reales.
  Future<int> clearSeeded() async {
    final seeded = _measurements.getAll().where(_isSeeded).toList();
    for (final reading in seeded) {
      await _measurements.delete(reading.id);
    }
    return seeded.length;
  }

  int countSeeded() => _measurements.getAll().where(_isSeeded).length;

  static bool _isSeeded(BloodPressureModel reading) {
    final externalId = reading.syncInfo.externalId ?? '';
    return externalId.startsWith(externalIdPrefix);
  }
}
