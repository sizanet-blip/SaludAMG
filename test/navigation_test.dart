import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salud_amg/core/navigation.dart';

class _Pushes extends NavigatorObserver {
  final names = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    names.add(route.settings.name);
  }
}

void main() {
  tearDown(() {
    pendingNotificationPayload = null;
    notificationNavigationReady = false;
  });

  testWidgets('sin sesión o bloqueada, el aviso se guarda y se abre después',
      (tester) async {
    resetAppNavigatorKey();
    notificationNavigationReady = false;
    final pushes = _Pushes();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        navigatorObservers: [pushes],
        home: const Text('acceso'),
      ),
    );
    pushes.names.clear();

    openMeasurementFromNotification();
    await tester.pump();
    // No se abre encima del acceso: queda pendiente.
    expect(pendingNotificationPayload, 'measurement');
    expect(pushes.names, isEmpty);

    // Sin estar lista, consumir no hace nada.
    consumePendingNotificationNavigation();
    await tester.pump();
    expect(pendingNotificationPayload, 'measurement');
    expect(pushes.names, isEmpty);

    notificationNavigationReady = true;
    consumePendingNotificationNavigation();
    await tester.pump();
    expect(pendingNotificationPayload, isNull);
    expect(pushes.names, ['/measurement']);
    // Sin AppScope en este test la pantalla no puede cargar datos.
    tester.takeException();
  });
}
