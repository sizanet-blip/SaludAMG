import 'package:intl/intl.dart';

/// Se crean al usarlas, después de `initializeDateFormatting` en `main`.
String formatDateTime(DateTime value) =>
    DateFormat('dd/MM/yyyy HH:mm', 'es_ES').format(value);

String formatDate(DateTime value) =>
    DateFormat('dd/MM/yyyy', 'es_ES').format(value);

String formatDayMonth(DateTime value) =>
    DateFormat('dd/MM', 'es_ES').format(value);

String formatClock(int minutesFromMidnight) {
  final hour = (minutesFromMidnight ~/ 60).toString().padLeft(2, '0');
  final minute = (minutesFromMidnight % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatWeight(double kilograms) {
  final rounded = (kilograms * 10).round() / 10;
  final decimals = rounded == rounded.roundToDouble() ? 0 : 1;
  return rounded.toStringAsFixed(decimals).replaceAll('.', ',');
}

int? ageInYears(DateTime birth, DateTime on) {
  var age = on.year - birth.year;
  final birthdayThisYear = DateTime(on.year, birth.month, birth.day);
  if (on.isBefore(birthdayThisYear)) age--;
  return age < 0 ? null : age;
}
