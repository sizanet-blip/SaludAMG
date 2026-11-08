import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Copias e informes se crean en la carpeta temporal para compartirlos.
/// No se borran justo después porque la app que los recibe (Drive, correo…)
/// puede seguir leyéndolos; se borran los que tienen más de unos minutos,
/// al arrancar y antes de crear otro.
abstract final class TempFiles {
  static const _prefix = 'saludamg_';
  static const maxAge = Duration(minutes: 10);

  static Future<void> cleanOld({Directory? directory, DateTime? now}) async {
    try {
      final dir = directory ?? await getTemporaryDirectory();
      if (!await dir.exists()) return;
      final limit = (now ?? DateTime.now()).subtract(maxAge);
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith(_prefix)) continue;
        if ((await entity.lastModified()).isBefore(limit)) {
          await entity.delete();
        }
      }
    } catch (error) {
      debugPrint('No se pudieron limpiar temporales: $error');
    }
  }
}
