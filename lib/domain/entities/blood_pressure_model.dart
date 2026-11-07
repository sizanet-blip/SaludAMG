import '../enums/health_enums.dart';
import 'sync_info.dart';

/// Una medición (normalmente tensión) con vitales y contexto opcionales.
class BloodPressureModel {
  const BloodPressureModel({
    required this.id,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.weightKg,
    required this.measuredAt,
    required this.context,
    required this.notes,
    required this.syncInfo,
    this.feeling = '',
    this.restingPulse,
    this.oxygenSaturation,
    this.bodyTemperatureC,
    this.glucoseMgDl,
    this.bodyFatPercent,
    this.bmi,
    this.steps,
    this.sleepMinutes,
    this.hrvMs,
  });

  final String id;

  /// mmHg. Nulo si la importación no traía tensión (solo extras).
  final int? systolic;

  /// mmHg.
  final int? diastolic;

  /// lpm.
  final int? pulse;

  /// lpm en reposo.
  final int? restingPulse;

  /// % SpO₂.
  final double? oxygenSaturation;

  /// °C.
  final double? bodyTemperatureC;

  /// mg/dL.
  final double? glucoseMgDl;

  /// kg.
  final double? weightKg;

  /// %.
  final double? bodyFatPercent;

  /// Índice de masa corporal.
  final double? bmi;

  /// Pasos del día calendario de [measuredAt].
  final int? steps;

  /// Minutos de sueño asociados al día.
  final int? sleepMinutes;

  /// Variabilidad (ms).
  final double? hrvMs;

  final DateTime measuredAt;
  final MeasurementContext context;
  final String notes;

  /// Cómo me siento (corto), aparte de las notas largas.
  final String feeling;
  final SyncInfo syncInfo;

  bool get hasPressure => systolic != null && diastolic != null;

  String get pressureLabel {
    if (!hasPressure) return 'Sin tensión';
    return '$systolic/$diastolic';
  }

  /// Resumen corto para listas (solo valores presentes).
  List<String> get extraChips {
    final chips = <String>[];
    if (pulse != null) chips.add('$pulse lpm');
    if (restingPulse != null) chips.add('reposo $restingPulse');
    if (oxygenSaturation != null) {
      chips.add('O₂ ${_trim(oxygenSaturation!)}%');
    }
    if (bodyTemperatureC != null) {
      chips.add('${_trim(bodyTemperatureC!)} °C');
    }
    if (glucoseMgDl != null) {
      chips.add('gluc ${_trim(glucoseMgDl!)}');
    }
    if (weightKg != null) chips.add('${_trim(weightKg!)} kg');
    if (bodyFatPercent != null) {
      chips.add('grasa ${_trim(bodyFatPercent!)}%');
    }
    if (bmi != null) chips.add('IMC ${_trim(bmi!)}');
    if (steps != null) chips.add('$steps pasos');
    if (sleepMinutes != null) {
      final h = sleepMinutes! ~/ 60;
      final m = sleepMinutes! % 60;
      chips.add(h > 0 ? 'sueño ${h}h ${m}m' : 'sueño ${m}m');
    }
    if (hrvMs != null) chips.add('HRV ${_trim(hrvMs!)} ms');
    return chips;
  }

  static String _trim(double value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }
}
