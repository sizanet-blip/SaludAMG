import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/import_preferences.dart';
import '../widgets/app_section_card.dart';
import '../widgets/salud_amg_app_bar.dart';

class ImportSettingsScreen extends StatefulWidget {
  const ImportSettingsScreen({super.key});

  @override
  State<ImportSettingsScreen> createState() => _ImportSettingsScreenState();
}

class _ImportSettingsScreenState extends State<ImportSettingsScreen> {
  late ImportPreferences _prefs;
  var _ready = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _prefs = AppScope.of(context).importPreferences.current();
        _ready = true;
      });
    });
  }

  Future<void> _save() async {
    if (!_prefs.hasAnySelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deja al menos un dato activo.')),
      );
      return;
    }
    setState(() => _saving = true);
    await AppScope.of(context).importPreferences.save(_prefs);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración de datos guardada.')),
    );
    Navigator.pop(context, true);
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
      appBar: const SaludAmgAppBar(section: 'Datos a medir'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'Define qué campos salen al anotar una medición a mano y qué '
            'se pide al importar desde Apple Salud o Health Connect. '
            'Por defecto solo tensión y pulso.',
            style: TextStyle(color: AppColors.subtitle),
          ),
          const SizedBox(height: 16),
          for (final group in ImportMetricGroup.values) ...[
            AppSectionCard(
              title: ImportMetric.groupTitle(group),
              icon: switch (group) {
                ImportMetricGroup.vitalsBase => Icons.monitor_heart_outlined,
                ImportMetricGroup.vitalsExtra => Icons.bloodtype_outlined,
                ImportMetricGroup.body => Icons.accessibility_new_outlined,
                ImportMetricGroup.activity => Icons.directions_walk_outlined,
              },
              child: Column(
                children: [
                  for (final metric in ImportMetric.values.where((m) => m.group == group))
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(metric.label),
                      subtitle: Text(metric.subtitle),
                      value: metric.read(_prefs),
                      onChanged: (value) {
                        setState(() => _prefs = metric.write(_prefs, value));
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
