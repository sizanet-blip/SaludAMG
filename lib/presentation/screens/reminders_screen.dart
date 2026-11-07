import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/reminder_config.dart';
import '../../domain/enums/health_enums.dart';
import '../widgets/app_section_card.dart';
import '../widgets/salud_amg_app_bar.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  ReminderFrequency _frequency = ReminderFrequency.daily;
  List<int> _minutes = const [8 * 60];
  var _active = false;
  var _ready = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final config = AppScope.of(context).reminders.current();
    setState(() {
      _frequency = config.frequency;
      _minutes = config.sortedMinutes.isEmpty ? [8 * 60] : config.sortedMinutes;
      _active = config.active;
      _ready = true;
    });
  }

  void _setFrequency(ReminderFrequency frequency) {
    setState(() {
      _frequency = frequency;
      _minutes = switch (frequency) {
        ReminderFrequency.daily => [_minutes.first],
        ReminderFrequency.timesPerDay => spreadReminderTimes(
            _minutes.length < 2 ? 3 : _minutes.length.clamp(2, 6),
          ),
        ReminderFrequency.fixedTimes =>
          _minutes.length < 2 ? [8 * 60, 21 * 60] : List<int>.of(_minutes),
      };
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
      _minutes.sort();
    });
  }

  Future<void> _save() async {
    final minutes = _minutes.toSet().toList()..sort();
    if (_active && minutes.isEmpty) {
      _message('Añade al menos un horario.');
      return;
    }
    final config = ReminderConfig(
      id: ReminderConfig.storageKey,
      frequency: _frequency,
      minutesFromMidnight: minutes,
      active: _active,
    );
    final deps = AppScope.of(context);
    setState(() => _saving = true);
    await deps.reminders.save(config);
    final notice = await deps.notifications.syncSchedule(config);
    if (!mounted) return;
    setState(() => _saving = false);
    _message(notice ?? (_active ? 'Recordatorio activado.' : 'Recordatorio guardado.'));
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SaludAmgAppBar(section: 'Recordatorios'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'Aviso local en este teléfono. No sale de la app ni consulta tus mediciones.',
            style: TextStyle(color: AppColors.subtitle),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'Aviso de tensión',
            icon: Icons.notifications_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ReminderFrequency>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(labelText: 'Frecuencia'),
                  items: [
                    for (final frequency in ReminderFrequency.values)
                      DropdownMenuItem(value: frequency, child: Text(frequency.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) _setFrequency(value);
                  },
                ),
                const SizedBox(height: 16),
                if (_frequency == ReminderFrequency.timesPerDay)
                  Row(
                    children: [
                      const Expanded(child: Text('Veces al día')),
                      IconButton(
                        onPressed: _minutes.length <= 2
                            ? null
                            : () => setState(() => _minutes = spreadReminderTimes(_minutes.length - 1)),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('${_minutes.length}'),
                      IconButton(
                        onPressed: _minutes.length >= 6
                            ? null
                            : () => setState(() => _minutes = spreadReminderTimes(_minutes.length + 1)),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                for (var i = 0; i < _minutes.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(formatClock(_minutes[i])),
                    trailing: _frequency == ReminderFrequency.fixedTimes && _minutes.length > 1
                        ? IconButton(
                            tooltip: 'Quitar horario',
                            onPressed: () {
                              setState(() {
                                _minutes = List<int>.of(_minutes)..removeAt(i);
                              });
                            },
                            icon: const Icon(Icons.delete_outline),
                          )
                        : const Icon(Icons.schedule),
                    onTap: () => _editTime(i),
                  ),
                if (_frequency == ReminderFrequency.fixedTimes &&
                    _minutes.length < ReminderConfig.maxSlots)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _minutes = [..._minutes, 12 * 60]..sort();
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir horario'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar recordatorio'),
          ),
        ],
      ),
    );
  }
}
