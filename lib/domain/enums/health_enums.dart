/// Grupo sanguíneo de la ficha. [unknown] es el valor hasta que se rellene.
enum BloodType {
  aPositive,
  aNegative,
  bPositive,
  bNegative,
  abPositive,
  abNegative,
  oPositive,
  oNegative,
  unknown;

  String get label => switch (this) {
        BloodType.aPositive => 'A+',
        BloodType.aNegative => 'A-',
        BloodType.bPositive => 'B+',
        BloodType.bNegative => 'B-',
        BloodType.abPositive => 'AB+',
        BloodType.abNegative => 'AB-',
        BloodType.oPositive => 'O+',
        BloodType.oNegative => 'O-',
        BloodType.unknown => 'Desconocido',
      };
}

/// Momento del día en el que se tomó la medición.
enum MeasurementContext {
  morningFasting,
  beforeSleep,
  postExercise,
  afterMedication,
  other,
  unspecified;

  String get label => switch (this) {
        MeasurementContext.morningFasting => 'Mañana / ayunas',
        MeasurementContext.beforeSleep => 'Noche / antes de dormir',
        MeasurementContext.postExercise => 'Después de ejercicio',
        MeasurementContext.afterMedication => 'Tras la medicación',
        MeasurementContext.other => 'Otro',
        MeasurementContext.unspecified => 'Sin especificar',
      };
}

/// Si el registro nació en SaludAMG o llegó de otra app de salud.
enum ReadingOrigin {
  manual,
  imported;

  String get label => switch (this) {
        ReadingOrigin.manual => 'Manual',
        ReadingOrigin.imported => 'Importado',
      };
}

/// Plataforma o app de la que procede una medición importada.
enum ImportSource {
  manual,
  appleHealth,
  googleHealthConnect,
  oHealth,
  samsungHealth,
  other;

  String get label => switch (this) {
        ImportSource.manual => 'Manual',
        ImportSource.appleHealth => 'Apple Salud',
        ImportSource.googleHealthConnect => 'Health Connect',
        ImportSource.oHealth => 'OHealth',
        ImportSource.samsungHealth => 'Samsung Health',
        ImportSource.other => 'Otra fuente',
      };
}

/// Cómo se repite el recordatorio de toma de tensión.
enum ReminderFrequency {
  daily,
  timesPerDay,
  fixedTimes;

  String get label => switch (this) {
        ReminderFrequency.daily => 'Una vez al día',
        ReminderFrequency.timesPerDay => 'Varias veces al día',
        ReminderFrequency.fixedTimes => 'Horarios fijos',
      };
}

/// Comparación con los umbrales que la persona ha guardado en su ficha.
///
/// No es una clasificación clínica: solo dice si el valor queda por encima,
/// dentro o por debajo de SU referencia.
enum ReferenceLevel {
  below,
  within,
  above;

  String get label => switch (this) {
        ReferenceLevel.below => 'Por debajo de tu referencia',
        ReferenceLevel.within => 'Dentro de tu referencia',
        ReferenceLevel.above => 'Por encima de tu referencia',
      };
}

/// Estado de una toma de medicación registrada.
enum DoseStatus {
  taken,
  skipped;

  String get label => switch (this) {
        DoseStatus.taken => 'Tomado',
        DoseStatus.skipped => 'Omitido',
      };
}

/// Cómo se repite el recordatorio de pedir al médico / renovar receta.
enum DoctorRequestRepeat {
  once,
  yearly,
  everyMonths;

  String get label => switch (this) {
        DoctorRequestRepeat.once => 'Solo una vez',
        DoctorRequestRepeat.yearly => 'Cada año (misma fecha)',
        DoctorRequestRepeat.everyMonths => 'Cada X meses',
      };
}
