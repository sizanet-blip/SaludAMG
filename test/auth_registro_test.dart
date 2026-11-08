import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salud_amg/presentation/screens/auth/auth_gate_screen.dart';
import 'package:salud_amg/services/app_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('registro', () {
    Future<AppAuthResult> registrar(String email, String repetido) {
      return AppAuthService().register(
        username: 'usuario',
        password: 'abc123',
        email: email,
        emailRepeat: repetido,
        acceptedLegal: true,
      );
    }

    test('exige email', () async {
      final r = await registrar('  ', '  ');
      expect(r.ok, isFalse);
      expect(r.message, contains('obligatorio'));
    });

    test('exige que los emails coincidan', () async {
      final r = await registrar('uno@example.test', 'dos@example.test');
      expect(r.ok, isFalse);
      expect(r.message, 'Los emails no coinciden.');
    });

    test('no distingue mayúsculas ni espacios al comparar', () async {
      final r = await registrar(' Uno@Example.test ', 'uno@example.test');
      expect(r.message, isNot('Los emails no coinciden.'));
    });
  });

  group('recuperación', () {
    test('pide el email', () async {
      final r = await AppAuthService().requestPasswordReset(email: ' ');
      expect(r.ok, isFalse);
      expect(r.message, 'Escribe tu email.');
    });
  });

  group('primera activación (build enlazado al panel)', () {
    final enlazado = AppAuthService.isConfigured;

    Future<void> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: AuthGateScreen(onAuthenticated: () {})),
      );
      // La pantalla lee el estado guardado de forma asíncrona al abrirse.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('dispositivo nuevo: ofrece crear cuenta con email repetido', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await abrir(tester);

      expect(find.text('Crear cuenta'), findsOneWidget);
      expect(find.text('Olvidé mi contraseña'), findsOneWidget);

      // Avisos de maquetación ajenos a esta prueba (la fuente de test es muy ancha).
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        final text = details.exceptionAsString();
        if (!text.contains('overflowed') && !text.contains('ListTile')) {
          original?.call(details);
        }
      };
      try {
        await tester.ensureVisible(find.text('Crear cuenta'));
        await tester.tap(find.text('Crear cuenta'));
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = original;
      }

      expect(find.widgetWithText(TextField, 'Repetir email'), findsOneWidget);
    }, skip: !enlazado);

    testWidgets('ya activado: no ofrece crear cuenta', (tester) async {
      SharedPreferences.setMockInitialValues({'app_auth_activated': true});
      await abrir(tester);

      expect(find.text('Crear cuenta'), findsNothing);
      expect(find.text('Olvidé mi contraseña'), findsOneWidget);
    }, skip: !enlazado);

    testWidgets('instalación antigua con usuario: no ofrece crear cuenta', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'app_auth_username': 'ana'});
      await abrir(tester);

      expect(find.text('Crear cuenta'), findsNothing);
    }, skip: !enlazado);

    testWidgets('recuperar pide el email y envía enlace', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await abrir(tester);

      await tester.ensureVisible(find.text('Olvidé mi contraseña'));
      await tester.tap(find.text('Olvidé mi contraseña'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      expect(find.text('Enviar enlace'), findsOneWidget);
      expect(find.textContaining('Código de recuperación'), findsNothing);
    }, skip: !enlazado);
  });
}
