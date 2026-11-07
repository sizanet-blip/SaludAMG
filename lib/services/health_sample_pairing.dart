import '../core/utils/ids.dart';
import '../domain/entities/blood_pressure_model.dart';
import '../domain/entities/import_preferences.dart';
import '../domain/entities/sync_info.dart';
import '../domain/enums/health_enums.dart';

enum HealthSampleKind {
  systolic,
  diastolic,
  pulse,
  restingPulse,
  oxygen,
  temperature,
  glucose,
  weight,
  bodyFat,
  bmi,
  steps,
  sleep,
  hrv,
}

/// Muestra ya desacoplada del paquete `health`, para poder probar el emparejado.
class RawHealthSample {
  const RawHealthSample({
    required this.kind,
    required this.value,
    required this.at,
    required this.uuid,
    required this.sourceName,
    required this.sourceId,
    required this.platformIsApple,
  });

  final HealthSampleKind kind;
  final double value;
  final DateTime at;
  final String uuid;
  final String sourceName;
  final String sourceId;
  final bool platformIsApple;
}

ImportSource detectImportSource({
  required bool platformIsApple,
  required String sourceName,
  required String sourceId,
}) {
  final blob = '${sourceName.toLowerCase()} ${sourceId.toLowerCase()}';
  const oHealthHints = [
    'ohealth',
    'oplus',
    'heytap',
    'oppo',
    'oneplus',
    'coloros',
    'realme',
  ];
  if (oHealthHints.any(blob.contains)) return ImportSource.oHealth;
  if (blob.contains('samsung')) return ImportSource.samsungHealth;
  if (platformIsApple) return ImportSource.appleHealth;
  return ImportSource.googleHealthConnect;
}

/// Construye mediciones según [prefs].
///
/// Con tensión activa: empareja sistólica/diastólica (±90 s) y adjunta extras.
/// También crea fichas huérfanas para anclas (peso, glucosa…) sin TA cercana.
/// Sin tensión: una ficha por ancla (tipo+día), con extras cercanos.
List<BloodPressureModel> pairHealthSamples(
  List<RawHealthSample> samples, {
  required ImportPreferences prefs,
  DateTime? syncedAt,
  String Function()? idFactory,
}) {
  final importedAt = syncedAt ?? DateTime.now();
  final nextId = idFactory ?? newLocalId;

  if (prefs.bloodPressure) {
    return _pairAroundBloodPressure(
      samples,
      prefs: prefs,
      importedAt: importedAt,
      nextId: nextId,
    );
  }
  return _pairWithoutBloodPressure(
    samples,
    prefs: prefs,
    importedAt: importedAt,
    nextId: nextId,
  );
}

List<BloodPressureModel> _pairAroundBloodPressure(
  List<RawHealthSample> samples, {
  required ImportPreferences prefs,
  required DateTime importedAt,
  required String Function() nextId,
}) {
  final systolics = samples.where((s) => s.kind == HealthSampleKind.systolic).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  final diastolics =
      samples.where((s) => s.kind == HealthSampleKind.diastolic).toList();
  final usedDiastolic = <int>{};
  final readings = <BloodPressureModel>[];
  final daysWithStepsSleep = <String>{};

  for (final systolic in systolics) {
    if (systolic.value < 40 || systolic.value > 300) continue;
    final diastolicIndex = _closestIndex(
      diastolics,
      systolic.at,
      const Duration(seconds: 90),
      usedDiastolic,
    );
    if (diastolicIndex == null) continue;
    final diastolic = diastolics[diastolicIndex];
    if (diastolic.value < 20 || diastolic.value > 200) continue;
    usedDiastolic.add(diastolicIndex);

    final dayKey =
        '${systolic.at.year}-${systolic.at.month}-${systolic.at.day}';
    final attachDaily = daysWithStepsSleep.add(dayKey);

    readings.add(
      _buildReading(
        samples: samples,
        prefs: prefs,
        at: systolic.at,
        systolic: systolic.value.round(),
        diastolic: diastolic.value.round(),
        sourceSample: systolic,
        importedAt: importedAt,
        id: nextId(),
        externalId: _externalId(systolic, diastolic),
        includeDailyTotals: attachDaily,
      ),
    );
  }

  // Anclas sin tensión cercana (peso a otra hora, etc.).
  readings.addAll(
    _orphanAnchors(
      samples,
      prefs: prefs,
      importedAt: importedAt,
      nextId: nextId,
      existing: readings,
      daysWithStepsSleep: daysWithStepsSleep,
    ),
  );

  readings.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
  return readings;
}

