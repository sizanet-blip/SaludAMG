/// Qué tipos se piden a Apple Salud / Health Connect al importar.
///
/// Por defecto solo tensión y pulso. El resto se activa en Configuración.
class ImportPreferences {
  const ImportPreferences({
    required this.bloodPressure,
    required this.pulse,
    required this.restingPulse,
    required this.oxygen,
    required this.temperature,
    required this.glucose,
    required this.weight,
    required this.bodyFat,
    required this.bmi,
    required this.steps,
    required this.sleep,
    required this.hrv,
  });

  static const storageKey = 'import';

  factory ImportPreferences.defaults() {
    return const ImportPreferences(
      bloodPressure: true,
      pulse: true,
      restingPulse: false,
      oxygen: false,
      temperature: false,
      glucose: false,
      weight: false,
      bodyFat: false,
      bmi: false,
      steps: false,
      sleep: false,
      hrv: false,
    );
  }

  /// Sistólica + diastólica.
  final bool bloodPressure;
  final bool pulse;
  final bool restingPulse;
  final bool oxygen;
  final bool temperature;
  final bool glucose;
  final bool weight;
  final bool bodyFat;
  final bool bmi;
  final bool steps;
  final bool sleep;
  final bool hrv;

  bool get hasAnySelected =>
      bloodPressure ||
      pulse ||
      restingPulse ||
      oxygen ||
      temperature ||
      glucose ||
      weight ||
      bodyFat ||
      bmi ||
      steps ||
      sleep ||
      hrv;

  ImportPreferences copyWith({
    bool? bloodPressure,
    bool? pulse,
    bool? restingPulse,
    bool? oxygen,
    bool? temperature,
    bool? glucose,
    bool? weight,
    bool? bodyFat,
    bool? bmi,
    bool? steps,
    bool? sleep,
    bool? hrv,
  }) {
    return ImportPreferences(
      bloodPressure: bloodPressure ?? this.bloodPressure,
      pulse: pulse ?? this.pulse,
      restingPulse: restingPulse ?? this.restingPulse,
      oxygen: oxygen ?? this.oxygen,
      temperature: temperature ?? this.temperature,
      glucose: glucose ?? this.glucose,
      weight: weight ?? this.weight,
      bodyFat: bodyFat ?? this.bodyFat,
      bmi: bmi ?? this.bmi,
      steps: steps ?? this.steps,
      sleep: sleep ?? this.sleep,
      hrv: hrv ?? this.hrv,
    );
  }
}

enum ImportMetricGroup { vitalsBase, vitalsExtra, body, activity }

enum ImportMetric {
  bloodPressure,
  pulse,
  restingPulse,
  oxygen,
  temperature,
  glucose,
  weight,
  bodyFat,
  bmi,
  steps,
  sleep,
  hrv;

  String get label => switch (this) {
        ImportMetric.bloodPressure => 'Tensión arterial',
        ImportMetric.pulse => 'Pulso',
        ImportMetric.restingPulse => 'Pulso en reposo',
        ImportMetric.oxygen => 'Saturación O₂',
        ImportMetric.temperature => 'Temperatura corporal',
        ImportMetric.glucose => 'Glucosa',
        ImportMetric.weight => 'Peso',
        ImportMetric.bodyFat => 'Grasa corporal',
        ImportMetric.bmi => 'IMC',
        ImportMetric.steps => 'Pasos',
        ImportMetric.sleep => 'Sueño',
        ImportMetric.hrv => 'Variabilidad cardiaca (HRV)',
      };

  String get subtitle => switch (this) {
        ImportMetric.bloodPressure => 'Sistólica y diastólica',
        ImportMetric.pulse => 'lpm cerca de la toma',
        ImportMetric.restingPulse => 'lpm en reposo',
        ImportMetric.oxygen => 'Porcentaje de oxígeno',
        ImportMetric.temperature => 'Grados Celsius',
        ImportMetric.glucose => 'mg/dL',
        ImportMetric.weight => 'Kilogramos',
        ImportMetric.bodyFat => 'Porcentaje',
        ImportMetric.bmi => 'Índice de masa corporal',
        ImportMetric.steps => 'Total del día de la medición',
        ImportMetric.sleep => 'Minutos dormidos del día',
        ImportMetric.hrv => 'ms (SDNN / RMSSD según plataforma)',
      };

  ImportMetricGroup get group => switch (this) {
        ImportMetric.bloodPressure || ImportMetric.pulse => ImportMetricGroup.vitalsBase,
        ImportMetric.restingPulse ||
        ImportMetric.oxygen ||
        ImportMetric.temperature ||
        ImportMetric.glucose =>
          ImportMetricGroup.vitalsExtra,
        ImportMetric.weight || ImportMetric.bodyFat || ImportMetric.bmi => ImportMetricGroup.body,
        ImportMetric.steps || ImportMetric.sleep || ImportMetric.hrv => ImportMetricGroup.activity,
      };

  static String groupTitle(ImportMetricGroup group) => switch (group) {
        ImportMetricGroup.vitalsBase => 'Vitales base',
        ImportMetricGroup.vitalsExtra => 'Vitales extra',
        ImportMetricGroup.body => 'Cuerpo',
        ImportMetricGroup.activity => 'Actividad y descanso',
      };

  bool read(ImportPreferences prefs) => switch (this) {
        ImportMetric.bloodPressure => prefs.bloodPressure,
        ImportMetric.pulse => prefs.pulse,
        ImportMetric.restingPulse => prefs.restingPulse,
        ImportMetric.oxygen => prefs.oxygen,
        ImportMetric.temperature => prefs.temperature,
        ImportMetric.glucose => prefs.glucose,
        ImportMetric.weight => prefs.weight,
        ImportMetric.bodyFat => prefs.bodyFat,
        ImportMetric.bmi => prefs.bmi,
        ImportMetric.steps => prefs.steps,
        ImportMetric.sleep => prefs.sleep,
        ImportMetric.hrv => prefs.hrv,
      };

  ImportPreferences write(ImportPreferences prefs, bool value) => switch (this) {
        ImportMetric.bloodPressure => prefs.copyWith(bloodPressure: value),
        ImportMetric.pulse => prefs.copyWith(pulse: value),
        ImportMetric.restingPulse => prefs.copyWith(restingPulse: value),
        ImportMetric.oxygen => prefs.copyWith(oxygen: value),
        ImportMetric.temperature => prefs.copyWith(temperature: value),
        ImportMetric.glucose => prefs.copyWith(glucose: value),
        ImportMetric.weight => prefs.copyWith(weight: value),
        ImportMetric.bodyFat => prefs.copyWith(bodyFat: value),
        ImportMetric.bmi => prefs.copyWith(bmi: value),
        ImportMetric.steps => prefs.copyWith(steps: value),
        ImportMetric.sleep => prefs.copyWith(sleep: value),
        ImportMetric.hrv => prefs.copyWith(hrv: value),
      };
}
