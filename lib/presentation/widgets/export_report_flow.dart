import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/blood_pressure_model.dart';
import '../../domain/entities/export_options.dart';
import '../../domain/entities/import_preferences.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_dose_log.dart';

/// Informe Excel / PDF: elige periodo y bloques, y lo comparte.
/// Se usa desde Resumen e Historial.
Future<void> startReportExport(
  BuildContext context, {
  required bool pdf,
  DateTimeRange? initialRange,
}) async {
  final deps = AppScope.of(context);
  final profile = deps.profiles.current();
  final allReadings = deps.measurements.getAll();
  void message(String text) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  final request = await _pickExportRequest(
    context,
    readings: allReadings,
    initialRange: initialRange,
  );
  if (request == null || !context.mounted) return;
  final range = request.range;
  final options = request.options;
  if (!options.hasContent) {
    message('Elige al menos un bloque del informe.');
    return;
  }

  final filtered = options.includeReadings
      ? allReadings.where((reading) {
          return !reading.measuredAt.isBefore(range.start) &&
              !reading.measuredAt.isAfter(range.end);
        }).toList()
      : <BloodPressureModel>[];
  final doseLogs = options.includeDoseLogs
      ? deps.medicationDoseLogs.getAll().where((log) {
          return !log.scheduledAt.isBefore(range.start) &&
              !log.scheduledAt.isAfter(range.end);
        }).toList()
      : <MedicationDoseLog>[];
  // Nombres de medicación siempre disponibles para el bloque de tomas.
  final medicationsInRange = deps.medications.getAll().where((med) {
    final start = DateTime(
      med.startDate.year,
      med.startDate.month,
      med.startDate.day,
    );
    final end = med.endDate == null
        ? null
        : DateTime(
            med.endDate!.year,
            med.endDate!.month,
            med.endDate!.day,
            23,
            59,
            59,
          );
    if (end != null && end.isBefore(range.start)) return false;
    if (start.isAfter(range.end)) return false;
    return true;
  }).toList();
  final medications = options.includeMedications || options.includeDoseLogs
      ? medicationsInRange
      : <Medication>[];
  final exports = deps.exports;
  try {
    if (pdf) {
      await exports.sharePdf(
        profile: profile,
        readings: filtered,
        medications: medications,
        doseLogs: doseLogs,
        options: options,
      );
    } else {
      await exports.shareExcel(
        profile: profile,
        readings: filtered,
        medications: medications,
        doseLogs: doseLogs,
        options: options,
      );
    }
  } catch (error) {
    debugPrint('Informe: $error');
    message('No se ha podido crear el informe. Inténtalo de nuevo.');
  }
}

Future<({DateTimeRange range, ExportOptions options})?> _pickExportRequest(
  BuildContext context, {
  required List<BloodPressureModel> readings,
  DateTimeRange? initialRange,
}) async {
  final now = DateTime.now();
  var from =
      initialRange?.start ??
      (readings.isEmpty
          ? now.subtract(const Duration(days: 90))
          : readings.last.measuredAt);
  var to = initialRange == null || initialRange.end.isAfter(now)
      ? now
      : initialRange.end;
  final importPrefs = AppScope.of(context).importPreferences.current();
  var options = ExportOptions.fromImportPreferences(importPrefs);

  return showDialog<({DateTimeRange range, ExportOptions options})>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('Exportar informe'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Periodo',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Desde'),
                      subtitle: Text(formatDate(from)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: from,
                          firstDate: DateTime(2000),
                          lastDate: now,
                        );
                        if (picked != null) {
                          setLocal(
                            () => from = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                            ),
                          );
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hasta'),
                      subtitle: Text(formatDate(to)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: to,
                          firstDate: DateTime(2000),
                          lastDate: now,
                        );
                        if (picked != null) setLocal(() => to = picked);
                      },
                    ),
                    const Divider(),
                    const Text(
                      'Bloques',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ficha'),
                      value: options.includeProfile,
                      onChanged: (value) => setLocal(
                        () => options = options.copyWith(
                          includeProfile: value ?? false,
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mediciones'),
                      value: options.includeReadings,
                      onChanged: (value) => setLocal(
                        () => options = options.copyWith(
                          includeReadings: value ?? false,
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Medicaciones'),
                      value: options.includeMedications,
                      onChanged: (value) => setLocal(
                        () => options = options.copyWith(
                          includeMedications: value ?? false,
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tomas de medicación'),
                      value: options.includeDoseLogs,
                      onChanged: (value) => setLocal(
                        () => options = options.copyWith(
                          includeDoseLogs: value ?? false,
                        ),
                      ),
                    ),
                    if (options.includeReadings) ...[
                      const Divider(),
                      const Text(
                        'Columnas de mediciones',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Por defecto, las de «Datos a medir».',
                        style: TextStyle(
                          color: AppColors.subtitle,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final metric in ImportMetric.values)
                            FilterChip(
                              label: Text(metric.label),
                              selected: options.hasMetric(metric),
                              onSelected: (selected) {
                                setLocal(() {
                                  final next = {...options.metrics};
                                  if (selected) {
                                    next.add(metric);
                                  } else {
                                    next.remove(metric);
                                  }
                                  options = options.copyWith(metrics: next);
                                });
                              },
                            ),
                        ],
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Contexto'),
                        subtitle: const Text(
                          'Momento, cómo me siento, notas, origen y fuente',
                        ),
                        value: options.includeContext,
                        onChanged: (value) => setLocal(
                          () => options = options.copyWith(
                            includeContext: value ?? false,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setLocal(() {
                            options = options.copyWith(
                              metrics: ImportMetric.values.toSet(),
                              includeContext: true,
                            );
                          }),
                          child: const Text('Seleccionar todas las columnas'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final start = DateTime(from.year, from.month, from.day);
                  final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
                  if (end.isBefore(start)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'La fecha «Hasta» tiene que ser posterior a «Desde».',
                        ),
                      ),
                    );
                    return;
                  }
                  if (!options.hasContent) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Elige al menos un bloque.'),
                      ),
                    );
                    return;
                  }
                  if (options.includeReadings &&
                      options.metrics.isEmpty &&
                      !options.includeContext) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'En mediciones elige alguna columna o el contexto.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, (
                    range: DateTimeRange(start: start, end: end),
                    options: options,
                  ));
                },
                child: const Text('Crear'),
              ),
            ],
          );
        },
      );
    },
  );
}