/// Muestras de peso/glucosa/… que no quedaron cerca de ninguna tensión.
List<BloodPressureModel> _orphanAnchors(
  List<RawHealthSample> samples, {
  required ImportPreferences prefs,
  required DateTime importedAt,
  required String Function() nextId,
  required List<BloodPressureModel> existing,
  required Set<String> daysWithStepsSleep,
}) {
  final anchors = _anchorSamples(samples, prefs);
  final usedDaysByKind = <String>{};
  final readings = <BloodPressureModel>[];

  for (final anchor in anchors) {
    final alreadyNearPressure = existing.any((reading) {
      if (!reading.hasPressure) return false;
      final gap = reading.measuredAt.difference(anchor.at).abs();
      return gap <= _orphanWindow(anchor.kind);
    });
    if (alreadyNearPressure) continue;

    final dayKindKey =
        '${anchor.at.year}-${anchor.at.month}-${anchor.at.day}-${anchor.kind.name}';
    if (!usedDaysByKind.add(dayKindKey)) continue;

    final dayKey = '${anchor.at.year}-${anchor.at.month}-${anchor.at.day}';
    final attachDaily = daysWithStepsSleep.add(dayKey);

    readings.add(
      _buildReading(
        samples: samples,
        prefs: prefs,
        at: anchor.at,
        systolic: null,
        diastolic: null,
        sourceSample: anchor,
        importedAt: importedAt,
        id: nextId(),
        externalId: anchor.uuid.isNotEmpty
            ? 'orphan|${anchor.uuid}'
            : 'orphan|${anchor.kind.name}|${anchor.at.toIso8601String()}',
        includeDailyTotals: attachDaily,
      ),
    );
  }
  return readings;
}

Duration _orphanWindow(HealthSampleKind kind) {
  return switch (kind) {
    HealthSampleKind.weight => const Duration(minutes: 30),
    HealthSampleKind.glucose => const Duration(hours: 4),
    HealthSampleKind.oxygen => const Duration(hours: 2),
    HealthSampleKind.temperature => const Duration(hours: 6),
    HealthSampleKind.pulse => const Duration(minutes: 5),
    _ => const Duration(hours: 12),
  };
}

List<BloodPressureModel> _pairWithoutBloodPressure(
  List<RawHealthSample> samples, {
  required ImportPreferences prefs,
  required DateTime importedAt,
  required String Function() nextId,
}) {
  final anchors = _anchorSamples(samples, prefs);

  if (anchors.isEmpty && (prefs.steps || prefs.sleep)) {
    final days = <DateTime>{};
    for (final sample in samples) {
      if ((sample.kind == HealthSampleKind.steps && prefs.steps) ||
          (sample.kind == HealthSampleKind.sleep && prefs.sleep)) {
        days.add(DateTime(sample.at.year, sample.at.month, sample.at.day));
      }
    }
    final readings = <BloodPressureModel>[];
    for (final day in days) {
      final noon = DateTime(day.year, day.month, day.day, 12);
      readings.add(
        _buildReading(
          samples: samples,
          prefs: prefs,
          at: noon,
          systolic: null,
          diastolic: null,
          sourceSample: RawHealthSample(
            kind: HealthSampleKind.steps,
            value: 0,
            at: noon,
            uuid: 'day-${day.toIso8601String()}',
            sourceName: 'Health Connect',
            sourceId: 'day',
            platformIsApple: false,
          ),
          importedAt: importedAt,
          id: nextId(),
          externalId: 'day|${day.toIso8601String()}',
          includeDailyTotals: true,
        ),
      );
    }
    readings.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return readings;
  }

  final usedDaysByKind = <String>{};
  final daysWithStepsSleep = <String>{};
  final readings = <BloodPressureModel>[];
  for (final anchor in anchors) {
    // Un ancla por tipo y día (no una sola ficha por día).
    final dayKindKey =
        '${anchor.at.year}-${anchor.at.month}-${anchor.at.day}-${anchor.kind.name}';
    if (!usedDaysByKind.add(dayKindKey)) continue;

    final dayKey = '${anchor.at.year}-${anchor.at.month}-${anchor.at.day}';
    final attachDaily = daysWithStepsSleep.add(dayKey);

    readings.add(
      _buildReading(
        samples: samples,
        prefs: prefs,
        at: anchor.at,
        systolic: null,
        diastolic: null,
        sourceSample: anchor,
        importedAt: importedAt,
        id: nextId(),
        externalId: anchor.uuid.isNotEmpty
            ? anchor.uuid
            : '${anchor.kind.name}|${anchor.at.toIso8601String()}',
        includeDailyTotals: attachDaily,
      ),
    );
  }
  readings.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
  return readings;
}

List<RawHealthSample> _anchorSamples(
  List<RawHealthSample> samples,
  ImportPreferences prefs,
) {
  return samples.where((sample) {
    return switch (sample.kind) {
      HealthSampleKind.weight => prefs.weight,
      HealthSampleKind.glucose => prefs.glucose,
      HealthSampleKind.temperature => prefs.temperature,
      HealthSampleKind.oxygen => prefs.oxygen,
      HealthSampleKind.restingPulse => prefs.restingPulse,
      HealthSampleKind.pulse => prefs.pulse,
      HealthSampleKind.bodyFat => prefs.bodyFat,
      HealthSampleKind.bmi => prefs.bmi,
      HealthSampleKind.hrv => prefs.hrv,
      _ => false,
    };
  }).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
}

