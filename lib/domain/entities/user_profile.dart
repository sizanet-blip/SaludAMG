import '../enums/health_enums.dart';
import 'blood_pressure_model.dart';

/// Ficha personal y umbrales de referencia.
///
/// Los umbrales los elige quien usa la app. Sirven para colorear lecturas y
/// para la cabecera de los informes; no sustituyen el criterio de un médico.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.nickname,
    required this.birthDate,
    required this.bloodType,
    required this.heightCm,
    required this.referenceWeightKg,
    required this.systolicReference,
    required this.diastolicReference,
    required this.restingPulseReference,
    required this.alertMarginPercent,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.updatedAt,
  });

  static const storageKey = 'me';

  /// Margen por defecto (±% sobre la referencia) antes de avisar.
  static const defaultAlertMarginPercent = 10;

  factory UserProfile.defaults() {
    return UserProfile(
      id: storageKey,
      nickname: '',
      birthDate: null,
      bloodType: BloodType.unknown,
      heightCm: null,
      referenceWeightKg: null,
      systolicReference: 120,
      diastolicReference: 80,
      restingPulseReference: 70,
      alertMarginPercent: defaultAlertMarginPercent,
      emergencyContactName: '',
      emergencyContactPhone: '',
      updatedAt: DateTime.now(),
    );
  }

  final String id;

  /// Nombre o apodo que saldrá en los informes.
  final String nickname;
  final DateTime? birthDate;
  final BloodType bloodType;

  /// Altura en centímetros.
  final double? heightCm;

  /// Peso habitual de referencia, en kilogramos. No es una medición del historial.
  final double? referenceWeightKg;

  /// Sistólica de referencia, en mmHg.
  final int systolicReference;

  /// Diastólica de referencia, en mmHg.
  final int diastolicReference;

  /// Pulso de reposo de referencia, en lpm.
  final int restingPulseReference;

  /// Margen ±% sobre tensión y pulso. Dentro de la banda no hay aviso.
  final int alertMarginPercent;

  final String emergencyContactName;
  final String emergencyContactPhone;
  final DateTime updatedAt;

  /// Solo avisa si la lectura sale de la banda referencia ± margen.
  /// Sin tensión ni pulso evaluable → null. Dentro de banda → [ReferenceLevel.within].
  ReferenceLevel? levelFor(BloodPressureModel reading) {
    final flags = _flags(reading);
    if (flags == null) return null;
    if (flags.above && flags.below) {
      // Sisto alta y diasto baja (u similar): prioriza “por encima” en el badge.
      return ReferenceLevel.above;
    }
    if (flags.above) return ReferenceLevel.above;
    if (flags.below) return ReferenceLevel.below;
    return ReferenceLevel.within;
  }

  bool isAbove(BloodPressureModel reading) => _flags(reading)?.above ?? false;

  bool isBelow(BloodPressureModel reading) => _flags(reading)?.below ?? false;

  ({bool above, bool below})? _flags(BloodPressureModel reading) {
    final margin = alertMarginPercent.clamp(0, 50) / 100.0;
    final pulse = reading.pulse ?? reading.restingPulse;

    if (!reading.hasPressure && pulse == null) return null;

    var above = false;
    var below = false;

    if (reading.hasPressure) {
      final systolic = reading.systolic!;
      final diastolic = reading.diastolic!;
      above = systolic > systolicReference * (1 + margin) ||
          diastolic > diastolicReference * (1 + margin);
      below = systolic < systolicReference * (1 - margin) ||
          diastolic < diastolicReference * (1 - margin);
    }

    if (pulse != null) {
      above = above || pulse > restingPulseReference * (1 + margin);
      below = below || pulse < restingPulseReference * (1 - margin);
    }

    return (above: above, below: below);
  }
}
