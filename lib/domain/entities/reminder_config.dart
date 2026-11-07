import '../enums/health_enums.dart';

/// Recordatorio local para acordarse de medir la tensión.
class ReminderConfig {
  const ReminderConfig({
    required this.id,
    required this.frequency,
    required this.minutesFromMidnight,
    required this.active,
  });

  static const storageKey = 'main';
  static const maxSlots = 8;

  factory ReminderConfig.defaults() {
    return const ReminderConfig(
      id: storageKey,
      frequency: ReminderFrequency.daily,
      minutesFromMidnight: [8 * 60],
      active: false,
    );
  }

  final String id;
  final ReminderFrequency frequency;

  /// Horas del día expresadas en minutos desde medianoche. De 0 a 1439.
  final List<int> minutesFromMidnight;
  final bool active;

  List<int> get sortedMinutes {
    final unique = minutesFromMidnight.where((minute) => minute >= 0 && minute < 24 * 60).toSet().toList()
      ..sort();
    if (unique.length <= maxSlots) return unique;
    return unique.sublist(0, maxSlots);
  }
}

/// Reparte [count] avisos entre las 08:00 y las 21:00.
List<int> spreadReminderTimes(int count) {
  final safe = count.clamp(1, 8);
  if (safe == 1) return const [8 * 60];
  const start = 8 * 60;
  const end = 21 * 60;
  final step = (end - start) / (safe - 1);
  return [for (var i = 0; i < safe; i++) (start + step * i).round()];
}
