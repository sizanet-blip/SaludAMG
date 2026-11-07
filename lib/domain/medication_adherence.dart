import 'entities/medication.dart';
import 'entities/medication_dose_log.dart';
import 'enums/health_enums.dart';

class AdherenceSummary {
  const AdherenceSummary({
    required this.expected,
    required this.taken,
    required this.skipped,
  });

  final int expected;
  final int taken;
  final int skipped;

  int get pending => (expected - taken - skipped).clamp(0, expected);

  double? get takenPercent {
    if (expected <= 0) return null;
    return (taken / expected) * 100;
  }
}

/// Calcula cumplimiento esperado vs registrado en un periodo.
AdherenceSummary adherenceFor({
  required Medication medication,
  required List<MedicationDoseLog> logs,
  required DateTime from,
  required DateTime to,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final endExclusive = DateTime(to.year, to.month, to.day)
      .add(const Duration(days: 1));
  var expected = 0;
  for (var day = start;
      day.isBefore(endExclusive);
      day = day.add(const Duration(days: 1))) {
    if (!medication.isActiveOn(day)) continue;
    expected += medication.sortedMinutes.length;
  }

  final relevant = logs.where((log) {
    if (log.medicationId != medication.id) return false;
    return !log.scheduledAt.isBefore(start) &&
        log.scheduledAt.isBefore(endExclusive);
  });

  var taken = 0;
  var skipped = 0;
  for (final log in relevant) {
    if (log.status == DoseStatus.taken) {
      taken++;
    } else {
      skipped++;
    }
  }

  return AdherenceSummary(expected: expected, taken: taken, skipped: skipped);
}

AdherenceSummary todayAdherence({
  required List<Medication> medications,
  required List<MedicationDoseLog> Function(String id) logsFor,
}) {
  final today = DateTime.now();
  var expected = 0;
  var taken = 0;
  var skipped = 0;
  for (final med in medications) {
    if (!med.isActiveOn(today)) continue;
    expected += med.sortedMinutes.length;
    for (final log in logsFor(med.id)) {
      if (log.status == DoseStatus.taken) {
        taken++;
      } else {
        skipped++;
      }
    }
  }
  return AdherenceSummary(expected: expected, taken: taken, skipped: skipped);
}
