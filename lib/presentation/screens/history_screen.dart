import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/blood_pressure_model.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/enums/health_enums.dart';
import '../widgets/export_report_flow.dart';
import '../widgets/reading_tile.dart';
import '../widgets/salud_amg_app_bar.dart';
import 'measurement_form_screen.dart';

enum _PeriodFilter { all, days7, days30, custom }

enum _AlertFilter { all, above, below, none }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  UserProfile? _profile;
  List<BloodPressureModel> _readings = const [];

  _PeriodFilter _period = _PeriodFilter.days30;
  DateTimeRange? _customRange;
  MeasurementContext? _context;
  ReadingOrigin? _origin;
  _AlertFilter _alert = _AlertFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() {
    if (!mounted) return;
    final deps = AppScope.of(context);
    setState(() {
      _profile = deps.profiles.current();
      _readings = deps.measurements.getAll();
    });
  }

  List<BloodPressureModel> get _filtered {
    final now = DateTime.now();
    final profile = _profile;
    return _readings.where((reading) {
      if (!_matchesPeriod(reading.measuredAt, now)) return false;
      if (_context != null && reading.context != _context) return false;
      if (_origin != null && reading.syncInfo.origin != _origin) return false;
      if (profile != null && !_matchesAlert(profile, reading)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Periodo del filtro actual, para proponerlo al exportar.
  DateTimeRange? get _periodRange {
    final now = DateTime.now();
    return switch (_period) {
      _PeriodFilter.all => null,
      _PeriodFilter.days7 => DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        ),
      _PeriodFilter.days30 => DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        ),
      _PeriodFilter.custom => _customRange,
    };
  }

  bool _matchesPeriod(DateTime at, DateTime now) {
    switch (_period) {
      case _PeriodFilter.all:
        return true;
      case _PeriodFilter.days7:
        return !at.isBefore(now.subtract(const Duration(days: 7)));
      case _PeriodFilter.days30:
        return !at.isBefore(now.subtract(const Duration(days: 30)));
      case _PeriodFilter.custom:
        final range = _customRange;
        if (range == null) return true;
        return !at.isBefore(range.start) && !at.isAfter(range.end);
    }
  }

  bool _matchesAlert(UserProfile profile, BloodPressureModel reading) {
    return switch (_alert) {
      _AlertFilter.all => true,
      // Incluye lecturas mixtas (p. ej. sisto alta y diasto baja).
      _AlertFilter.above => profile.isAbove(reading),
      _AlertFilter.below => profile.isBelow(reading),
      // Sin aviso: en rango o no evaluable (solo peso/glucosa…).
      _AlertFilter.none =>
        !profile.isAbove(reading) && !profile.isBelow(reading),
    };
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = _customRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 14)),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: initial.start,
        end: initial.end.isAfter(now) ? now : initial.end,
      ),
      locale: const Locale('es', 'ES'),
      helpText: 'Periodo del historial',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _period = _PeriodFilter.custom;
      _customRange = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        ),
      );
    });
  }

  Future<void> _openMeasurement(BloodPressureModel reading) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MeasurementFormScreen(existing: reading)),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(BloodPressureModel reading) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar medición'),
        content: Text('Se borrará la toma del ${formatDateTime(reading.measuredAt)}.'),
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
    await AppScope.of(context).measurements.delete(reading.id);
    _reload();
  }

  bool get _hasActiveFilters =>
      _period != _PeriodFilter.days30 ||
      _context != null ||
      _origin != null ||
      _alert != _AlertFilter.all;

  String get _filterSummary {
    final parts = <String>[];
    parts.add(switch (_period) {
      _PeriodFilter.all => 'Todo',
      _PeriodFilter.days7 => '7 días',
      _PeriodFilter.days30 => '30 días',
      _PeriodFilter.custom => _customRange == null
          ? 'Personalizado'
          : '${formatDate(_customRange!.start)} – ${formatDate(_customRange!.end)}',
    });
    if (_context != null) parts.add(_context!.label);
    if (_origin != null) parts.add(_origin!.label);
    if (_alert != _AlertFilter.all) {
      parts.add(switch (_alert) {
        _AlertFilter.above => 'Por encima',
        _AlertFilter.below => 'Por debajo',
        _AlertFilter.none => 'Sin aviso',
        _AlertFilter.all => '',
      });
    }
    return parts.join(' · ');
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            void apply(VoidCallback update) {
              setState(update);
              setSheet(() {});
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Text(
                        'Filtros',
                        style: TextStyle(
                          color: AppColors.title,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _FilterPanel(
                      period: _period,
                      customRange: _customRange,
                      contextFilter: _context,
                      origin: _origin,
                      alert: _alert,
                      onPeriod: (value) {
                        if (value == _PeriodFilter.custom) {
                          Navigator.pop(sheetContext);
                          _pickCustomRange();
                          return;
                        }
                        apply(() {
                          _period = value;
                          if (value != _PeriodFilter.custom) {
                            _customRange = null;
                          }
                        });
                      },
                      onCustomTap: () {
                        Navigator.pop(sheetContext);
                        _pickCustomRange();
                      },
                      onContext: (value) => apply(() => _context = value),
                      onOrigin: (value) => apply(() => _origin = value),
                      onAlert: (value) => apply(() => _alert = value),
                    ),
                    if (_hasActiveFilters)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: OutlinedButton.icon(
                          onPressed: () => apply(() {
                            _period = _PeriodFilter.days30;
                            _customRange = null;
                            _context = null;
                            _origin = null;
                            _alert = _AlertFilter.all;
                          }),
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('Quitar filtros'),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SaludAmgAppBar(
        section: 'Historial',
        actions: [
          IconButton(
            tooltip: 'Filtros',
            onPressed: _openFilters,
            icon: Icon(
              _hasActiveFilters ? Icons.tune : Icons.tune_outlined,
              color: _hasActiveFilters ? AppColors.accent : null,
            ),
          ),
          PopupMenuButton<bool>(
            tooltip: 'Exportar informe',
            icon: const Icon(Icons.ios_share),
            onSelected: (pdf) => startReportExport(
              context,
              pdf: pdf,
              initialRange: _periodRange,
            ),
            itemBuilder: (context) => const [
              PopupMenuItem(value: false, child: Text('Exportar Excel')),
              PopupMenuItem(value: true, child: Text('Exportar PDF')),
            ],
          ),
        ],
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    filtered.isEmpty
                        ? 'Ninguna medición · $_filterSummary'
                        : '${filtered.length} '
                            '${filtered.length == 1 ? 'medición' : 'mediciones'}'
                            ' · $_filterSummary',
                    style: const TextStyle(
                      color: AppColors.subtitle,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Prueba otro periodo o quita algún filtro.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.subtitle),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final reading = filtered[index];
                            return ReadingTile(
                              reading: reading,
                              profile: profile,
                              onOpen: () => _openMeasurement(reading),
                              onDelete: () => _delete(reading),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.period,
    required this.customRange,
    required this.contextFilter,
    required this.origin,
    required this.alert,
    required this.onPeriod,
    required this.onCustomTap,
    required this.onContext,
    required this.onOrigin,
    required this.onAlert,
  });

  final _PeriodFilter period;
  final DateTimeRange? customRange;
  final MeasurementContext? contextFilter;
  final ReadingOrigin? origin;
  final _AlertFilter alert;
  final ValueChanged<_PeriodFilter> onPeriod;
  final VoidCallback onCustomTap;
  final ValueChanged<MeasurementContext?> onContext;
  final ValueChanged<ReadingOrigin?> onOrigin;
  final ValueChanged<_AlertFilter> onAlert;

  @override
  Widget build(BuildContext context) {
    final customLabel = customRange == null
        ? 'Personalizado'
        : '${formatDate(customRange!.start)} – ${formatDate(customRange!.end)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          const Text(
            'Periodo',
            style: TextStyle(
              color: AppColors.subtitle,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  label: 'Todo',
                  selected: period == _PeriodFilter.all,
                  onTap: () => onPeriod(_PeriodFilter.all),
                ),
                _chip(
                  label: '7 días',
                  selected: period == _PeriodFilter.days7,
                  onTap: () => onPeriod(_PeriodFilter.days7),
                ),
                _chip(
                  label: '30 días',
                  selected: period == _PeriodFilter.days30,
                  onTap: () => onPeriod(_PeriodFilter.days30),
                ),
                _chip(
                  label: customLabel,
                  selected: period == _PeriodFilter.custom,
                  onTap: () {
                    if (period == _PeriodFilter.custom) {
                      onCustomTap();
                    } else {
                      onPeriod(_PeriodFilter.custom);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Momento',
              style: TextStyle(
                color: AppColors.subtitle,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  label: 'Todos',
                  selected: contextFilter == null,
                  onTap: () => onContext(null),
                ),
                for (final value in MeasurementContext.values)
                  if (value != MeasurementContext.unspecified)
                    _chip(
                      label: value.label,
                      selected: contextFilter == value,
                      onTap: () => onContext(value),
                    ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Origen y aviso',
              style: TextStyle(
                color: AppColors.subtitle,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  label: 'Cualquier origen',
                  selected: origin == null,
                  onTap: () => onOrigin(null),
                ),
                _chip(
                  label: 'Manual',
                  selected: origin == ReadingOrigin.manual,
                  onTap: () => onOrigin(ReadingOrigin.manual),
                ),
                _chip(
                  label: 'Importado',
                  selected: origin == ReadingOrigin.imported,
                  onTap: () => onOrigin(ReadingOrigin.imported),
                ),
                _chip(
                  label: 'Cualquier aviso',
                  selected: alert == _AlertFilter.all,
                  onTap: () => onAlert(_AlertFilter.all),
                ),
                _chip(
                  label: 'Por encima',
                  selected: alert == _AlertFilter.above,
                  onTap: () => onAlert(_AlertFilter.above),
                ),
                _chip(
                  label: 'Por debajo',
                  selected: alert == _AlertFilter.below,
                  onTap: () => onAlert(_AlertFilter.below),
                ),
                _chip(
                  label: 'Sin aviso',
                  selected: alert == _AlertFilter.none,
                  onTap: () => onAlert(_AlertFilter.none),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.accent.withValues(alpha: 0.18),
      side: BorderSide(
        color: selected ? AppColors.accent : AppColors.border,
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.subtitle,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
    );
  }
}
