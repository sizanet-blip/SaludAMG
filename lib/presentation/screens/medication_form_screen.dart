import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/ids.dart';
import '../../domain/entities/medication.dart';
import '../../domain/enums/health_enums.dart';
import '../widgets/app_section_card.dart';
import '../widgets/salud_amg_app_bar.dart';

class MedicationFormScreen extends StatefulWidget {
  const MedicationFormScreen({super.key, this.existing});

  final Medication? existing;

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _notes = TextEditingController();
  final _stock = TextEditingController();
  final _threshold = TextEditingController();
  final _units = TextEditingController(text: '1');
  final _repeatEvery = TextEditingController(text: '6');
  final _leadDays = TextEditingController(text: '0');

  late DateTime _startDate;
  DateTime? _endDate;
  DateTime? _doctorRequestDate;
  var _doctorRepeat = DoctorRequestRepeat.once;
  var _noEnd = true;
  var _active = true;
  List<int> _minutes = const [8 * 60];
  Set<int> _weekdays = {1, 2, 3, 4, 5, 6, 7};
  var _trackStock = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final today = DateTime.now();
    if (existing != null) {
      _name.text = existing.name;
      _dose.text = existing.dose;
      _notes.text = existing.notes;
      _startDate = DateTime(
        existing.startDate.year,
        existing.startDate.month,
        existing.startDate.day,
      );
      _endDate = existing.endDate == null
          ? null
          : DateTime(
              existing.endDate!.year,
              existing.endDate!.month,
              existing.endDate!.day,
            );
      _noEnd = existing.endDate == null;
      _active = existing.active;
      _minutes = existing.sortedMinutes.isEmpty
          ? [8 * 60]
          : existing.sortedMinutes;
      _weekdays = existing.effectiveWeekdays.toSet();
      _units.text = '${existing.unitsPerDose}';
      if (existing.stockRemaining != null) {
        _stock.text = '${existing.stockRemaining}';
      }
      if (existing.reorderThreshold != null) {
        _threshold.text = '${existing.reorderThreshold}';
      }
      if (existing.doctorRequestDate != null) {
        _doctorRequestDate = DateTime(
          existing.doctorRequestDate!.year,
          existing.doctorRequestDate!.month,
          existing.doctorRequestDate!.day,
        );
      }
      _doctorRepeat = existing.doctorRepeat;
      _repeatEvery.text = '${existing.effectiveDoctorRepeatEvery}';
      _leadDays.text = '${existing.effectiveDoctorLeadDays}';
    } else {
      _startDate = DateTime(today.year, today.month, today.day);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _trackStock =
            AppScope.of(context).medicationPreferences.current().trackStock;
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _notes.dispose();
    _stock.dispose();
    _threshold.dispose();
    _units.dispose();
    _repeatEvery.dispose();
    _leadDays.dispose();
    super.dispose();
  }

  Future<void> _pickDoctorRequestDate() async {
    final initial = _doctorRequestDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Fecha para pedir al médico',
    );
    if (picked == null) return;
    setState(() {
      _doctorRequestDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      if (_endDate != null && _endDate!.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEnd() async {
    final initial = _endDate ?? _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(_startDate) ? _startDate : initial,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);
      _noEnd = false;
    });
  }

  int _suggestedMinute() {
    final used = _minutes.toSet();
    var candidate = _minutes.isEmpty ? 8 * 60 : (_minutes.last + 60) % (24 * 60);
    for (var i = 0; i < 24 * 60; i++) {
      if (!used.contains(candidate)) return candidate;
      candidate = (candidate + 1) % (24 * 60);
    }
    return 8 * 60;
  }

