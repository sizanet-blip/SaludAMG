import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/ids.dart';
import '../../domain/entities/blood_pressure_model.dart';
import '../../domain/entities/import_preferences.dart';
import '../../domain/entities/sync_info.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/enums/health_enums.dart';
import '../../services/health_sync_service.dart';
import '../widgets/app_section_card.dart';
import '../widgets/salud_amg_app_bar.dart';

/// Alta y edición de una medición, a mano o leyendo Apple Salud / Health Connect.
class MeasurementFormScreen extends StatefulWidget {
  const MeasurementFormScreen({super.key, this.existing});

  final BloodPressureModel? existing;

  @override
  State<MeasurementFormScreen> createState() => _MeasurementFormScreenState();
}

class _MeasurementFormScreenState extends State<MeasurementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _pulse = TextEditingController();
  final _restingPulse = TextEditingController();
  final _oxygen = TextEditingController();
  final _temperature = TextEditingController();
  final _glucose = TextEditingController();
  final _weight = TextEditingController();
  final _bodyFat = TextEditingController();
  final _bmi = TextEditingController();
  final _steps = TextEditingController();
  final _sleep = TextEditingController();
  final _hrv = TextEditingController();
  final _notes = TextEditingController();
  final _feeling = TextEditingController();

  var _manual = true;
  var _saving = false;
  var _loadingImport = false;
  var _ready = false;
  var _context = MeasurementContext.unspecified;
  var _measuredAt = DateTime.now();
  DateTime _importFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _importTo = DateTime.now();
  String? _formError;
  String? _importError;
  List<BloodPressureModel> _imported = const [];
  final _selected = <String>{};
  final _active = <ImportMetric>{};

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    final prefs = AppScope.of(context).importPreferences.current();
    final existing = widget.existing;
    _active
      ..clear()
      ..addAll(_metricsFromPrefs(prefs));

    if (existing != null) {
      _systolic.text = existing.systolic?.toString() ?? '';
      _diastolic.text = existing.diastolic?.toString() ?? '';
      _pulse.text = existing.pulse?.toString() ?? '';
      _restingPulse.text = existing.restingPulse?.toString() ?? '';
      _oxygen.text = existing.oxygenSaturation == null
          ? ''
          : formatWeight(existing.oxygenSaturation!);
      _temperature.text = existing.bodyTemperatureC == null
          ? ''
          : formatWeight(existing.bodyTemperatureC!);
      _glucose.text =
          existing.glucoseMgDl == null ? '' : formatWeight(existing.glucoseMgDl!);
      _weight.text =
          existing.weightKg == null ? '' : formatWeight(existing.weightKg!);
      _bodyFat.text = existing.bodyFatPercent == null
          ? ''
          : formatWeight(existing.bodyFatPercent!);
      _bmi.text = existing.bmi == null ? '' : formatWeight(existing.bmi!);
      _steps.text = existing.steps?.toString() ?? '';
      _sleep.text = existing.sleepMinutes?.toString() ?? '';
      _hrv.text = existing.hrvMs == null ? '' : formatWeight(existing.hrvMs!);
      _notes.text = existing.notes;
      _feeling.text = existing.feeling;
      _measuredAt = existing.measuredAt;
      _context = existing.context;
      // Al editar, no ocultar un valor ya guardado aunque esté desactivado en config.
      _active.addAll(_metricsFromReading(existing));
    } else {
      _measuredAt = DateTime.now();
    }

    setState(() => _ready = true);
  }

  Set<ImportMetric> _metricsFromPrefs(ImportPreferences prefs) {
    return {
      for (final metric in ImportMetric.values)
        if (metric.read(prefs)) metric,
    };
  }

  Set<ImportMetric> _metricsFromReading(BloodPressureModel reading) {
    return {
      if (reading.hasPressure) ImportMetric.bloodPressure,
      if (reading.pulse != null) ImportMetric.pulse,
      if (reading.restingPulse != null) ImportMetric.restingPulse,
      if (reading.oxygenSaturation != null) ImportMetric.oxygen,
      if (reading.bodyTemperatureC != null) ImportMetric.temperature,
      if (reading.glucoseMgDl != null) ImportMetric.glucose,
      if (reading.weightKg != null) ImportMetric.weight,
      if (reading.bodyFatPercent != null) ImportMetric.bodyFat,
      if (reading.bmi != null) ImportMetric.bmi,
      if (reading.steps != null) ImportMetric.steps,
      if (reading.sleepMinutes != null) ImportMetric.sleep,
      if (reading.hrvMs != null) ImportMetric.hrv,
    };
  }

  @override
  void dispose() {
    for (final controller in [
      _systolic,
      _diastolic,
      _pulse,
      _restingPulse,
      _oxygen,
      _temperature,
      _glucose,
      _weight,
      _bodyFat,
      _bmi,
      _steps,
      _sleep,
      _hrv,
      _notes,
      _feeling,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _on(ImportMetric metric) => _active.contains(metric);

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = AppScope.of(context).profiles.current();
    final health = AppScope.of(context).healthSync;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SaludAmgAppBar(
        section: _editing ? 'Editar medición' : 'Nueva medición',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (!_editing) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Manual'),
                    icon: Icon(Icons.edit_outlined),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Importar'),
                    icon: Icon(Icons.downloading_outlined),
                  ),
                ],
                selected: {_manual},
                onSelectionChanged: (selection) {
                  setState(() => _manual = selection.first);
                },
              ),
              const SizedBox(height: 16),
            ],
            if (_manual)
              ..._manualFields(profile)
            else
              ..._importFields(health),
          ],
        ),
      ),
    );
  }

  List<Widget> _manualFields(UserProfile profile) {
    final preview = _previewLevel(profile);
    final existing = widget.existing;
    return [
      if (existing != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            existing.syncInfo.detail,
            style: const TextStyle(color: AppColors.subtitle),
          ),
        ),
      if (_active.isEmpty)
        const Text(
          'No hay datos activos. Actívalos en el menú → Datos a medir.',
          style: TextStyle(color: AppColors.danger),
        )
      else
        AppSectionCard(
          title: 'Valores',
          icon: Icons.monitor_heart_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_on(ImportMetric.bloodPressure) || _on(ImportMetric.pulse))
                Text(
                  'Tu referencia: ${profile.systolicReference}/${profile.diastolicReference} mmHg'
                  ' · pulso ${profile.restingPulseReference} lpm',
                  style: const TextStyle(color: AppColors.subtitle),
                ),
              if (_on(ImportMetric.bloodPressure)) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _intField(_systolic, 'Sistólica', 'mmHg', 60, 260),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _intField(_diastolic, 'Diastólica', 'mmHg', 30, 180),
                    ),
                  ],
                ),
              ],
              if (_on(ImportMetric.pulse) || _on(ImportMetric.restingPulse)) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_on(ImportMetric.pulse))
                      Expanded(
                        child: _intField(_pulse, 'Pulso', 'lpm', 30, 220),
                      ),
                    if (_on(ImportMetric.pulse) && _on(ImportMetric.restingPulse))
                      const SizedBox(width: 10),
                    if (_on(ImportMetric.restingPulse))
                      Expanded(
                        child: _intField(
                          _restingPulse,
                          'Pulso reposo',
                          'lpm',
                          30,
                          220,
                        ),
                      ),
                  ],
                ),
              ],
              if (_on(ImportMetric.oxygen) || _on(ImportMetric.temperature)) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_on(ImportMetric.oxygen))
                      Expanded(
                        child: _decimalField(_oxygen, 'Saturación O₂', '%', 50, 100),
                      ),
                    if (_on(ImportMetric.oxygen) && _on(ImportMetric.temperature))
                      const SizedBox(width: 10),
                    if (_on(ImportMetric.temperature))
                      Expanded(
                        child: _decimalField(
                          _temperature,
                          'Temperatura',
                          '°C',
                          30,
                          45,
                        ),
                      ),
                  ],
                ),
              ],
              if (_on(ImportMetric.glucose)) ...[
                const SizedBox(height: 12),
                _decimalField(_glucose, 'Glucosa', 'mg/dL', 40, 600),
              ],
              if (_on(ImportMetric.weight) ||
                  _on(ImportMetric.bodyFat) ||
                  _on(ImportMetric.bmi)) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_on(ImportMetric.weight))
                      Expanded(
                        child: _decimalField(_weight, 'Peso', 'kg', 20, 400),
                      ),
                    if (_on(ImportMetric.weight) &&
                        (_on(ImportMetric.bodyFat) || _on(ImportMetric.bmi)))
                      const SizedBox(width: 10),
                    if (_on(ImportMetric.bodyFat))
                      Expanded(
                        child: _decimalField(_bodyFat, 'Grasa', '%', 1, 70),
                      ),
                    if (_on(ImportMetric.bodyFat) && _on(ImportMetric.bmi))
                      const SizedBox(width: 10),
                    if (_on(ImportMetric.bmi))
                      Expanded(
                        child: _decimalField(_bmi, 'IMC', '', 10, 80),
                      ),
                  ],
                ),
              ],
              if (_on(ImportMetric.steps) ||
                  _on(ImportMetric.sleep) ||
                  _on(ImportMetric.hrv)) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_on(ImportMetric.steps))
                      Expanded(
                        child: _intField(_steps, 'Pasos', '', 0, 200000),
                      ),
                    if (_on(ImportMetric.steps) &&
                        (_on(ImportMetric.sleep) || _on(ImportMetric.hrv)))
                      const SizedBox(width: 10),
                    if (_on(ImportMetric.sleep))
                      Expanded(
                        child: _intField(_sleep, 'Sueño', 'min', 0, 24 * 60),
                      ),
                    if (_on(ImportMetric.sleep) && _on(ImportMetric.hrv))
                      const SizedBox(width: 10),
                    if (_on(ImportMetric.hrv))
                      Expanded(
                        child: _decimalField(_hrv, 'HRV', 'ms', 1, 400),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      const SizedBox(height: 12),
      AppSectionCard(
        title: 'Cuándo',
        icon: Icons.schedule_outlined,
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha y hora'),
              subtitle: Text(formatDateTime(_measuredAt)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickMeasuredAt,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<MeasurementContext>(
              initialValue: _context,
              decoration: const InputDecoration(labelText: 'Momento'),
              items: [
                for (final context in MeasurementContext.values)
                  DropdownMenuItem(value: context, child: Text(context.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _context = value);
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AppSectionCard(
        title: 'Cómo me siento',
        icon: Icons.mood_outlined,
        child: TextFormField(
          controller: _feeling,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: 'Bien, mareo, cansancio…',
            counterText: '',
          ),
        ),
      ),
      const SizedBox(height: 12),
      AppSectionCard(
        title: 'Notas',
        icon: Icons.notes_outlined,
        child: TextFormField(
          controller: _notes,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Café, medicación, contexto… lo que quieras recordar',
            alignLabelWithHint: true,
          ),
          validator: (value) {
            if ((value?.length ?? 0) > 500) return 'Máximo 500 caracteres';
            return null;
          },
        ),
      ),
      if (preview != null) ...[
        const SizedBox(height: 12),
        Text(
          preview.label,
          style: TextStyle(color: colorFor(preview), fontWeight: FontWeight.w700),
        ),
        const Text(
          'La comparación usa tus umbrales, no es un diagnóstico.',
          style: TextStyle(color: AppColors.subtitle, fontSize: 12),
        ),
      ],
      if (_formError != null) ...[
        const SizedBox(height: 12),
        Text(_formError!, style: const TextStyle(color: AppColors.danger)),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _saving || _active.isEmpty ? null : _saveManual,
        child: Text(_saving ? 'Guardando…' : 'Guardar medición'),
      ),
    ];
  }

  List<Widget> _importFields(HealthSyncService? health) {
    if (health == null) {
      return const [
        Text(
          'La importación automática está disponible al instalar la app en Android o iPhone.',
          style: TextStyle(color: AppColors.subtitle),
        ),
      ];
    }

    return [
      AppSectionCard(
        title: 'Desde ${health.platformLabel}',
        icon: Icons.health_and_safety_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Se leen los datos activos en «Datos a medir» '
              '(por defecto tensión y pulso). OHealth y Samsung Health llegan '
              'a través de Health Connect si publican ahí.',
              style: TextStyle(color: AppColors.subtitle),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Desde'),
              subtitle: Text(formatDate(_importFrom)),
              onTap: () => _pickImportDay(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hasta'),
              subtitle: Text(formatDate(_importTo)),
              onTap: () => _pickImportDay(isStart: false),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _loadingImport ? null : () => _readHealth(health),
              icon: _loadingImport
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(_loadingImport ? 'Leyendo…' : 'Leer mediciones'),
            ),
          ],
        ),
      ),
      if (_importError != null) ...[
        const SizedBox(height: 12),
        Text(_importError!, style: const TextStyle(color: AppColors.danger)),
      ],
      if (_imported.isNotEmpty) ...[
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          tristate: true,
          value: _selected.isEmpty
              ? false
              : _selected.length == _imported.length
                  ? true
                  : null,
          title: Text('${_selected.length} de ${_imported.length} seleccionadas'),
          subtitle: const Text('Las que ya estén guardadas no se duplican.'),
          onChanged: (checked) {
            setState(() {
              _selected
                ..clear()
                ..addAll(checked == false ? const [] : _imported.map((e) => e.id));
            });
          },
        ),
        for (final reading in _imported)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _selected.contains(reading.id),
            onChanged: (checked) {
              setState(() {
                if (checked ?? false) {
                  _selected.add(reading.id);
                } else {
                  _selected.remove(reading.id);
                }
              });
            },
            title: Text(
              reading.hasPressure
                  ? '${reading.pressureLabel} mmHg'
                  : reading.pressureLabel,
            ),
            subtitle: Text(
              '${formatDateTime(reading.measuredAt)}\n'
              '${reading.extraChips.isEmpty ? reading.syncInfo.detail : reading.extraChips.join(' · ')}',
            ),
            isThreeLine: true,
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saving || _selected.isEmpty ? null : _saveImported,
          child: Text(_saving ? 'Guardando…' : 'Guardar seleccionadas'),
        ),
      ],
    ];
  }

  Widget _intField(
    TextEditingController controller,
    String label,
    String unit,
    int min,
    int max, {
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit.isEmpty ? null : unit,
      ),
      onChanged: (_) => setState(() => _formError = null),
      validator: (raw) {
        final text = raw?.trim() ?? '';
        if (text.isEmpty) return required ? 'Obligatorio' : null;
        final value = int.tryParse(text);
        if (value == null || value < min || value > max) return '$min–$max';
        return null;
      },
    );
  }

  Widget _decimalField(
    TextEditingController controller,
    String label,
    String unit,
    double min,
    double max, {
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit.isEmpty ? null : unit,
      ),
      onChanged: (_) => setState(() => _formError = null),
      validator: (raw) {
        final text = raw?.trim() ?? '';
        if (text.isEmpty) return required ? 'Obligatorio' : null;
        final value = double.tryParse(text.replaceAll(',', '.'));
        if (value == null || value < min || value > max) {
          return '${min.toStringAsFixed(0)}–${max.toStringAsFixed(0)}';
        }
        return null;
      },
    );
  }

  ReferenceLevel? _previewLevel(UserProfile profile) {
    if (!_on(ImportMetric.bloodPressure)) return null;
    final systolic = int.tryParse(_systolic.text.trim());
    final diastolic = int.tryParse(_diastolic.text.trim());
    if (systolic == null || diastolic == null) return null;
    return profile.levelFor(
      BloodPressureModel(
        id: 'preview',
        systolic: systolic,
        diastolic: diastolic,
        pulse: int.tryParse(_pulse.text.trim()),
        weightKg: null,
        measuredAt: _measuredAt,
        context: _context,
        notes: '',
        syncInfo: const SyncInfo.manual(),
      ),
    );
  }

  Future<void> _pickMeasuredAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _measuredAt,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_measuredAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _measuredAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickImportDay({required bool isStart}) async {
    final initial = isStart ? _importFrom : _importTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _importFrom = DateTime(picked.year, picked.month, picked.day);
      } else {
        _importTo = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  int? _parseInt(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  double? _parseDouble(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _saveManual() async {
    if (_active.isEmpty) {
      setState(() => _formError = 'Activa al menos un dato en Datos a medir.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    int? systolic;
    int? diastolic;
    if (_on(ImportMetric.bloodPressure)) {
      systolic = _parseInt(_systolic);
      diastolic = _parseInt(_diastolic);
      if ((systolic == null) != (diastolic == null)) {
        setState(() => _formError = 'Completa sistólica y diastólica, o déjalas vacías.');
        return;
      }
      if (systolic != null && diastolic != null && diastolic >= systolic) {
        setState(() {
          _formError = 'La diastólica tiene que ser menor que la sistólica.';
        });
        return;
      }
    }

    final pulse = _on(ImportMetric.pulse) ? _parseInt(_pulse) : null;
    final restingPulse =
        _on(ImportMetric.restingPulse) ? _parseInt(_restingPulse) : null;
    final oxygen = _on(ImportMetric.oxygen) ? _parseDouble(_oxygen) : null;
    final temperature =
        _on(ImportMetric.temperature) ? _parseDouble(_temperature) : null;
    final glucose = _on(ImportMetric.glucose) ? _parseDouble(_glucose) : null;
    final weight = _on(ImportMetric.weight) ? _parseDouble(_weight) : null;
    final bodyFat = _on(ImportMetric.bodyFat) ? _parseDouble(_bodyFat) : null;
    final bmi = _on(ImportMetric.bmi) ? _parseDouble(_bmi) : null;
    final steps = _on(ImportMetric.steps) ? _parseInt(_steps) : null;
    final sleep = _on(ImportMetric.sleep) ? _parseInt(_sleep) : null;
    final hrv = _on(ImportMetric.hrv) ? _parseDouble(_hrv) : null;

    final hasAnyValue = systolic != null ||
        pulse != null ||
        restingPulse != null ||
        oxygen != null ||
        temperature != null ||
        glucose != null ||
        weight != null ||
        bodyFat != null ||
        bmi != null ||
        steps != null ||
        sleep != null ||
        hrv != null;
    if (!hasAnyValue) {
      setState(() => _formError = 'Indica al menos un valor para guardar.');
      return;
    }

    if (_measuredAt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      setState(() => _formError = 'La fecha no puede ser futura.');
      return;
    }

    final reading = BloodPressureModel(
      id: widget.existing?.id ?? newLocalId(),
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
      restingPulse: restingPulse,
      oxygenSaturation: oxygen,
      bodyTemperatureC: temperature,
      glucoseMgDl: glucose,
      weightKg: weight,
      bodyFatPercent: bodyFat,
      bmi: bmi,
      steps: steps,
      sleepMinutes: sleep,
      hrvMs: hrv,
      measuredAt: _measuredAt,
      context: _context,
      notes: _notes.text.trim(),
      feeling: _feeling.text.trim(),
      syncInfo: widget.existing?.syncInfo ?? const SyncInfo.manual(),
    );

    setState(() => _saving = true);
    await AppScope.of(context).measurements.save(reading);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _readHealth(HealthSyncService health) async {
    final from = DateTime(_importFrom.year, _importFrom.month, _importFrom.day);
    final toDay = DateTime(_importTo.year, _importTo.month, _importTo.day);
    final endOfTo = DateTime(toDay.year, toDay.month, toDay.day, 23, 59, 59);
    final to = endOfTo.isAfter(DateTime.now()) ? DateTime.now() : endOfTo;
    if (!to.isAfter(from)) {
      setState(() => _importError = 'La fecha inicial tiene que ser anterior.');
      return;
    }

    setState(() {
      _loadingImport = true;
      _importError = null;
    });
    try {
      final prefs = AppScope.of(context).importPreferences.current();
      final readings = await health.importRange(
        from: from,
        to: to,
        prefs: prefs,
      );
      if (!mounted) return;
      setState(() {
        _imported = readings;
        _selected
          ..clear()
          ..addAll(readings.map((reading) => reading.id));
        if (readings.isEmpty) {
          _importError =
              'No hay datos en ese periodo con los filtros activos. '
              'Revisa Datos a medir o los permisos de ${health.platformLabel}.';
        }
      });
    } on HealthSyncException catch (error) {
      if (!mounted) return;
      setState(() => _importError = error.message);
    } finally {
      if (mounted) setState(() => _loadingImport = false);
    }
  }

  Future<void> _saveImported() async {
    final chosen = _imported.where((reading) => _selected.contains(reading.id));
    setState(() => _saving = true);
    final added =
        await AppScope.of(context).measurements.saveImported(chosen.toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Se han guardado $added mediciones nuevas.')),
    );
    Navigator.pop(context, true);
  }
}
