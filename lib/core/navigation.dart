import 'package:flutter/material.dart';

import '../presentation/screens/measurement_form_screen.dart';
import '../presentation/screens/medications_screen.dart';

/// Navegación global (p. ej. al tocar una notificación).
/// No es `final`: al cerrar sesión se sustituye para vaciar la pila.
GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Nuevo navigator (p. ej. tras logout) para no reutilizar rutas de la sesión.
void resetAppNavigatorKey() {
  appNavigatorKey = GlobalKey<NavigatorState>();
}

/// Payload pendiente si la app aún no ha montado el navigator.
String? pendingNotificationPayload;

/// `true` solo con sesión iniciada y la app desbloqueada. Mientras no lo esté
/// (arranque, pantalla de acceso o PIN), el toque en un aviso se guarda y se
/// abre después; si no, se perdía al cambiar de pantalla o se abría encima
/// del acceso.
bool notificationNavigationReady = false;

void openMedicationsFromNotification() {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null || !notificationNavigationReady) {
    pendingNotificationPayload = 'medications';
    return;
  }
  _pushMedications(navigator);
}

void openMeasurementFromNotification() {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null || !notificationNavigationReady) {
    pendingNotificationPayload = 'measurement';
    return;
  }
  _pushMeasurement(navigator);
}

void consumePendingNotificationNavigation() {
  if (pendingNotificationPayload == null || !notificationNavigationReady) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final pending = pendingNotificationPayload;
    final navigator = appNavigatorKey.currentState;
    if (pending == null || navigator == null || !notificationNavigationReady) {
      return;
    }
    pendingNotificationPayload = null;
    if (pending == 'medications') {
      _pushMedications(navigator);
    } else if (pending == 'measurement') {
      _pushMeasurement(navigator);
    }
  });
  // Por si se llama fuera de un frame: que el callback llegue a ejecutarse.
  WidgetsBinding.instance.scheduleFrame();
}

void _pushMedications(NavigatorState navigator) {
  // Evita apilar varias MedicationsScreen si ya estamos ahí o tras varios taps.
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/medications'),
      builder: (_) => const MedicationsScreen(),
    ),
    (route) => route.isFirst,
  );
}

void _pushMeasurement(NavigatorState navigator) {
  navigator.push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/measurement'),
      builder: (_) => const MeasurementFormScreen(),
    ),
  );
}
