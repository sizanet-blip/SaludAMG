import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_scope.dart';
import 'core/navigation.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/auth/auth_gate_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/lock_screen.dart';
import 'services/app_auth_service.dart';

class SaludAmgApp extends StatefulWidget {
  const SaludAmgApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  /// Cierra la sesión de UI y vuelve a la pantalla de acceso.
  static void signOut([BuildContext? context]) {
    final fromContext =
        context?.findAncestorStateOfType<_SaludAmgAppState>();
    (fromContext ?? _SaludAmgAppState.instance)?.signOut();
  }

  @override
  State<SaludAmgApp> createState() => _SaludAmgAppState();
}

class _SaludAmgAppState extends State<SaludAmgApp> with WidgetsBindingObserver {
  static _SaludAmgAppState? instance;

  var _unlocked = false;
  var _wasInBackground = false;
  var _authReady = !AppAuthService.isConfigured;
  var _checkingAuth = AppAuthService.isConfigured;

  bool get _lockEnabled {
    final lock = widget.dependencies.appLock.current();
    return lock.enabled && lock.hasPin;
  }

  String get _appKey => _checkingAuth
      ? 'checking'
      : (_authReady ? 'in-app' : 'auth-gate');

  @override
  void initState() {
    super.initState();
    instance = this;
    WidgetsBinding.instance.addObserver(this);
    _unlocked = !_lockEnabled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      consumePendingNotificationNavigation();
      _checkAuthSession();
    });
  }

  void signOut() {
    if (!mounted) return;
    // ValueKey del MaterialApp + navigator nuevo (evita pila/GlobalKey viejos).
    resetAppNavigatorKey();
    pendingNotificationPayload = null;
    setState(() {
      _authReady = false;
      _checkingAuth = false;
      // El PIN de app no debe tapar la pantalla de acceso.
      _unlocked = true;
      _wasInBackground = false;
    });
  }

  void _finishAuthCheck({required bool ready}) {
    if (!mounted) return;
    // Siempre navigator nuevo al salir de «checking»: reutilizar el GlobalKey
    // del MaterialApp anterior deja la UI colgada (spinner / no llega al login).
    resetAppNavigatorKey();
    setState(() {
      _authReady = ready;
      _checkingAuth = false;
      if (!ready) _unlocked = true;
    });
  }

  Future<void> _checkAuthSession() async {
    try {
      if (!AppAuthService.isConfigured) {
        _finishAuthCheck(ready: true);
        return;
      }
      final ok = await AppAuthService()
          .hasSession()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      _finishAuthCheck(ready: ok);
    } catch (e, st) {
      debugPrint('Auth check falló: $e\n$st');
      _finishAuthCheck(ready: false);
    }
  }

  @override
  void dispose() {
    if (identical(instance, this)) instance = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_lockEnabled) _wasInBackground = true;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _resyncNotifications();
      if (_lockEnabled && _wasInBackground) {
        _wasInBackground = false;
        if (_unlocked) {
          setState(() => _unlocked = false);
        }
      }
    }
  }

  Future<void> _resyncNotifications() async {
    try {
      final deps = widget.dependencies;
      await deps.notifications.syncSchedule(deps.reminders.current());
      await deps.notifications.syncMedicationSchedule(
        medications: deps.medications.getAll(),
        preferences: deps.medicationPreferences.current(),
      );
    } catch (error) {
      debugPrint('No se pudieron re-sincronizar avisos: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      dependencies: widget.dependencies,
      child: MaterialApp(
        // Como TiroAMG: al pasar a auth-gate se recrea el Navigator.
        key: ValueKey<String>(_appKey),
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'SaludAMG',
        theme: buildSaludAmgTheme(),
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              child ?? const SizedBox.shrink(),
              // Solo con sesión: el bloqueo no debe cubrir el login.
              if (_authReady && _lockEnabled && !_unlocked)
                Positioned.fill(
                  child: LockScreen(
                    onUnlocked: () {
                      setState(() {
                        _unlocked = true;
                        _wasInBackground = false;
                      });
                      consumePendingNotificationNavigation();
                    },
                  ),
                ),
            ],
          );
        },
        home: _checkingAuth
            ? const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              )
            : (_authReady
                ? const HomeScreen()
                : AuthGateScreen(
                    onAuthenticated: () {
                      resetAppNavigatorKey();
                      setState(() {
                        _authReady = true;
                        _unlocked = !_lockEnabled;
                      });
                    },
                  )),
      ),
    );
  }
}
