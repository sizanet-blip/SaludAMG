import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_dose_log.dart';
import '../../domain/enums/health_enums.dart';
import '../widgets/salud_amg_app_bar.dart';

/// Marcas de los últimos 30 días, para corregir un error.
class MedicationDosesScreen extends StatefulWidget {
  const MedicationDosesScreen({
    super.key,
    required this.medication,
    required this.trackStock,
  });

  final Medication medication;
  final bool trackStock;

  @override
  State<MedicationDosesScreen> createState() => _MedicationDosesScreenState();
}

class _MedicationDosesScreenState extends State<MedicationDosesScreen> {
  List<MedicationDoseLog> _logs = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() {
    if (!mounted) return;
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 29));
    final logs = AppScope.of(context).medicationDoseLogs.forMedicationInRange(
      widget.medication.id,
      DateTime(from.year, from.month, from.day),
      now.add(const Duration(days: 1)),
    )..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    setState(() => _logs = logs);
  }

  Future<void> _delete(MedicationDoseLog log) async {
    final when = formatDateTime(log.scheduledAt);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar marca'),
        content: Text(
          'Se borrará la marca del $when (${log.status.label.toLowerCase()}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deps = AppScope.of(context);
    await deps.medicationDoseLogs.delete(log.id);
    final current =
        deps.medications.getById(widget.medication.id) ?? widget.medication;
    if (widget.trackStock &&
        log.status == DoseStatus.taken &&
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
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SaludAmgAppBar(section: widget.medication.name),
      body: _logs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No hay tomas marcadas en los últimos 30 días.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.subtitle),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: _logs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final log = _logs[index];
                final taken = log.status == DoseStatus.taken;
                final takenAt = log.effectiveTakenAt;
                final detail = takenAt == null
                    ? log.status.label
                    : '${log.status.label} · ${formatDateTime(takenAt)}';
                return Card(
                  child: ListTile(
                    title: Text(
                      '${formatDate(log.scheduledAt)} · '
                      '${formatClock(log.scheduledAt.hour * 60 + log.scheduledAt.minute)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      detail,
                      style: TextStyle(
                        color: taken ? AppColors.ok : AppColors.warn,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Quitar marca',
                      onPressed: () => _delete(log),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
