import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/ids.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_dose_log.dart';
import '../../domain/entities/medication_preferences.dart';
import '../../domain/enums/health_enums.dart';
import '../../domain/medication_adherence.dart';
import '../widgets/salud_amg_app_bar.dart';
import 'medication_form_screen.dart';
import 'medication_preferences_screen.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  List<Medication> _medications = const [];
  MedicationPreferences _prefs = MedicationPreferences.defaults();
  var _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() {
    if (!mounted) return;
    final deps = AppScope.of(context);
    setState(() {
      _medications = deps.medications.getAll();
      _prefs = deps.medicationPreferences.current();
      _ready = true;
    });
  }

  Future<void> _openForm([Medication? existing]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationFormScreen(existing: existing),
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _openPrefs() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MedicationPreferencesScreen()),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(Medication medication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar medicación'),
        content: Text(
          'Se borrará «${medication.name}», sus avisos y el historial de tomas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deps = AppScope.of(context);
    await deps.medicationDoseLogs.deleteForMedication(medication.id);
    await deps.medications.delete(medication.id);
    await deps.notifications.syncMedicationSchedule(
      medications: deps.medications.getAll(),
      preferences: deps.medicationPreferences.current(),
    );
    _reload();
  }

  Future<void> _restock(Medication medication) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => _RestockDialog(medicationName: medication.name),
    );
    if (amount == null || amount <= 0 || !mounted) return;
    final current = medication.stockRemaining ?? 0;
    final deps = AppScope.of(context);
    await deps.medications.save(
      medication.copyWith(
        stockRemaining: current + amount,
        updatedAt: DateTime.now(),
      ),
    );
    await deps.notifications.syncMedicationSchedule(
      medications: deps.medications.getAll(),
      preferences: deps.medicationPreferences.current(),
    );
    _reload();
  }

  Future<void> _markDoctorDone(Medication medication) async {
    final deps = AppScope.of(context);
    final previous = deps.medications.getById(medication.id) ?? medication;
    final updated = previous.afterDoctorRequestDone();
    await deps.medications.save(updated);
    await deps.notifications.syncMedicationSchedule(
      medications: deps.medications.getAll(),
      preferences: deps.medicationPreferences.current(),
    );
    if (!mounted) return;
    _reload();
    final next = updated.doctorRequestDate;
    final message = next == null
        ? 'Recordatorio de ${previous.name} cerrado.'
        : 'Siguiente aviso de ${previous.name}: ${formatDate(next)}.';
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            await deps.medications.save(previous);
            await deps.notifications.syncMedicationSchedule(
              medications: deps.medications.getAll(),
              preferences: deps.medicationPreferences.current(),
            );
            if (mounted) _reload();
          },
        ),
      ),
    );
  }

  bool _hasPendingOn(Medication med, DateTime day) {
    final deps = AppScope.of(context);
    for (final minutes in med.sortedMinutes) {
      final slot = day.add(Duration(minutes: minutes));
      if (deps.medicationDoseLogs.findForSlot(med.id, slot) == null) {
        return true;
      }
    }
    return false;
  }

  Future<void> _recordDose({
    required Medication medication,
    required DateTime scheduledAt,
    required DoseStatus status,
    DateTime? takenAt,
  }) async {
    final deps = AppScope.of(context);
    // Recarga fresca: evita stock incorrecto con toques rápidos.
    final current = deps.medications.getById(medication.id) ?? medication;
    final existing = deps.medicationDoseLogs.findForSlot(
      current.id,
      scheduledAt,
    );
    final previous = existing?.status;
    final log = MedicationDoseLog(
      id: existing?.id ?? newLocalId(),
      medicationId: current.id,
      scheduledAt: scheduledAt,
      status: status,
      recordedAt: DateTime.now(),
      takenAt: status == DoseStatus.taken ? takenAt : null,
    );
    await deps.medicationDoseLogs.save(log);

    if (_prefs.trackStock) {
      final stock = current.stockRemaining;
      final units = current.unitsPerDose.clamp(1, 99);
      if (stock != null) {
        var next = stock;
        if (status == DoseStatus.taken && previous != DoseStatus.taken) {
          next = (stock - units).clamp(0, 999999);
        } else if (status == DoseStatus.skipped &&
            previous == DoseStatus.taken) {
          next = stock + units;
        }
        if (next != stock) {
          await deps.medications.save(
            current.copyWith(
              stockRemaining: next,
              updatedAt: DateTime.now(),
            ),
          );
          await deps.notifications.syncMedicationSchedule(
            medications: deps.medications.getAll(),
            preferences: deps.medicationPreferences.current(),
          );
        }
      }
    }

    if (!mounted) return;
    _reload();
  }

  /// «Tomado»: pregunta cuándo (por defecto, ahora). Sirve para la toma
  /// olvidada de las 22:00 que se toma a las 00:30 del día siguiente.
  Future<void> _onStatus(
    Medication medication,
    DateTime scheduledAt,
    DoseStatus status,
  ) async {
    DateTime? takenAt;
    if (status == DoseStatus.taken) {
      takenAt = await _askTakenAt(medication, scheduledAt);
      if (takenAt == null) return;
    }
    await _recordDose(
      medication: medication,
      scheduledAt: scheduledAt,
      status: status,
      takenAt: takenAt,
    );
  }

  Future<DateTime?> _askTakenAt(
    Medication medication,
    DateTime scheduledAt,
  ) {
    final now = DateTime.now();
    var takenAt = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    // Desde un día antes de la hora prevista hasta ahora.
    final first = scheduledAt.subtract(const Duration(days: 1));
    return showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Tomado · ${medication.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Toma prevista: ${dayLabel(scheduledAt, now)} '
                '${formatClock(scheduledAt.hour * 60 + scheduledAt.minute)}',
                style: const TextStyle(color: AppColors.subtitle),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: const Text('¿Cuándo la tomaste?'),
                subtitle: Text(
                  '${dayLabel(takenAt, now)} '
                  '${formatClock(takenAt.hour * 60 + takenAt.minute)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.title,
                  ),
                ),
                trailing: const Text('Cambiar'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: takenAt,
                    firstDate: DateTime(first.year, first.month, first.day),
                    lastDate: now,
                  );
                  if (date == null || !ctx.mounted) return;
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(takenAt),
                  );
                  if (time == null) return;
                  var picked = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                  if (picked.isAfter(now)) picked = takenAt;
                  setLocal(() => takenAt = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, takenAt),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 1));
    final pendingYesterday = !_ready || !_prefs.trackDoses
        ? <Medication>[]
        : _medications
            .where(
              (med) =>
                  med.isActiveOn(yesterday) &&
                  _hasPendingOn(med, yesterday),
            )
            .toList();
    final activeToday =
        _medications.where((med) => med.isActiveOn(today)).toList();
    final others =
        _medications.where((med) => !med.isActiveOn(today)).toList();
    final deps = _ready ? AppScope.of(context) : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SaludAmgAppBar(
        section: 'Medicaciones',
        actions: [
          IconButton(
            tooltip: 'Configuración',
            onPressed: _openPrefs,
            icon: const Icon(Icons.tune_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Medicación'),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _medications.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 96),
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 56,
                      color: AppColors.accent.withValues(alpha: 0.85),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Todavía no hay medicaciones',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.title,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Añade nombre, dosis, fechas y horarios. '
                      'Los avisos se programan en este teléfono.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.subtitle,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => _openForm(),
                      child: const Text('Añadir medicación'),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  children: [
                    if (pendingYesterday.isNotEmpty) ...[
                      const Text(
                        'Pendientes de ayer',
                        style: TextStyle(
                          color: AppColors.title,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '¿Se te olvidó marcarla o la tomaste pasada la '
                        'medianoche? Márcala aquí con la hora real.',
                        style: TextStyle(color: AppColors.subtitle),
                      ),
                      const SizedBox(height: 8),
                      for (final med in pendingYesterday) ...[
                        _TodayMedicationCard(
                          medication: med,
                          day: yesterday,
                          onlyPending: true,
                          onStatus: (scheduledAt, status) =>
                              _onStatus(med, scheduledAt, status),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                    ],
                    if (_prefs.trackDoses && activeToday.isNotEmpty) ...[
                      const Text(
                        'Hoy',
                        style: TextStyle(
                          color: AppColors.title,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final med in activeToday) ...[
                        _TodayMedicationCard(
                          medication: med,
                          day: DateTime(today.year, today.month, today.day),
                          onStatus: (scheduledAt, status) =>
                              _onStatus(med, scheduledAt, status),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                    ],
                    if (_prefs.trackDoses) ...[
                      const Text(
                        'Cumplimiento',
                        style: TextStyle(
                          color: AppColors.title,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final med in _medications.where((m) => m.active)) ...[
                        _AdherenceCard(
                          medication: med,
                          week: adherenceFor(
                            medication: med,
                            logs: deps!.medicationDoseLogs
                                .forMedicationInRange(
                              med.id,
                              today.subtract(const Duration(days: 6)),
                              today,
                            ),
                            from: today.subtract(const Duration(days: 6)),
                            to: today,
                          ),
                          month: adherenceFor(
                            medication: med,
                            logs: deps.medicationDoseLogs.forMedicationInRange(
                              med.id,
                              today.subtract(const Duration(days: 29)),
                              today,
                            ),
                            from: today.subtract(const Duration(days: 29)),
                            to: today,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                    ],
                    const Text(
                      'Todas',
                      style: TextStyle(
                        color: AppColors.title,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final med in [...activeToday, ...others]) ...[
                      _MedicationTile(
                        medication: med,
                        prefs: _prefs,
                        onOpen: () => _openForm(med),
                        onDelete: () => _delete(med),
                        onRestock: _prefs.trackStock
                            ? () => _restock(med)
                            : null,
                        onDoctorDone: _prefs.doctorRequestReminders &&
                                med.needsDoctorRequestReminder()
                            ? () => _markDoctorDone(med)
                            : null,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({
    required this.medication,
    required this.week,
    required this.month,
  });

  final Medication medication;
  final AdherenceSummary week;
  final AdherenceSummary month;

  String _line(String label, AdherenceSummary summary) {
    final pct = summary.takenPercent;
    if (summary.expected == 0) return '$label: sin tomas previstas';
    final pctText = pct == null ? '—' : '${pct.round()} %';
    return '$label: ${summary.taken}/${summary.expected} ($pctText)';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          medication.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${_line('7 días', week)}\n${_line('30 días', month)}'),
        isThreeLine: true,
      ),
    );
  }
}

class _TodayMedicationCard extends StatelessWidget {
  const _TodayMedicationCard({
    required this.medication,
    required this.day,
    required this.onStatus,
    this.onlyPending = false,
  });

  final Medication medication;

  /// Día de los horarios (medianoche).
  final DateTime day;

  /// «Pendientes de ayer»: oculta los horarios ya marcados.
  final bool onlyPending;
  final void Function(DateTime scheduledAt, DoseStatus status) onStatus;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final now = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              medication.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.title,
              ),
            ),
            if (medication.dose.trim().isNotEmpty)
              Text(
                medication.dose,
                style: const TextStyle(color: AppColors.subtitle),
              ),
            const SizedBox(height: 8),
            for (final minutes in medication.sortedMinutes) ...[
              Builder(
                builder: (context) {
                  final scheduledAt = day.add(Duration(minutes: minutes));
                  final log = deps.medicationDoseLogs.findForSlot(
                    medication.id,
                    scheduledAt,
                  );
                  if (onlyPending && log != null) {
                    return const SizedBox.shrink();
                  }
                  final takenAt = log?.effectiveTakenAt;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            formatClock(minutes),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            takenAt == null
                                ? (log?.status.label ?? 'Pendiente')
                                : '${log!.status.label} '
                                    '${_takenLabel(takenAt, scheduledAt, now)}',
                            style: TextStyle(
                              color: log == null
                                  ? AppColors.subtitle
                                  : log.status == DoseStatus.taken
                                      ? AppColors.ok
                                      : AppColors.warn,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              onStatus(scheduledAt, DoseStatus.taken),
                          child: const Text('Tomado'),
                        ),
                        TextButton(
                          onPressed: () =>
                              onStatus(scheduledAt, DoseStatus.skipped),
                          child: const Text('Omitido'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// «hoy», «ayer» o la fecha.
String dayLabel(DateTime value, DateTime now) {
  final d = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  if (d == today) return 'hoy';
  if (d == today.subtract(const Duration(days: 1))) return 'ayer';
  return formatDayMonth(value);
}

/// Hora real de la toma; con «ayer» o la fecha si no es el día previsto.
String _takenLabel(DateTime takenAt, DateTime scheduledAt, DateTime now) {
  final clock = formatClock(takenAt.hour * 60 + takenAt.minute);
  final sameDay = takenAt.year == scheduledAt.year &&
      takenAt.month == scheduledAt.month &&
      takenAt.day == scheduledAt.day;
  return sameDay ? clock : '${dayLabel(takenAt, now)} $clock';
}

class _MedicationTile extends StatelessWidget {
  const _MedicationTile({
    required this.medication,
    required this.prefs,
    required this.onOpen,
    required this.onDelete,
    this.onRestock,
    this.onDoctorDone,
  });

  final Medication medication;
  final MedicationPreferences prefs;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback? onRestock;
  final VoidCallback? onDoctorDone;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final activeToday = medication.isActiveOn(today);
    final times = medication.sortedMinutes.map(formatClock).join(' · ');
    final lowStock = medication.needsReorder(
      trackStock: prefs.trackStock,
      reorderReminders: prefs.reorderReminders,
    );
    final showDoctor = prefs.doctorRequestReminders;
    final doctorDue =
        showDoctor && medication.needsDoctorRequestReminder(today);
    final doctorDate = medication.doctorRequestDate;
    final doctorStatus =
        showDoctor ? medication.doctorStatusLabel(today) : null;

    final subtitleParts = <String>[
      if (medication.dose.trim().isNotEmpty) medication.dose.trim(),
      if (times.isNotEmpty) times,
      medication.weekdaysLabel,
      'Desde ${formatDate(medication.startDate)}'
          '${medication.endDate == null ? ' · sin fin' : ' · hasta ${formatDate(medication.endDate!)}'}',
      if (prefs.trackStock && medication.stockRemaining != null)
        'Stock ${medication.stockRemaining} (−${medication.unitsPerDose}/toma)',
      if (showDoctor && doctorDate != null)
        doctorDue
            ? 'Pedir al médico · ${formatDate(doctorDate)} · ${medication.doctorRepeatLabel}'
            : 'Médico: ${formatDate(doctorDate)} · ${medication.doctorRepeatLabel}'
                '${medication.effectiveDoctorLeadDays > 0 ? ' · avisa ${medication.effectiveDoctorLeadDays} d antes' : ''}',
      if (!medication.active) 'Inactiva',
      if (medication.active && !activeToday) 'Fuera de vigencia hoy',
    ];

    return Card(
      child: Column(
        children: [
          ListTile(
            onTap: onOpen,
            leading: Icon(
              Icons.medication_outlined,
              color: activeToday ? AppColors.accent : AppColors.subtitle,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    medication.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (doctorStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      doctorDue ? 'Médico' : doctorStatus,
                      style: TextStyle(
                        color: doctorDue ? AppColors.accent : AppColors.subtitle,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (lowStock)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      'Pedir',
                      style: TextStyle(
                        color: AppColors.warn,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(subtitleParts.join('\n')),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRestock != null)
                  IconButton(
                    tooltip: 'Reponer stock',
                    onPressed: onRestock,
                    icon: const Icon(Icons.add_box_outlined),
                  ),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          if (onDoctorDone != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: onDoctorDone,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Ya pedí'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RestockDialog extends StatefulWidget {
  const _RestockDialog({required this.medicationName});

  final String medicationName;

  @override
  State<_RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends State<_RestockDialog> {
  final _controller = TextEditingController(text: '30');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reponer ${widget.medicationName}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Unidades a añadir',
        ),
        onSubmitted: (_) {
          final value = int.tryParse(_controller.text.trim());
          Navigator.pop(context, value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(_controller.text.trim());
            Navigator.pop(context, value);
          },
          child: const Text('Añadir'),
        ),
      ],
    );
  }
}