  Future<void> _addTime() async {
    final suggested = _suggestedMinute();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: suggested ~/ 60, minute: suggested % 60),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    if (_minutes.contains(minutes)) {
      _message('Ese horario ya está.');
      return;
    }
    setState(() {
      _minutes = [..._minutes, minutes]..sort();
    });
  }

  Future<void> _editTime(int index) async {
    final current = _minutes[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    setState(() {
      _minutes = List<int>.of(_minutes);
      _minutes[index] = picked.hour * 60 + picked.minute;
      _minutes = _minutes.toSet().toList()..sort();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final minutes = _minutes.toSet().toList()..sort();
    if (minutes.isEmpty) {
      _message('Añade al menos un horario.');
      return;
    }
    if (!_noEnd && _endDate == null) {
      _message('Elige la fecha de fin o marca «Sin fecha de fin».');
      return;
    }
    if (_weekdays.isEmpty) {
      _message('Elige al menos un día de la semana.');
      return;
    }

    final units = int.tryParse(_units.text.trim()) ?? 1;
    if (units < 1 || units > 99) {
      _message('Unidades por toma: entre 1 y 99.');
      return;
    }

    int? stock;
    int? threshold;
    if (_trackStock) {
      final stockText = _stock.text.trim();
      final thresholdText = _threshold.text.trim();
      if (stockText.isNotEmpty) {
        stock = int.tryParse(stockText);
        if (stock == null || stock < 0) {
          _message('Stock no válido.');
          return;
        }
      }
      if (thresholdText.isNotEmpty) {
        threshold = int.tryParse(thresholdText);
        if (threshold == null || threshold < 0) {
          _message('Umbral no válido.');
          return;
        }
      }
    }

    var leadDays = 0;
    var repeatEvery = 6;
    if (_doctorRequestDate != null) {
      leadDays = int.tryParse(_leadDays.text.trim()) ?? 0;
      if (leadDays < 0 || leadDays > 90) {
        _message('Aviso anticipado: entre 0 y 90 días.');
        return;
      }
      if (_doctorRepeat == DoctorRequestRepeat.everyMonths) {
        repeatEvery = int.tryParse(_repeatEvery.text.trim()) ?? 0;
        if (repeatEvery < 1 || repeatEvery > 60) {
          _message('Repetición: entre 1 y 60 meses.');
          return;
        }
      }
    }

    final weekdays = _weekdays.toList()..sort();
    final everyDay = weekdays.length == 7;

    setState(() => _saving = true);
    final medication = Medication(
      id: widget.existing?.id ?? newLocalId(),
      name: _name.text.trim(),
      dose: _dose.text.trim(),
      notes: _notes.text.trim(),
      startDate: _startDate,
      endDate: _noEnd ? null : _endDate,
      minutesFromMidnight: minutes,
      active: _active,
      stockRemaining: _trackStock ? stock : widget.existing?.stockRemaining,
      reorderThreshold:
          _trackStock ? threshold : widget.existing?.reorderThreshold,
      unitsPerDose: units,
      weekdays: everyDay ? const [] : weekdays,
      doctorRequestDate: _doctorRequestDate,
      doctorRepeat: _doctorRequestDate == null
          ? DoctorRequestRepeat.once
          : _doctorRepeat,
      doctorRepeatEvery: repeatEvery,
      doctorLeadDays: leadDays,
      updatedAt: DateTime.now(),
    );

    final deps = AppScope.of(context);
    await deps.medications.save(medication);
    final notice = await deps.notifications.syncMedicationSchedule(
      medications: deps.medications.getAll(),
      preferences: deps.medicationPreferences.current(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    if (notice != null) {
      messenger.showSnackBar(SnackBar(content: Text(notice)));
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _doctorHelpText() {
    final date = _doctorRequestDate;
    if (date == null) return '';
    final lead = int.tryParse(_leadDays.text.trim()) ?? 0;
    final notify = date.subtract(Duration(days: lead.clamp(0, 90)));
    final repeat = switch (_doctorRepeat) {
      DoctorRequestRepeat.once => 'sin repetición',
      DoctorRequestRepeat.yearly => 'luego cada año',
      DoctorRequestRepeat.everyMonths =>
        'luego cada ${(int.tryParse(_repeatEvery.text.trim()) ?? 6).clamp(1, 60)} meses',
    };
    final leadText = lead <= 0
        ? 'Avisa el ${formatDate(date)}'
        : 'Avisa desde el ${formatDate(notify)} (objetivo ${formatDate(date)})';
    return '$leadText · $repeat. Tras «Ya pedí» se calcula la siguiente fecha.';
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SaludAmgAppBar(
        section: editing ? 'Editar medicación' : 'Nueva medicación',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            AppSectionCard(
              title: 'Datos',
              icon: Icons.medication_liquid_outlined,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Obligatorio'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dose,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Dosis',
                      hintText: 'p. ej. 1 comprimido / 10 mg',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Notas'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activa'),
                    value: _active,
                    onChanged: (value) => setState(() => _active = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppSectionCard(
              title: 'Vigencia',
              icon: Icons.date_range_outlined,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha de inicio'),
                    subtitle: Text(formatDate(_startDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: _pickStart,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sin fecha de fin'),
                    subtitle: const Text('Indefinida mientras esté activa'),
                    value: _noEnd,
                    onChanged: (value) => setState(() {
                      _noEnd = value;
                      if (!value && _endDate == null) {
                        _endDate = _startDate.add(const Duration(days: 30));
                      }
                    }),
                  ),
                  if (!_noEnd)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fecha de fin'),
                      subtitle: Text(
                        _endDate == null
                            ? 'Elige una fecha'
                            : formatDate(_endDate!),
                      ),
                      trailing: const Icon(Icons.event_outlined),
                      onTap: _pickEnd,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppSectionCard(
              title: 'Días de la semana',
              icon: Icons.view_week_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(Medication.weekdayLabels[day - 1]),
                      selected: _weekdays.contains(day),
                      showCheckmark: false,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _weekdays = {..._weekdays, day};
                          } else {
                            _weekdays = {..._weekdays}..remove(day);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppSectionCard(
              title: 'Horarios de aviso',
              icon: Icons.schedule,
              child: Column(
                children: [
                  for (var i = 0; i < _minutes.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(formatClock(_minutes[i])),
                      trailing: _minutes.length > 1
                          ? IconButton(
                              tooltip: 'Quitar',
                              onPressed: () {
                                setState(() {
                                  _minutes = List<int>.of(_minutes)
                                    ..removeAt(i);
                                });
                              },
                              icon: const Icon(Icons.delete_outline),
                            )
                          : const Icon(Icons.schedule),
                      onTap: () => _editTime(i),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addTime,
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir horario'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppSectionCard(
              title: 'Unidades por toma',
              icon: Icons.exposure_outlined,
              child: TextFormField(
                controller: _units,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Al marcar tomado se restan',
                  hintText: '1',
                ),
              ),
            ),
            if (_trackStock) ...[
              const SizedBox(height: 12),
              AppSectionCard(
                title: 'Stock',
                icon: Icons.inventory_2_outlined,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Unidades restantes',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _threshold,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Umbral para pedir',
                        hintText: 'Avisar si stock ≤ este valor',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            AppSectionCard(
              title: 'Pedir al médico',
              icon: Icons.medical_services_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Próxima fecha'),
                    subtitle: Text(
                      _doctorRequestDate == null
                          ? 'Sin fecha · toca para elegir'
                          : formatDate(_doctorRequestDate!),
                    ),
                    trailing: const Icon(Icons.event_outlined),
                    onTap: _pickDoctorRequestDate,
                  ),
                  if (_doctorRequestDate != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _doctorRequestDate = null;
                          _doctorRepeat = DoctorRequestRepeat.once;
                        }),
                        child: const Text('Quitar recordatorio'),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Repetición',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final value in DoctorRequestRepeat.values)
                          ChoiceChip(
                            label: Text(
                              value == DoctorRequestRepeat.everyMonths
                                  ? 'Cada X meses'
                                  : value.label,
                            ),
                            selected: _doctorRepeat == value,
                            onSelected: (_) =>
                                setState(() => _doctorRepeat = value),
                          ),
                      ],
                    ),
                    if (_doctorRepeat == DoctorRequestRepeat.everyMonths) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _repeatEvery,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Cada cuántos meses',
                          hintText: '3, 6 o 12',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _leadDays,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Avisar con antelación (días)',
                        hintText: '0 = el mismo día · p. ej. 14',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _doctorHelpText(),
                      style: const TextStyle(
                        color: AppColors.subtitle,
                        fontSize: 13,
                      ),
                    ),
                  ] else
                    const Text(
                      'Opcional. Ideal para renovar la receta (p. ej. una vez al año en la SS).',
                      style: TextStyle(color: AppColors.subtitle, fontSize: 13),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
