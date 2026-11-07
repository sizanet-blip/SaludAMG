import 'import_preferences.dart';

/// Qué bloques y columnas incluir en Excel/PDF.
class ExportOptions {
  const ExportOptions({
    this.includeProfile = true,
    this.includeReadings = true,
    this.includeMedications = true,
    this.includeDoseLogs = true,
    this.includeContext = true,
    this.metrics = const {
      ImportMetric.bloodPressure,
      ImportMetric.pulse,
      ImportMetric.restingPulse,
      ImportMetric.oxygen,
      ImportMetric.temperature,
      ImportMetric.glucose,
      ImportMetric.weight,
      ImportMetric.bodyFat,
      ImportMetric.bmi,
      ImportMetric.steps,
      ImportMetric.sleep,
      ImportMetric.hrv,
    },
  });

  /// Parte de las preferencias «Datos a medir» (métricas activas + contexto).
  factory ExportOptions.fromImportPreferences(ImportPreferences prefs) {
    final selected = {
      for (final metric in ImportMetric.values)
        if (metric.read(prefs)) metric,
    };
    return ExportOptions(
      metrics: selected.isEmpty
          ? {
              ImportMetric.bloodPressure,
              ImportMetric.pulse,
            }
          : selected,
    );
  }

  final bool includeProfile;
  final bool includeReadings;
  final bool includeMedications;
  final bool includeDoseLogs;

  /// Momento, cómo me siento, notas, origen, fuente, sincronizado.
  final bool includeContext;

  final Set<ImportMetric> metrics;

  bool get hasContent =>
      includeProfile ||
      includeReadings ||
      includeMedications ||
      includeDoseLogs;

  bool hasMetric(ImportMetric metric) => metrics.contains(metric);

  ExportOptions copyWith({
    bool? includeProfile,
    bool? includeReadings,
    bool? includeMedications,
    bool? includeDoseLogs,
    bool? includeContext,
    Set<ImportMetric>? metrics,
  }) {
    return ExportOptions(
      includeProfile: includeProfile ?? this.includeProfile,
      includeReadings: includeReadings ?? this.includeReadings,
      includeMedications: includeMedications ?? this.includeMedications,
      includeDoseLogs: includeDoseLogs ?? this.includeDoseLogs,
      includeContext: includeContext ?? this.includeContext,
      metrics: metrics ?? this.metrics,
    );
  }
}