BloodPressureModel _buildReading({
  required List<RawHealthSample> samples,
  required ImportPreferences prefs,
  required DateTime at,
  required int? systolic,
  required int? diastolic,
  required RawHealthSample sourceSample,
  required DateTime importedAt,
  required String id,
  required String externalId,
  bool includeDailyTotals = true,
}) {
  final pulse = prefs.pulse
      ? _closest(_of(samples, HealthSampleKind.pulse), at, const Duration(minutes: 5))
      : null;
  final resting = prefs.restingPulse
      ? _closest(
          _of(samples, HealthSampleKind.restingPulse),
          at,
          const Duration(hours: 12),
        )
      : null;
  final oxygen = prefs.oxygen
      ? _closest(_of(samples, HealthSampleKind.oxygen), at, const Duration(hours: 2))
      : null;
  final temperature = prefs.temperature
      ? _closest(
          _of(samples, HealthSampleKind.temperature),
          at,
          const Duration(hours: 6),
        )
      : null;
  final glucose = prefs.glucose
      ? _closest(_of(samples, HealthSampleKind.glucose), at, const Duration(hours: 4))
      : null;
  final weight = prefs.weight
      ? _closest(_of(samples, HealthSampleKind.weight), at, const Duration(minutes: 30))
      : null;
  final bodyFat = prefs.bodyFat
      ? _closest(_of(samples, HealthSampleKind.bodyFat), at, const Duration(hours: 12))
      : null;
  final bmi = prefs.bmi
      ? _closest(_of(samples, HealthSampleKind.bmi), at, const Duration(hours: 12))
      : null;
  final hrv = prefs.hrv
      ? _closest(_of(samples, HealthSampleKind.hrv), at, const Duration(hours: 12))
      : null;

  final sourceName = sourceSample.sourceName.trim();
  return BloodPressureModel(
    id: id,
    systolic: systolic,
    diastolic: diastolic,
    pulse: pulse?.value.round(),
    restingPulse: resting?.value.round(),
    oxygenSaturation: oxygen == null ? null : _oneDecimal(oxygen.value),
    bodyTemperatureC: temperature == null ? null : _oneDecimal(temperature.value),
    glucoseMgDl: glucose == null ? null : _oneDecimal(glucose.value),
    weightKg: weight == null ? null : _oneDecimal(weight.value),
    bodyFatPercent: bodyFat == null ? null : _oneDecimal(bodyFat.value),
    bmi: bmi == null ? null : _oneDecimal(bmi.value),
    steps: prefs.steps && includeDailyTotals
        ? _sumSameDay(_of(samples, HealthSampleKind.steps), at)
        : null,
    sleepMinutes: prefs.sleep && includeDailyTotals
        ? _sumSameDay(_of(samples, HealthSampleKind.sleep), at)
        : null,
    hrvMs: hrv == null ? null : _oneDecimal(hrv.value),
    measuredAt: at,
    context: MeasurementContext.unspecified,
    notes: '',
    syncInfo: SyncInfo(
      origin: ReadingOrigin.imported,
      source: detectImportSource(
        platformIsApple: sourceSample.platformIsApple,
        sourceName: sourceSample.sourceName,
        sourceId: sourceSample.sourceId,
      ),
      syncedAt: importedAt,
      externalId: externalId,
      sourceLabel: sourceName.isEmpty ? null : sourceName,
    ),
  );
}

List<RawHealthSample> _of(List<RawHealthSample> samples, HealthSampleKind kind) {
  return samples.where((sample) => sample.kind == kind).toList();
}

int? _sumSameDay(List<RawHealthSample> samples, DateTime at) {
  var total = 0.0;
  var found = false;
  for (final sample in samples) {
    if (sample.at.year == at.year &&
        sample.at.month == at.month &&
        sample.at.day == at.day) {
      total += sample.value;
      found = true;
    }
  }
  if (!found) return null;
  return total.round();
}

int? _closestIndex(
  List<RawHealthSample> samples,
  DateTime at,
  Duration window,
  Set<int> used,
) {
  int? bestIndex;
  var bestGap = window + const Duration(microseconds: 1);
  for (var i = 0; i < samples.length; i++) {
    if (used.contains(i)) continue;
    final gap = samples[i].at.difference(at).abs();
    if (gap <= window && gap < bestGap) {
      bestGap = gap;
      bestIndex = i;
    }
  }
  return bestIndex;
}

RawHealthSample? _closest(
  List<RawHealthSample> samples,
  DateTime at,
  Duration window,
) {
  RawHealthSample? best;
  var bestGap = window + const Duration(microseconds: 1);
  for (final sample in samples) {
    final gap = sample.at.difference(at).abs();
    if (gap <= window && gap < bestGap) {
      bestGap = gap;
      best = sample;
    }
  }
  return best;
}

double _oneDecimal(double value) => (value * 10).round() / 10;

String _externalId(RawHealthSample systolic, RawHealthSample diastolic) {
  if (systolic.uuid.isNotEmpty && diastolic.uuid.isNotEmpty) {
    return '${systolic.uuid}|${diastolic.uuid}';
  }
  return '${systolic.at.toIso8601String()}|${systolic.value.round()}|${diastolic.value.round()}';
}
