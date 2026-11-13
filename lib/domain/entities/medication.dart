import '../enums/health_enums.dart';

/// Medicación personal con horarios de aviso y vigencia.
class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.notes,
    required this.startDate,
    required this.endDate,
    required this.minutesFromMidnight,
    required this.active,
    required this.stockRemaining,
    required this.reorderThreshold,
    required this.updatedAt,
    this.unitsPerDose = 1,
    this.weekdays = const [],
    this.doctorRequestDate,
    this.doctorRepeat = DoctorRequestRepeat.once,
    this.doctorRepeatEvery = 6,
    this.doctorLeadDays = 0,
  });

  /// Etiquetas cortas Lun…Dom (DateTime.weekday 1–7).
  static const weekdayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  final String id;
  final String name;

  /// Texto libre, p. ej. «1 comprimido» o «10 mg».
  final String dose;
  final String notes;

  /// Día de inicio (solo fecha).
  final DateTime startDate;

  /// Día de fin inclusive. Nulo = indefinido.
  final DateTime? endDate;

  /// Horarios de aviso en minutos desde medianoche.
  final List<int> minutesFromMidnight;
  final bool active;

  /// Unidades restantes. Nulo si no se usa stock.
  final int? stockRemaining;

  /// Aviso de pedir si stock ≤ este valor.
  final int? reorderThreshold;

  /// Unidades que se restan al marcar tomado (por defecto 1).
  final int unitsPerDose;

  /// Días de la semana (1=lun … 7=dom). Vacío = todos los días.
  final List<int> weekdays;

  /// Próxima fecha objetivo para pedir al médico / renovar receta.
  final DateTime? doctorRequestDate;

  /// Cómo avanzar tras marcar «Ya pedí».
  final DoctorRequestRepeat doctorRepeat;

  /// Intervalo en meses si [doctorRepeat] es [DoctorRequestRepeat.everyMonths].
  final int doctorRepeatEvery;

  /// Días de anticipación del aviso (0 = el mismo día).
  final int doctorLeadDays;

  final DateTime updatedAt;

  List<int> get sortedMinutes {
    final unique = minutesFromMidnight
        .where((minute) => minute >= 0 && minute < 24 * 60)
        .toSet()
        .toList()
      ..sort();
    return unique;
  }

  List<int> get effectiveWeekdays {
    final unique = weekdays.where((d) => d >= 1 && d <= 7).toSet().toList()
      ..sort();
    if (unique.isEmpty) return const [1, 2, 3, 4, 5, 6, 7];
    return unique;
  }

  bool get isEveryDay => effectiveWeekdays.length == 7;

  String get weekdaysLabel {
    if (isEveryDay) return 'Todos los días';
    return effectiveWeekdays.map((d) => weekdayLabels[d - 1]).join('·');
  }

  int get effectiveDoctorRepeatEvery => doctorRepeatEvery.clamp(1, 60);

  int get effectiveDoctorLeadDays => doctorLeadDays.clamp(0, 90);

  /// Día en que debe empezar a avisar (fecha objetivo − lead).
  DateTime? get doctorNotifyDate {
    final due = doctorRequestDate;
    if (due == null) return null;
    final day = DateTime(due.year, due.month, due.day);
    return day.subtract(Duration(days: effectiveDoctorLeadDays));
  }

  String get doctorRepeatLabel {
    return switch (doctorRepeat) {
      DoctorRequestRepeat.once => 'Solo una vez',
      DoctorRequestRepeat.yearly => 'Cada año',
      DoctorRequestRepeat.everyMonths =>
        'Cada $effectiveDoctorRepeatEvery '
            '${effectiveDoctorRepeatEvery == 1 ? 'mes' : 'meses'}',
    };
  }

  /// Vigente en [day] (fecha + día de la semana).
  bool isActiveOn(DateTime day) {
    if (!active) return false;
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (d.isBefore(start)) return false;
    final end = endDate;
    if (end != null) {
      final endDay = DateTime(end.year, end.month, end.day);
      if (d.isAfter(endDay)) return false;
    }
    return effectiveWeekdays.contains(d.weekday);
  }

  bool needsReorder({required bool trackStock, required bool reorderReminders}) {
    if (!trackStock || !reorderReminders || !active) return false;
    final stock = stockRemaining;
    final threshold = reorderThreshold;
    if (stock == null || threshold == null) return false;
    return stock <= threshold;
  }

  /// Aviso activo: desde la fecha de notificación (con lead), si sigue activa.
  bool needsDoctorRequestReminder([DateTime? onDay]) {
    if (!active || doctorNotifyDate == null) return false;
    final day = onDay ?? DateTime.now();
    final today = DateTime(day.year, day.month, day.day);
    return !today.isBefore(doctorNotifyDate!);
  }

  /// Días hasta el aviso (negativo = ya toca / vencido). Nulo si no hay fecha.
  int? doctorDaysUntil([DateTime? onDay]) {
    final notify = doctorNotifyDate;
    if (notify == null) return null;
    final day = onDay ?? DateTime.now();
    final today = DateTime(day.year, day.month, day.day);
    return notify.difference(today).inDays;
  }

  String? doctorStatusLabel([DateTime? onDay]) {
    final days = doctorDaysUntil(onDay);
    final due = doctorRequestDate;
    if (days == null || due == null) return null;
    if (days > 0) {
      return days == 1
          ? 'Médico · mañana'
          : 'Médico · en $days días';
    }
    if (days == 0) return 'Médico · pedir hoy';
    return 'Médico · pedir';
  }

  /// Tras «Ya pedí»: avanza la próxima fecha o limpia si era una sola vez.
  Medication afterDoctorRequestDone({DateTime? from}) {
    final current = doctorRequestDate;
    if (current == null) return this;
    final anchor = DateTime(current.year, current.month, current.day);
    switch (doctorRepeat) {
      case DoctorRequestRepeat.once:
        return copyWith(
          clearDoctorRequestDate: true,
          updatedAt: DateTime.now(),
        );
      case DoctorRequestRepeat.yearly:
        return copyWith(
          doctorRequestDate: _addCalendarYears(anchor, 1),
          updatedAt: DateTime.now(),
        );
      case DoctorRequestRepeat.everyMonths:
        return copyWith(
          doctorRequestDate:
              _addCalendarMonths(anchor, effectiveDoctorRepeatEvery),
          updatedAt: DateTime.now(),
        );
    }
  }

  static DateTime _addCalendarYears(DateTime date, int years) {
    final year = date.year + years;
    final day = date.day.clamp(1, _daysInMonth(year, date.month));
    return DateTime(year, date.month, day);
  }

  static DateTime _addCalendarMonths(DateTime date, int months) {
    final total = date.month - 1 + months;
    final year = date.year + total ~/ 12;
    final month = total % 12 + 1;
    final day = date.day.clamp(1, _daysInMonth(year, month));
    return DateTime(year, month, day);
  }

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  Medication copyWith({
    String? id,
    String? name,
    String? dose,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    List<int>? minutesFromMidnight,
    bool? active,
    int? stockRemaining,
    bool clearStock = false,
    int? reorderThreshold,
    bool clearThreshold = false,
    int? unitsPerDose,
    List<int>? weekdays,
    DateTime? doctorRequestDate,
    bool clearDoctorRequestDate = false,
    DoctorRequestRepeat? doctorRepeat,
    int? doctorRepeatEvery,
    int? doctorLeadDays,
    DateTime? updatedAt,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dose: dose ?? this.dose,
      notes: notes ?? this.notes,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      minutesFromMidnight: minutesFromMidnight ?? this.minutesFromMidnight,
      active: active ?? this.active,
      stockRemaining: clearStock ? null : (stockRemaining ?? this.stockRemaining),
      reorderThreshold:
          clearThreshold ? null : (reorderThreshold ?? this.reorderThreshold),
      unitsPerDose: unitsPerDose ?? this.unitsPerDose,
      weekdays: weekdays ?? this.weekdays,
      doctorRequestDate: clearDoctorRequestDate
          ? null
          : (doctorRequestDate ?? this.doctorRequestDate),
      doctorRepeat: doctorRepeat ?? this.doctorRepeat,
      doctorRepeatEvery: doctorRepeatEvery ?? this.doctorRepeatEvery,
      doctorLeadDays: doctorLeadDays ?? this.doctorLeadDays,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dose': dose,
        'notes': notes,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'minutesFromMidnight': minutesFromMidnight,
        'active': active,
        'stockRemaining': stockRemaining,
        'reorderThreshold': reorderThreshold,
        'unitsPerDose': unitsPerDose,
        'weekdays': weekdays,
        'doctorRequestDate': doctorRequestDate?.toIso8601String(),
        'doctorRepeat': doctorRepeat.index,
        'doctorRepeatEvery': doctorRepeatEvery,
        'doctorLeadDays': doctorLeadDays,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Medication.fromJson(Map<String, dynamic> json) {
    final repeats = DoctorRequestRepeat.values;
    final repeatIndex = (json['doctorRepeat'] as num?)?.toInt() ?? 0;
    return Medication(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      dose: json['dose'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ??
          DateTime.now(),
      endDate: json['endDate'] == null
          ? null
          : DateTime.tryParse(json['endDate'] as String),
      minutesFromMidnight: _ints(json['minutesFromMidnight']),
      active: json['active'] as bool? ?? true,
      stockRemaining: (json['stockRemaining'] as num?)?.toInt(),
      reorderThreshold: (json['reorderThreshold'] as num?)?.toInt(),
      unitsPerDose: (json['unitsPerDose'] as num?)?.toInt() ?? 1,
      weekdays: _ints(json['weekdays']),
      doctorRequestDate: json['doctorRequestDate'] == null
          ? null
          : DateTime.tryParse(json['doctorRequestDate'] as String),
      doctorRepeat: repeatIndex >= 0 && repeatIndex < repeats.length
          ? repeats[repeatIndex]
          : DoctorRequestRepeat.once,
      doctorRepeatEvery: (json['doctorRepeatEvery'] as num?)?.toInt() ?? 6,
      doctorLeadDays: (json['doctorLeadDays'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static List<int> _ints(dynamic raw) {
    if (raw is! List) return const [];
    return [for (final item in raw) if (item is num) item.toInt()];
  }
}
