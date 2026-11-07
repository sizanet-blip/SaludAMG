import '../enums/health_enums.dart';

/// Trazabilidad de una medición: de dónde salió y cuándo se copió al dispositivo.
class SyncInfo {
  const SyncInfo({
    required this.origin,
    required this.source,
    this.syncedAt,
    this.externalId,
    this.sourceLabel,
  });

  /// Registro escrito en SaludAMG, sin paso por Apple Salud ni Health Connect.
  const SyncInfo.manual()
      : origin = ReadingOrigin.manual,
        source = ImportSource.manual,
        syncedAt = null,
        externalId = null,
        sourceLabel = null;

  final ReadingOrigin origin;
  final ImportSource source;

  /// Momento en que SaludAMG copió el dato. Nulo si el origen es manual.
  final DateTime? syncedAt;

  /// Identidad en la plataforma de origen, para no importar dos veces lo mismo.
  final String? externalId;

  /// Nombre tal cual lo devuelve Salud o Health Connect (por ejemplo "OHealth").
  final String? sourceLabel;

  String get detail {
    final pieces = <String>[origin.label, source.label];
    final label = sourceLabel?.trim();
    if (label != null && label.isNotEmpty && label != source.label) {
      pieces.add(label);
    }
    return pieces.join(' · ');
  }
}
