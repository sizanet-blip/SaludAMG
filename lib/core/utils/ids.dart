import 'dart:math';

/// Identificador local. Basta para un diario que vive en un solo dispositivo.
String newLocalId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final noise = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '$time-$noise';
}
