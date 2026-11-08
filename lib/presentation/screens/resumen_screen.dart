import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/blood_pressure_model.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_preferences.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/medication_adherence.dart';
import '../widgets/export_report_flow.dart';
import '../widgets/reference_badge.dart';
import '../widgets/salud_amg_app_bar.dart';
import 'history_screen.dart';
import 'measurement_form_screen.dart';
import 'medications_screen.dart';

enum _ChartMetric { pressure, pulse, weight, glucose, steps, oxygen }

enum _ChartPeriod { days7, days30, days90 }

class ResumenScreen extends StatefulWidget {
  const ResumenScreen({super.key});

  @override
  State<ResumenScreen> createState() => _ResumenScreenState();
}

class _ResumenScreenState extends State<ResumenScreen> {
  UserProfile? _profile;
  List<BloodPressureModel> _readings = const [];
  List<Medication> _medications = const [];
  MedicationPreferences _medPrefs = MedicationPreferences.defaults();
  _ChartMetric _metric = _ChartMetric.pressure;
  _ChartPeriod _period = _ChartPeriod.days30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reload();
    });
  }




  void _reload() {
    if (!mounted) return;
    final deps = AppScope.of(context);
    setState(() {
      _profile = deps.profiles.current();
      _readings = deps.measurements.getAll();
      _medications = deps.medications.getAll();
      _medPrefs = deps.medicationPreferences.current();
    });
  }

  Future<void> _openMeasurement([BloodPressureModel? existing]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MeasurementFormScreen(existing: existing)),
    );
    if (saved == true) _reload();
  }




  Future<void> _openHistory() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
    if (mounted) _reload();
  }

  Future<void> _openMedications() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const MedicationsScreen()),
    );
    if (mounted) _reload();
  }

  List<Medication> get _doctorDueMedications {
    if (!_medPrefs.doctorRequestReminders) return const [];
    final today = DateTime.now();
    return _medications
        .where((med) => med.needsDoctorRequestReminder(today))
        .toList()
      ..sort((a, b) {
        final aDate = a.doctorRequestDate ?? today;
        final bDate = b.doctorRequestDate ?? today;
        return aDate.compareTo(bDate);
      });
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






  Future<void> _export({required bool pdf}) =>
      startReportExport(context, pdf: pdf);


  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final today = DateTime.now();
    final todaySummary = todayAdherence(
      medications: _medications,
      logsFor: (id) =>
          AppScope.of(context).medicationDoseLogs.forMedicationOnDay(id, today),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SaludAmgAppBar(
        section: 'Resumen',
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (value) {
              switch (value) {
                case 'excel':
                  _export(pdf: false);
                case 'pdf':
                  _export(pdf: true);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'excel',
                child: Text('Exportar Excel'),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: Text('Exportar PDF'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_medPrefs.showHomeButton) ...[
            FloatingActionButton.extended(
              heroTag: 'fab_medication',
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              onPressed: _openMedications,
              icon: const Icon(Icons.medication_outlined),
              label: const Text('Medicación'),
            ),
            const SizedBox(width: 12),
          ],
          FloatingActionButton.extended(
            heroTag: 'fab_measurement',
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: () => _openMeasurement(),
            icon: const Icon(Icons.add),
            label: const Text('Medición'),
          ),
        ],
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : _readings.isEmpty && _medications.isEmpty
              ? _EmptyHome(onAdd: () => _openMeasurement())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  children: [
                    if (_doctorDueMedications.isNotEmpty) ...[
                      _DoctorRequestHomeCard(
                        medications: _doctorDueMedications,
                        onOpenList: _openMedications,
                        onMarkDone: _markDoctorDone,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_readings.isNotEmpty) ...[
                      _LatestCard(
                        profile: profile,
                        reading: _readings.first,
                        onOpen: () => _openMeasurement(_readings.first),
                      ),
                      const SizedBox(height: 12),
                      _TrendCard(
                        readings: _readings,
                        metric: _metric,
                        period: _period,
                        onMetric: (metric) => setState(() => _metric = metric),
                        onPeriod: (period) => setState(() => _period = period),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_medPrefs.trackDoses &&
                        todaySummary.expected > 0) ...[
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.medication_outlined,
                            color: AppColors.accent,
                          ),
                          title: const Text(
                            'Medicación de hoy',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${todaySummary.taken}/${todaySummary.expected} tomadas'
                            '${todaySummary.pending > 0 ? ' · ${todaySummary.pending} pendientes' : ''}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openMedications,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.history,
                          color: AppColors.accent,
                        ),
                        title: const Text(
                          'Historial',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${_readings.length} '
                          '${_readings.length == 1 ? 'medición' : 'mediciones'} · filtrar por periodo',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openHistory,
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 96),
      children: [
        Icon(
          Icons.monitor_heart_outlined,
          size: 56,
          color: AppColors.accent.withValues(alpha: 0.85),
        ),
        const SizedBox(height: 20),
        const Text(
          'Todavía no hay mediciones',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.title,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Anota la primera a mano o impórtala desde Apple Salud o Health Connect.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.subtitle, fontSize: 15, height: 1.35),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onAdd, child: const Text('Añadir medición')),
      ],
    );
  }
}

class _DoctorRequestHomeCard extends StatelessWidget {
  const _DoctorRequestHomeCard({
    required this.medications,
    required this.onOpenList,
    required this.onMarkDone,
  });

  final List<Medication> medications;
  final VoidCallback onOpenList;
  final Future<void> Function(Medication medication) onMarkDone;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              onTap: onOpenList,
              leading: const Icon(
                Icons.medical_services_outlined,
                color: AppColors.accent,
              ),
              title: const Text(
                'Pedir al médico',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                medications.length == 1
                    ? 'Toca para ver en Medicaciones'
                    : '${medications.length} medicaciones pendientes',
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
            for (final med in medications)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            [
                              if (med.doctorRequestDate != null)
                                'Objetivo ${formatDate(med.doctorRequestDate!)}',
                              med.doctorStatusLabel() ?? 'Pedir',
                            ].join(' · '),
                            style: const TextStyle(
                              color: AppColors.subtitle,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => onMarkDone(med),
                      child: const Text('Ya pedí'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LatestCard extends StatelessWidget {
  const _LatestCard({
    required this.profile,
    required this.reading,
    required this.onOpen,
  });

  final UserProfile profile;
  final BloodPressureModel reading;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Última toma', style: TextStyle(color: AppColors.subtitle)),
              const SizedBox(height: 4),
              Text(
                reading.hasPressure
                    ? '${reading.pressureLabel} mmHg'
                    : reading.pressureLabel,
                style: const TextStyle(
                  color: AppColors.title,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  ...reading.extraChips.take(4),
                  formatDateTime(reading.measuredAt),
                ].join(' · '),
                style: const TextStyle(color: AppColors.subtitle),
              ),
              const SizedBox(height: 8),
              ReferenceBadge(level: profile.levelFor(reading)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendCard extends StatefulWidget {
  const _TrendCard({
    required this.readings,
    required this.metric,
    required this.period,
    required this.onMetric,
    required this.onPeriod,
  });

  final List<BloodPressureModel> readings;
  final _ChartMetric metric;
  final _ChartPeriod period;
  final ValueChanged<_ChartMetric> onMetric;
  final ValueChanged<_ChartPeriod> onPeriod;

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  var _filtersOpen = false;

  int get _days => switch (widget.period) {
        _ChartPeriod.days7 => 7,
        _ChartPeriod.days30 => 30,
        _ChartPeriod.days90 => 90,
      };

  String get _periodLabel => switch (widget.period) {
        _ChartPeriod.days7 => '7 días',
        _ChartPeriod.days30 => '30 días',
        _ChartPeriod.days90 => '90 días',
      };

  String get _metricLabel => switch (widget.metric) {
        _ChartMetric.pressure => 'Tensión',
        _ChartMetric.pulse => 'Pulso',
        _ChartMetric.weight => 'Peso',
        _ChartMetric.glucose => 'Glucosa',
        _ChartMetric.steps => 'Pasos',
        _ChartMetric.oxygen => 'O₂',
      };

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(Duration(days: _days));
    final filtered = widget.readings
        .where((reading) => !reading.measuredAt.isBefore(cutoff))
        .toList();
    final series = filtered.reversed.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evolución',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.title,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Comparado con tu referencia, no es un diagnóstico.',
                        style: TextStyle(
                          color: AppColors.subtitle,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Filtros',
                  onPressed: () =>
                      setState(() => _filtersOpen = !_filtersOpen),
                  icon: Icon(
                    _filtersOpen ? Icons.tune : Icons.tune_outlined,
                    color: _filtersOpen ? AppColors.accent : AppColors.primary,
                  ),
                ),
              ],
            ),
            if (!_filtersOpen)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '$_periodLabel · $_metricLabel',
                  style: const TextStyle(
                    color: AppColors.subtitle,
                    fontSize: 12,
                  ),
                ),
              ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  SegmentedButton<_ChartPeriod>(
                    segments: const [
                      ButtonSegment(
                        value: _ChartPeriod.days7,
                        label: Text('7 d'),
                      ),
                      ButtonSegment(
                        value: _ChartPeriod.days30,
                        label: Text('30 d'),
                      ),
                      ButtonSegment(
                        value: _ChartPeriod.days90,
                        label: Text('90 d'),
                      ),
                    ],
                    selected: {widget.period},
                    onSelectionChanged: (selection) =>
                        widget.onPeriod(selection.first),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_ChartMetric>(
                      segments: const [
                        ButtonSegment(
                          value: _ChartMetric.pressure,
                          label: Text('Tensión'),
                        ),
                        ButtonSegment(
                          value: _ChartMetric.pulse,
                          label: Text('Pulso'),
                        ),
                        ButtonSegment(
                          value: _ChartMetric.weight,
                          label: Text('Peso'),
                        ),
                        ButtonSegment(
                          value: _ChartMetric.glucose,
                          label: Text('Glucosa'),
                        ),
                        ButtonSegment(
                          value: _ChartMetric.steps,
                          label: Text('Pasos'),
                        ),
                        ButtonSegment(
                          value: _ChartMetric.oxygen,
                          label: Text('O₂'),
                        ),
                      ],
                      selected: {widget.metric},
                      onSelectionChanged: (selection) =>
                          widget.onMetric(selection.first),
                    ),
                  ),
                ],
              ),
              crossFadeState: _filtersOpen
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeInOut,
            ),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: _chart(series)),
            if (_averagesLabel(series) != null) ...[
              const SizedBox(height: 12),
              Text(
                _averagesLabel(series)!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.subtitle,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _averagesLabel(List<BloodPressureModel> series) {
    switch (widget.metric) {
      case _ChartMetric.pressure:
        final sys = [
          for (final r in series)
            if (r.systolic != null) r.systolic!.toDouble(),
        ];
        final dia = [
          for (final r in series)
            if (r.diastolic != null) r.diastolic!.toDouble(),
        ];
        if (sys.isEmpty && dia.isEmpty) return null;
        final parts = <String>[];
        if (sys.isNotEmpty) {
          parts.add('Sist. media ${_avg(sys).round()}');
        }
        if (dia.isNotEmpty) {
          parts.add('Diast. media ${_avg(dia).round()}');
        }
        return parts.join(' · ');
      case _ChartMetric.pulse:
        final values = [
          for (final r in series)
            if ((r.pulse ?? r.restingPulse) != null)
              (r.pulse ?? r.restingPulse)!.toDouble(),
        ];
        if (values.isEmpty) return null;
        return 'Media ${_avg(values).round()} lpm';
      case _ChartMetric.weight:
        final values = [
          for (final r in series)
            if (r.weightKg != null) r.weightKg!,
        ];
        if (values.isEmpty) return null;
        return 'Media ${formatWeight(_avg(values))} kg';
      case _ChartMetric.glucose:
        final values = [
          for (final r in series)
            if (r.glucoseMgDl != null) r.glucoseMgDl!,
        ];
        if (values.isEmpty) return null;
        return 'Media ${formatWeight(_avg(values))} mg/dL';
      case _ChartMetric.steps:
        final values = [
          for (final r in series)
            if (r.steps != null) r.steps!.toDouble(),
        ];
        if (values.isEmpty) return null;
        return 'Media ${_avg(values).round()} pasos';
      case _ChartMetric.oxygen:
        final values = [
          for (final r in series)
            if (r.oxygenSaturation != null) r.oxygenSaturation!,
        ];
        if (values.isEmpty) return null;
        return 'Media ${formatWeight(_avg(values))} %';
    }
  }

  double _avg(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;

  Widget _chart(List<BloodPressureModel> series) {
    final metric = widget.metric;
    final lines = switch (metric) {
      _ChartMetric.pressure => [
          _line(
            series,
            AppColors.systolic,
            (reading) => reading.systolic?.toDouble(),
          ),
          _line(
            series,
            AppColors.diastolic,
            (reading) => reading.diastolic?.toDouble(),
          ),
        ],
      _ChartMetric.pulse => [
          _line(
            series,
            AppColors.accent,
            (reading) => (reading.pulse ?? reading.restingPulse)?.toDouble(),
          ),
        ],
      _ChartMetric.weight => [
          _line(series, AppColors.primary, (reading) => reading.weightKg),
        ],
      _ChartMetric.glucose => [
          _line(series, AppColors.warn, (reading) => reading.glucoseMgDl),
        ],
      _ChartMetric.steps => [
          _line(
            series,
            AppColors.appBarSection,
            (reading) => reading.steps?.toDouble(),
          ),
        ],
      _ChartMetric.oxygen => [
          _line(
            series,
            AppColors.diastolic,
            (reading) => reading.oxygenSaturation,
          ),
        ],
    };
    final spots = lines.expand((line) => line.spots).toList();
    final distinctPoints = spots.map((spot) => spot.x.round()).toSet();
    if (distinctPoints.length < 2) {
      return const Center(
        child: Text(
          'Hacen falta al menos dos datos para la gráfica.',
          style: TextStyle(color: AppColors.subtitle),
          textAlign: TextAlign.center,
        ),
      );
    }
    final values = spots.map((spot) => spot.y);
    var minY = values.reduce(math.min) - 8;
    var maxY = values.reduce(math.max) + 8;
    if (maxY - minY < 16) {
      minY -= 8;
      maxY += 8;
    }
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.primary,
            getTooltipItems: (touchedSpots) {
              if (touchedSpots.isEmpty) return [];
              final index = touchedSpots.first.x.round();
              final dateLabel = (index >= 0 && index < series.length)
                  ? formatDateTime(series[index].measuredAt)
                  : '';
              return [
                for (var i = 0; i < touchedSpots.length; i++)
                  LineTooltipItem(
                    i == 0 && dateLabel.isNotEmpty
                        ? '$dateLabel\n${_tooltipValue(touchedSpots[i])}'
                        : _tooltipValue(touchedSpots[i]),
                    TextStyle(
                      color: touchedSpots[i].bar.color ?? Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
              ];
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: ((maxY - minY) / 4).clamp(1, 1000),
              getTitlesWidget: (value, meta) => Text(
                value.round().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.subtitle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index != 0 && index != series.length - 1) {
                  return const SizedBox.shrink();
                }
                if (index < 0 || index >= series.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  formatDayMonth(series[index].measuredAt),
                  style: const TextStyle(fontSize: 10, color: AppColors.subtitle),
                );
              },
            ),
          ),
        ),
        lineBarsData: lines,
      ),
    );
  }

  String _tooltipValue(LineBarSpot spot) {
    final y = spot.y;
    final label = switch (widget.metric) {
      _ChartMetric.pressure => spot.barIndex == 0 ? 'Sist.' : 'Diast.',
      _ChartMetric.pulse => 'Pulso',
      _ChartMetric.weight => 'Peso',
      _ChartMetric.glucose => 'Glucosa',
      _ChartMetric.steps => 'Pasos',
      _ChartMetric.oxygen => 'O₂',
    };
    final value = switch (widget.metric) {
      _ChartMetric.weight ||
      _ChartMetric.glucose ||
      _ChartMetric.oxygen =>
        formatWeight(y),
      _ => y.round().toString(),
    };
    return '$label $value';
  }

  LineChartBarData _line(
    List<BloodPressureModel> series,
    Color color,
    double? Function(BloodPressureModel reading) read,
  ) {
    final spots = <FlSpot>[];
    for (var i = 0; i < series.length; i++) {
      final value = read(series[i]);
      if (value != null) spots.add(FlSpot(i.toDouble(), value));
    }
    return LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 2.5,
      dotData: const FlDotData(show: false),
    );
  }
}
