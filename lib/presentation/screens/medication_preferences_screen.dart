import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/medication_preferences.dart';
import '../widgets/app_section_card.dart';
import '../widgets/salud_amg_app_bar.dart';

class MedicationPreferencesScreen extends StatefulWidget {
  const MedicationPreferencesScreen({super.key});

  @override
  State<MedicationPreferencesScreen> createState() =>
      _MedicationPreferencesScreenState();
}

class _MedicationPreferencesScreenState
    extends State<MedicationPreferencesScreen> {
  late MedicationPreferences _prefs;
  var _ready = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _prefs = AppScope.of(context).medicationPreferences.current();
        _ready = true;
      });
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final deps = AppScope.of(context);
    var prefs = _prefs;
    if (!prefs.trackStock) {
      prefs = prefs.copyWith(reorderReminders: false);
    }
    await deps.medicationPreferences.save(prefs);
    final notice = await deps.notifications.syncMedicationSchedule(
      medications: deps.medications.getAll(),
      preferences: prefs,
    );
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _saving = false;
    });
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    messenger.showSnackBar(
      SnackBar(content: Text(notice ?? 'Configuración de medicación guardada.')),
    );
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
      appBar: const SaludAmgAppBar(section: 'Medicación (config)'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'Elige qué partes de medicación quieres usar. Los avisos de toma '
            'siguen el horario de cada medicación activa y vigente.',
            style: TextStyle(color: AppColors.subtitle),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'Opciones',
            icon: Icons.medication_outlined,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Registro de toma'),
                  subtitle: const Text(
                    'Marcar cada horario como tomado u omitido.',
                  ),
                  value: _prefs.trackDoses,
                  onChanged: (value) => setState(
                    () => _prefs = _prefs.copyWith(trackDoses: value),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Control de stock'),
                  subtitle: const Text(
                    'Unidades restantes por medicación. Al marcar tomado se resta 1.',
                  ),
                  value: _prefs.trackStock,
                  onChanged: (value) => setState(() {
                    _prefs = _prefs.copyWith(
                      trackStock: value,
                      reorderReminders:
                          value ? _prefs.reorderReminders : false,
                    );
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aviso de pedir medicación'),
                  subtitle: const Text(
                    'Notificación diaria si el stock está en el umbral o por debajo.',
                  ),
                  value: _prefs.reorderReminders,
                  onChanged: _prefs.trackStock
                      ? (value) => setState(
                            () => _prefs =
                                _prefs.copyWith(reorderReminders: value),
                          )
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aviso de pedir al médico'),
                  subtitle: const Text(
                    'Notificaciones, tarjeta en inicio y «Ya pedí» para renovar la receta.',
                  ),
                  value: _prefs.doctorRequestReminders,
                  onChanged: (value) => setState(
                    () => _prefs =
                        _prefs.copyWith(doctorRequestReminders: value),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Botón en inicio'),
                  subtitle: const Text(
                    'Mostrar acceso rápido a medicación junto al de medición.',
                  ),
                  value: _prefs.showHomeButton,
                  onChanged: (value) => setState(
                    () => _prefs = _prefs.copyWith(showHomeButton: value),
                  ),
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
    );
  }
}
