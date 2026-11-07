/// Preferencias globales de medicación (qué bloques están activos).
class MedicationPreferences {
  const MedicationPreferences({
    required this.trackDoses,
    required this.trackStock,
    required this.reorderReminders,
    required this.doctorRequestReminders,
    required this.showHomeButton,
  });

  static const storageKey = 'med_prefs';

  factory MedicationPreferences.defaults() {
    return const MedicationPreferences(
      trackDoses: true,
      trackStock: false,
      reorderReminders: false,
      doctorRequestReminders: true,
      showHomeButton: true,
    );
  }

  /// Mostrar y guardar tomado/omitido.
  final bool trackDoses;

  /// Controlar unidades restantes por medicación.
  final bool trackStock;

  /// Aviso diario para pedir medicación cuando el stock es bajo.
  final bool reorderReminders;

  /// Avisos y tarjeta de «pedir al médico / renovar receta».
  final bool doctorRequestReminders;

  /// Botón de medicación en la pantalla de inicio.
  final bool showHomeButton;

  MedicationPreferences copyWith({
    bool? trackDoses,
    bool? trackStock,
    bool? reorderReminders,
    bool? doctorRequestReminders,
    bool? showHomeButton,
  }) {
    return MedicationPreferences(
      trackDoses: trackDoses ?? this.trackDoses,
      trackStock: trackStock ?? this.trackStock,
      reorderReminders: reorderReminders ?? this.reorderReminders,
      doctorRequestReminders:
          doctorRequestReminders ?? this.doctorRequestReminders,
      showHomeButton: showHomeButton ?? this.showHomeButton,
    );
  }

  Map<String, dynamic> toJson() => {
        'trackDoses': trackDoses,
        'trackStock': trackStock,
        'reorderReminders': reorderReminders,
        'doctorRequestReminders': doctorRequestReminders,
        'showHomeButton': showHomeButton,
      };

  factory MedicationPreferences.fromJson(Map<String, dynamic> json) {
    final defaults = MedicationPreferences.defaults();
    return MedicationPreferences(
      trackDoses: json['trackDoses'] as bool? ?? defaults.trackDoses,
      trackStock: json['trackStock'] as bool? ?? defaults.trackStock,
      reorderReminders:
          json['reorderReminders'] as bool? ?? defaults.reorderReminders,
      doctorRequestReminders: json['doctorRequestReminders'] as bool? ??
          defaults.doctorRequestReminders,
      showHomeButton:
          json['showHomeButton'] as bool? ?? defaults.showHomeButton,
    );
  }
}
