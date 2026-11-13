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
import 'medication_doses_screen.dart';
import 'medication_form_screen.dart';
import 'medication_preferences_screen.dart';

enum _MedView { today, list, adherence }

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  List<Medication> _medications = const [];
  MedicationPreferences _prefs = MedicationPreferences.defaults();
  var _ready = false;
  _MedView _view = _MedView.today;

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
      if (!_prefs.trackDoses && _view != _MedView.list) {
        _view = _MedView.list;
      }
    });
  }

  static AdherenceSummary _sumAdherence(Iterable<AdherenceSummary> items) {
    var expected = 0;
    var taken = 0;
    var skipped = 0;
    for (final item in items) {
      expected += item.expected;
      taken += item.taken;
      skipped += item.skipped;
    }
    return AdherenceSummary(
      expected: expected,
      taken: taken,
      skipped: skipped,
    );
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

  Future<void> _clearDose(Medication medication, DateTime scheduledAt) async {
    final deps = AppScope.of(context);
    final current = deps.medications.getById(medication.id) ?? medication;
    final existing = deps.medicationDoseLogs.findForSlot(
      current.id,
      scheduledAt,
    );
    if (existing == null) return;
    await deps.medicationDoseLogs.delete(existing.id);
    if (_prefs.trackStock &&
        existing.status == DoseStatus.taken &&
        current.stockRemaining != null) {
      final units = current.unitsPerDose.clamp(1, 99);
      await deps.medications.save(
        current.copyWith(
          stockRemaining: current.stockRemaining! + units,
          updatedAt: DateTime.now(),
        ),
      );
      await deps.notifications.syncMedicationSchedule(
        medications: deps.medications.getAll(),
        preferences: deps.medicationPreferences.current(),
      );
    }
    if (!mounted) return;
    _reload();
  }

  Future<void> _openDoses(Medication medication) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationDosesScreen(
          medication: medication,
          trackStock: _prefs.trackStock,
        ),
      ),
    );
    if (mounted) _reload();
  }

  /// «Tomado» pide fecha y hora. «Omitir» confirma el horario.
  /// Si el día no es el de la fila, se casa con un horario de ese día.
  Future<void> _onStatus(
    Medication medication,
    DateTime scheduledAt,
    DoseStatus status,
  ) async {
    final existing = AppScope.of(context).medicationDoseLogs.findForSlot(
      medication.id,
      scheduledAt,
    );
    final result = await showDialog<_MarkResult>(
      context: context,
      builder: (context) => status == DoseStatus.taken
          ? _TakenDialog(
              medication: medication,
              scheduledAt: scheduledAt,
              existing: existing,
            )
          : _SkipDialog(
              medication: medication,
              scheduledAt: scheduledAt,
              existing: existing,
            ),
    );
    if (result == null || !mounted) return;
    if (result.clear) {
      await _clearDose(medication, result.slot);
      return;
    }
    await _recordDose(
      medication: medication,
      scheduledAt: result.slot,
      status: status,
      takenAt: result.takenAt,
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
    final trackDoses = _prefs.trackDoses;
    final todaySummary = trackDoses && deps != null
        ? todayAdherence(
            medications: _medications,
            logsFor: (id) =>
                deps.medicationDoseLogs.forMedicationOnDay(id, today),
          )
        : null;
    final activeCount = _medications.where((m) => m.active).length;
    final effectiveView = trackDoses ? _view : _MedView.list;
    final viewSummary = switch (effectiveView) {
      _MedView.today when todaySummary != null =>
        todaySummary.expected == 0
            ? 'Nada previsto hoy'
            : '${todaySummary.taken}/${todaySummary.expected} tomadas'
                '${todaySummary.pending > 0 ? ' · ${todaySummary.pending} pendientes' : ''}',
      _MedView.list =>
        '${_medications.length} '
        '${_medications.length == 1 ? 'medicación' : 'medicaciones'}'
        ' · $activeCount activas',
      _MedView.adherence => '$activeCount activas · últimos 7 y 30 días',
      _MedView.today => '$activeCount activas',
    };

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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (trackDoses)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: SegmentedButton<_MedView>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 4),
                            ),
                            textStyle: WidgetStatePropertyAll(
                              TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          segments: const [
                            ButtonSegment(
                              value: _MedView.today,
                              label: Text('Hoy', maxLines: 1, softWrap: false),
                            ),
                            ButtonSegment(
                              value: _MedView.list,
                              label: Text('Lista', maxLines: 1, softWrap: false),
                            ),
                            ButtonSegment(
                              value: _MedView.adherence,
                              label: _SegmentLabel('Cumplimiento'),
                            ),
                          ],
                          selected: {effectiveView},
                          onSelectionChanged: (selection) {
                            setState(() => _view = selection.first);
                          },
                        ),
                      ),
                    if (!trackDoses || effectiveView != _MedView.today)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          trackDoses ? 0 : 12,
                          20,
                          8,
                        ),
                        child: Text(
                          viewSummary,
                          style: const TextStyle(
                            color: AppColors.subtitle,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Expanded(
                      child: switch (effectiveView) {
                        _MedView.today => _buildTodayTab(
                            pendingYesterday: pendingYesterday,
                            activeToday: activeToday,
                            yesterday: yesterday,
                            today: today,
                          ),
                        _MedView.list => _buildListTab(
                            medications: [...activeToday, ...others],
                          ),
                        _MedView.adherence => _buildAdherenceTab(
                            deps: deps!,
                            today: today,
                          ),
                      },
                    ),
                  ],
                ),
    );
  }

  Widget _buildTodayTab({
    required List<Medication> pendingYesterday,
    required List<Medication> activeToday,
    required DateTime yesterday,
    required DateTime today,
  }) {
    final dayStart = DateTime(today.year, today.month, today.day);
    if (pendingYesterday.isEmpty && activeToday.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Ninguna medicación prevista para hoy. '
            'Revisa fechas y horarios en Lista.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.subtitle),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pendingYesterday.isNotEmpty) ...[
                const _DaySectionHeader(title: 'Ayer'),
                for (var i = 0; i < pendingYesterday.length; i++) ...[
                  if (i > 0) const Divider(height: 8, thickness: 8, color: AppColors.background),
                  _DoseGroup(
                    medication: pendingYesterday[i],
                    day: yesterday,
                    onlyPending: true,
                    onStatus: (scheduledAt, status) => _onStatus(
                      pendingYesterday[i],
                      scheduledAt,
                      status,
                    ),
                  ),
                ],
              ],
              if (activeToday.isNotEmpty) ...[
                if (pendingYesterday.isNotEmpty) const Divider(height: 1),
                const _DaySectionHeader(title: 'Hoy'),
                for (var i = 0; i < activeToday.length; i++) ...[
                  if (i > 0) const Divider(height: 8, thickness: 8, color: AppColors.background),
                  _DoseGroup(
                    medication: activeToday[i],
                    day: dayStart,
                    onStatus: (scheduledAt, status) => _onStatus(
                      activeToday[i],
                      scheduledAt,
                      status,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListTab({required List<Medication> medications}) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
      itemCount: medications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final med = medications[index];
        return _MedicationTile(
          medication: med,
          prefs: _prefs,
          onOpen: () => _openForm(med),
          onDelete: () => _delete(med),
          onRestock: _prefs.trackStock ? () => _restock(med) : null,
          onDoses: _prefs.trackDoses ? () => _openDoses(med) : null,
          onDoctorDone: _prefs.doctorRequestReminders &&
                  med.needsDoctorRequestReminder()
              ? () => _markDoctorDone(med)
              : null,
        );
      },
    );
  }

  Widget _buildAdherenceTab({
    required AppDependencies deps,
    required DateTime today,
  }) {
    final active = _medications.where((m) => m.active).toList();
    if (active.isEmpty) {
      return const Center(
        child: Text(
          'No hay medicaciones activas.',
          style: TextStyle(color: AppColors.subtitle),
        ),
      );
    }
    final weekFrom = today.subtract(const Duration(days: 6));
    final monthFrom = today.subtract(const Duration(days: 29));
    final weekSummaries = <AdherenceSummary>[];
    final monthSummaries = <AdherenceSummary>[];
    for (final med in active) {
      weekSummaries.add(
        adherenceFor(
          medication: med,
          logs: deps.medicationDoseLogs.forMedicationInRange(
            med.id,
            weekFrom,
            today,
          ),
          from: weekFrom,
          to: today,
        ),
      );
      monthSummaries.add(
        adherenceFor(
          medication: med,
          logs: deps.medicationDoseLogs.forMedicationInRange(
            med.id,
            monthFrom,
            today,
          ),
          from: monthFrom,
          to: today,
        ),
      );
    }
    final weekTotal = _sumAdherence(weekSummaries);
    final monthTotal = _sumAdherence(monthSummaries);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _AdherenceStatBlock(
                      label: '7 días',
                      summary: weekTotal,
                    ),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.divider),
                  Expanded(
                    child: _AdherenceStatBlock(
                      label: '30 días',
                      summary: monthTotal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Medicación',
                        style: TextStyle(
                          color: AppColors.subtitle,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '7 d',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: AppColors.subtitle,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '30 d',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: AppColors.subtitle,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              for (var i = 0; i < active.length; i++) ...[
                _AdherenceCompactRow(
                  medication: active[i],
                  week: weekSummaries[i],
                  month: monthSummaries[i],
                ),
                if (i < active.length - 1)
                  const Divider(height: 1, color: AppColors.divider),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AdherenceStatBlock extends StatelessWidget {
  const _AdherenceStatBlock({
    required this.label,
    required this.summary,
  });

  final String label;
  final AdherenceSummary summary;

  @override
  Widget build(BuildContext context) {
    final pct = summary.takenPercent;
    final pctLabel = summary.expected == 0
        ? '—'
        : pct == null
            ? '—'
            : '${pct.round()} %';
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.subtitle,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          pctLabel,
          style: const TextStyle(
            color: AppColors.title,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          summary.expected == 0
              ? 'Sin tomas previstas'
              : '${summary.taken}/${summary.expected}',
          style: const TextStyle(color: AppColors.subtitle, fontSize: 12),
        ),
      ],
    );
  }
}

class _AdherenceCompactRow extends StatelessWidget {
  const _AdherenceCompactRow({
    required this.medication,
    required this.week,
    required this.month,
  });

  final Medication medication;
  final AdherenceSummary week;
  final AdherenceSummary month;

  static String _pctCell(AdherenceSummary summary) {
    if (summary.expected == 0) return '—';
    final pct = summary.takenPercent;
    return pct == null ? '—' : '${pct.round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              medication.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.title,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              _pctCell(week),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              _pctCell(month),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}

class _DaySectionHeader extends StatelessWidget {
  const _DaySectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7FBFD),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.subtitle,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _DoseGroup extends StatelessWidget {
  const _DoseGroup({
    required this.medication,
    required this.day,
    required this.onStatus,
    this.onlyPending = false,
  });

  final Medication medication;
  final DateTime day;
  final bool onlyPending;
  final void Function(DateTime scheduledAt, DoseStatus status) onStatus;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final now = DateTime.now();
    final dose = medication.dose.trim();
    final title = dose.isEmpty ? medication.name : '${medication.name} · $dose';
    final rows = <Widget>[];

    for (final minutes in medication.sortedMinutes) {
      final scheduledAt = day.add(Duration(minutes: minutes));
      final log = deps.medicationDoseLogs.findForSlot(
        medication.id,
        scheduledAt,
      );
      if (onlyPending && log != null) continue;
      final taken = log?.status == DoseStatus.taken;
      rows.add(
        _DoseSlot(
          title: title,
          time: formatClock(minutes),
          detail: log == null
              ? null
              : taken && log.effectiveTakenAt != null
                  ? 'Tomado ${_takenLabel(log.effectiveTakenAt!, scheduledAt, now)}'
                  : log.status.label,
          pending: log == null,
          taken: taken,
          onTaken: () => onStatus(scheduledAt, DoseStatus.taken),
          onSkipped: () => onStatus(scheduledAt, DoseStatus.skipped),
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 64, endIndent: 12),
          rows[i],
        ],
      ],
    );
  }
}

class _DoseSlot extends StatelessWidget {
  const _DoseSlot({
    required this.time,
    required this.pending,
    required this.taken,
    required this.onTaken,
    required this.onSkipped,
    this.title,
    this.detail,
  });

  final String? title;
  final String? detail;
  final String time;
  final bool pending;
  final bool taken;
  final VoidCallback onTaken;
  final VoidCallback onSkipped;

  @override
  Widget build(BuildContext context) {
    final timeColor = pending
        ? AppColors.subtitle
        : taken
            ? AppColors.ok
            : AppColors.warn;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              time,
              style: TextStyle(
                color: timeColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.title,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                if (detail != null)
                  Text(
                    detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: timeColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tomado',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onTaken,
            icon: Icon(
              Icons.check_circle_outline,
              color: taken ? AppColors.ok : AppColors.accent,
            ),
          ),
          IconButton(
            tooltip: 'Omitir',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onSkipped,
            icon: Icon(
              Icons.remove_circle_outline,
              color: !pending && !taken ? AppColors.warn : AppColors.subtitle,
            ),
          ),
        ],
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
    this.onDoses,
    this.onDoctorDone,
  });

  final Medication medication;
  final MedicationPreferences prefs;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback? onRestock;
  final VoidCallback? onDoses;
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

    final primaryLine = [
      if (medication.dose.trim().isNotEmpty) medication.dose.trim(),
      if (times.isNotEmpty) times,
      medication.weekdaysLabel,
    ].join(' · ');

    final statusHints = <String>[
      if (lowStock) 'Pedir stock',
      if (doctorDue && showDoctor) 'Pedir al médico',
      if (!medication.active) 'Inactiva',
      if (medication.active && !activeToday) 'Fuera de vigencia hoy',
      if (prefs.trackStock && medication.stockRemaining != null)
        'Stock ${medication.stockRemaining}',
    ];

    return Card(
      child: ListTile(
        onTap: onOpen,
        leading: Icon(
          Icons.medication_outlined,
          color: activeToday ? AppColors.accent : AppColors.subtitle,
        ),
        title: Text(
          medication.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (primaryLine.isNotEmpty)
              Text(
                primaryLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (statusHints.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                statusHints.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: doctorDue || lowStock
                      ? (doctorDue ? AppColors.accent : AppColors.warn)
                      : AppColors.subtitle,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ] else if (showDoctor && doctorDate != null && doctorStatus != null)
              Text(
                'Médico: ${formatDate(doctorDate)} · $doctorStatus',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.subtitle),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<_MedTileAction>(
          tooltip: 'Acciones',
          onSelected: (action) {
            switch (action) {
              case _MedTileAction.restock:
                onRestock?.call();
              case _MedTileAction.doses:
                onDoses?.call();
              case _MedTileAction.doctorDone:
                onDoctorDone?.call();
              case _MedTileAction.delete:
                onDelete();
            }
          },
          itemBuilder: (context) => [
            if (onDoses != null)
              const PopupMenuItem(
                value: _MedTileAction.doses,
                child: Text('Tomas'),
              ),
            if (onRestock != null)
              const PopupMenuItem(
                value: _MedTileAction.restock,
                child: Text('Reponer stock'),
              ),
            if (onDoctorDone != null)
              const PopupMenuItem(
                value: _MedTileAction.doctorDone,
                child: Text('Ya pedí al médico'),
              ),
            const PopupMenuItem(
              value: _MedTileAction.delete,
              child: Text('Eliminar'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MedTileAction { doses, restock, doctorDone, delete }

class _MarkResult {
  const _MarkResult({required this.slot, this.clear = false, this.takenAt});

  final DateTime slot;
  final bool clear;
  final DateTime? takenAt;
}

class _SlotMatch {
  const _SlotMatch._({this.slot, this.options = const []});

  final DateTime? slot;
  final List<DateTime> options;

  bool get none => slot == null && options.isEmpty;
  bool get ambiguous => options.length > 1;

  factory _SlotMatch.single(DateTime slot) => _SlotMatch._(slot: slot);
  factory _SlotMatch.none() => const _SlotMatch._();
  factory _SlotMatch.ambiguous(List<DateTime> options) =>
      _SlotMatch._(options: options);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _minuteDistance(DateTime slot, int targetMinutes) {
  return (slot.hour * 60 + slot.minute - targetMinutes).abs();
}

/// Si [byClock] y el día es el de la fila, se queda ese horario.
/// En otro día, busca el horario previsto más cercano.
_SlotMatch _matchDoseSlot({
  required Medication medication,
  required DateTime scheduledAt,
  required DateTime when,
  required bool byClock,
}) {
  final rowDay = _dateOnly(scheduledAt);
  final whenDay = _dateOnly(when);
  if (rowDay == whenDay) return _SlotMatch.single(scheduledAt);
  if (!medication.isActiveOn(whenDay)) return _SlotMatch.none();
  final slots = [
    for (final minutes in medication.sortedMinutes)
      whenDay.add(Duration(minutes: minutes)),
  ];
  if (slots.isEmpty) return _SlotMatch.none();
  if (!byClock || slots.length == 1) {
    return slots.length == 1
        ? _SlotMatch.single(slots.first)
        : _SlotMatch.ambiguous(slots);
  }
  final target = when.hour * 60 + when.minute;
  final ranked = [...slots]..sort(
      (a, b) => _minuteDistance(a, target).compareTo(_minuteDistance(b, target)),
    );
  final gap = _minuteDistance(ranked[1], target) - _minuteDistance(ranked.first, target);
  if (gap < 90) return _SlotMatch.ambiguous(ranked);
  return _SlotMatch.single(ranked.first);
}

class _TakenDialog extends StatefulWidget {
  const _TakenDialog({
    required this.medication,
    required this.scheduledAt,
    required this.existing,
  });

  final Medication medication;
  final DateTime scheduledAt;
  final MedicationDoseLog? existing;

  @override
  State<_TakenDialog> createState() => _TakenDialogState();
}

class _TakenDialogState extends State<_TakenDialog> {
  late DateTime _when;
  DateTime? _pickedSlot;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final taken = widget.existing?.effectiveTakenAt;
    _when = taken == null
        ? DateTime(now.year, now.month, now.day, now.hour, now.minute)
        : DateTime(taken.year, taken.month, taken.day, taken.hour, taken.minute);
    if (_when.isAfter(now)) _when = now;
  }

  DateTime get _now => DateTime.now();

  DateTime get _firstDay {
    final start = widget.medication.startDate;
    final back = _now.subtract(const Duration(days: 30));
    final floor = DateTime(start.year, start.month, start.day);
    final limit = DateTime(back.year, back.month, back.day);
    return floor.isAfter(limit) ? floor : limit;
  }

  _SlotMatch get _match => _matchDoseSlot(
        medication: widget.medication,
        scheduledAt: widget.scheduledAt,
        when: _when,
        byClock: true,
      );

  DateTime? get _slot {
    final match = _match;
    if (match.ambiguous) return _pickedSlot;
    return match.slot;
  }

  Future<void> _pickDate() async {
    final now = _now;
    final date = await showDatePicker(
      context: context,
      initialDate: _when.isAfter(now) ? now : _when,
      firstDate: _firstDay,
      lastDate: now,
    );
    if (date == null) return;
    setState(() {
      _pickedSlot = null;
      _when = DateTime(date.year, date.month, date.day, _when.hour, _when.minute);
      if (_when.isAfter(now)) {
        _when = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      }
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null) return;
    final now = _now;
    setState(() {
      _pickedSlot = null;
      var next = DateTime(
        _when.year,
        _when.month,
        _when.day,
        time.hour,
        time.minute,
      );
      if (next.isAfter(now)) next = now;
      _when = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final match = _match;
    final slot = _slot;
    final logs = AppScope.of(context).medicationDoseLogs;
    final marked = slot == null ? null : logs.findForSlot(widget.medication.id, slot);
    final replacesOther = marked != null &&
        marked.scheduledAt.millisecondsSinceEpoch !=
            widget.scheduledAt.millisecondsSinceEpoch;
    final canSave = slot != null;

    return AlertDialog(
      title: Text(widget.medication.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Prevista ${dayLabel(widget.scheduledAt, now)} '
              '${formatClock(widget.scheduledAt.hour * 60 + widget.scheduledAt.minute)}',
              style: const TextStyle(color: AppColors.subtitle),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateTimeField(
                    label: 'Fecha',
                    value: formatDate(_when),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DateTimeField(
                    label: 'Hora',
                    value: formatClock(_when.hour * 60 + _when.minute),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  _pickedSlot = null;
                  _when = DateTime(now.year, now.month, now.day, now.hour, now.minute);
                }),
                child: const Text('Ahora'),
              ),
            ),
            if (match.none)
              const Text(
                'Ese día no le toca esta medicación.',
                style: TextStyle(color: AppColors.warn, fontWeight: FontWeight.w600),
              )
            else if (match.ambiguous) ...[
              const Text(
                '¿Qué horario?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in match.options)
                    ChoiceChip(
                      label: Text(
                        formatClock(option.hour * 60 + option.minute),
                      ),
                      selected: _pickedSlot == option,
                      onSelected: (_) => setState(() => _pickedSlot = option),
                    ),
                ],
              ),
            ] else if (slot != null)
              Text(
                'Se anotará en ${dayLabel(slot, now)} '
                '${formatClock(slot.hour * 60 + slot.minute)}',
                style: const TextStyle(color: AppColors.subtitle),
              ),
            if (replacesOther) ...[
              const SizedBox(height: 8),
              const Text(
                'Ese horario ya está marcado. Al guardar se sustituye.',
                style: TextStyle(color: AppColors.warn, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (marked != null)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              _MarkResult(slot: slot!, clear: true),
            ),
            child: const Text('Quitar marca'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: canSave
              ? () => Navigator.pop(
                    context,
                    _MarkResult(slot: slot, takenAt: _when),
                  )
              : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _SkipDialog extends StatefulWidget {
  const _SkipDialog({
    required this.medication,
    required this.scheduledAt,
    required this.existing,
  });

  final Medication medication;
  final DateTime scheduledAt;
  final MedicationDoseLog? existing;

  @override
  State<_SkipDialog> createState() => _SkipDialogState();
}

class _SkipDialogState extends State<_SkipDialog> {
  late DateTime _day;
  DateTime? _pickedSlot;

  @override
  void initState() {
    super.initState();
    _day = _dateOnly(widget.scheduledAt);
  }

  DateTime get _now => DateTime.now();

  DateTime get _firstDay {
    final start = widget.medication.startDate;
    final back = _now.subtract(const Duration(days: 30));
    final floor = DateTime(start.year, start.month, start.day);
    final limit = DateTime(back.year, back.month, back.day);
    return floor.isAfter(limit) ? floor : limit;
  }

  _SlotMatch get _match => _matchDoseSlot(
        medication: widget.medication,
        scheduledAt: widget.scheduledAt,
        when: _day,
        byClock: false,
      );

  DateTime? get _slot {
    final match = _match;
    if (match.ambiguous) return _pickedSlot;
    return match.slot;
  }

  Future<void> _pickDate() async {
    final now = _now;
    final date = await showDatePicker(
      context: context,
      initialDate: _day.isAfter(now) ? now : _day,
      firstDate: _firstDay,
      lastDate: now,
    );
    if (date == null) return;
    setState(() {
      _pickedSlot = null;
      _day = DateTime(date.year, date.month, date.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final match = _match;
    final slot = _slot;
    final marked = slot == null
        ? null
        : AppScope.of(context).medicationDoseLogs.findForSlot(
              widget.medication.id,
              slot,
            );
    final replacesOther = marked != null &&
        marked.scheduledAt.millisecondsSinceEpoch !=
            widget.scheduledAt.millisecondsSinceEpoch;

    return AlertDialog(
      title: Text('Omitir · ${widget.medication.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DateTimeField(
            label: 'Día',
            value: '${dayLabel(_day, now)} · ${formatDate(_day)}',
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          if (match.none)
            const Text(
              'Ese día no le toca esta medicación.',
              style: TextStyle(color: AppColors.warn, fontWeight: FontWeight.w600),
            )
          else if (match.ambiguous) ...[
            const Text(
              '¿Qué horario?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in match.options)
                  ChoiceChip(
                    label: Text(formatClock(option.hour * 60 + option.minute)),
                    selected: _pickedSlot == option,
                    onSelected: (_) => setState(() => _pickedSlot = option),
                  ),
              ],
            ),
          ] else if (slot != null)
            Text(
              'Se omitirá la de ${dayLabel(slot, now)} '
              '${formatClock(slot.hour * 60 + slot.minute)}',
              style: const TextStyle(color: AppColors.subtitle),
            ),
          if (replacesOther) ...[
            const SizedBox(height: 8),
            const Text(
              'Ese horario ya está marcado. Al guardar se sustituye.',
              style: TextStyle(color: AppColors.warn, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
      actions: [
        if (marked != null)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              _MarkResult(slot: slot!, clear: true),
            ),
            child: const Text('Quitar marca'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: slot == null
              ? null
              : () => Navigator.pop(
                    context,
                    _MarkResult(slot: slot),
                  ),
          child: const Text('Omitir'),
        ),
      ],
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value,
          style: const TextStyle(
            color: AppColors.title,
            fontWeight: FontWeight.w700,
          ),
        ),
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
