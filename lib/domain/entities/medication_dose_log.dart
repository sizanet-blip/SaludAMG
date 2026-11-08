import '../enums/health_enums.dart';

/// Registro de una toma (tomado u omitido) para un horario concreto.
class MedicationDoseLog {
  const MedicationDoseLog({
    required this.id,
    required this.medicationId,
    required this.scheduledAt,
    required this.status,
    required this.recordedAt,
    this.takenAt,
  });

  final String id;
  final String medicationId;

  /// Momento del aviso/horario al que corresponde la toma.
  final DateTime scheduledAt;
  final DoseStatus status;
  final DateTime recordedAt;

  /// Cuándo se tomó de verdad (p. ej. la de las 22:00 a las 00:30 del día
  /// siguiente). Nulo en registros antiguos: se usa [recordedAt].
  final DateTime? takenAt;

  /// Hora real de la toma, solo si está como tomada.
  DateTime? get effectiveTakenAt =>
      status == DoseStatus.taken ? (takenAt ?? recordedAt) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicationId': medicationId,
        'scheduledAt': scheduledAt.toIso8601String(),
        'status': status.index,
        'recordedAt': recordedAt.toIso8601String(),
        if (takenAt != null) 'takenAt': takenAt!.toIso8601String(),
      };

  factory MedicationDoseLog.fromJson(Map<String, dynamic> json) {
    final statusIndex = (json['status'] as num?)?.toInt() ?? 0;
    return MedicationDoseLog(
      id: json['id'] as String? ?? '',
      medicationId: json['medicationId'] as String? ?? '',
      scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? '') ??
          DateTime.now(),
      status: statusIndex >= 0 && statusIndex < DoseStatus.values.length
          ? DoseStatus.values[statusIndex]
          : DoseStatus.taken,
      recordedAt: DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
          DateTime.now(),
      takenAt: DateTime.tryParse(json['takenAt'] as String? ?? ''),
    );
  }
}
