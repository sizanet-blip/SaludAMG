import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/app_lock_config.dart';
import '../../services/app_auth_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pin = TextEditingController();
  var _error = '';
  var _biometricsAvailable = false;
  var _ready = false;
  AppLockConfig? _config;

  /// Fallos seguidos y espera (se guardan para que cerrar la app no los reinicie).
  static const _kFailed = 'lock_failed_attempts';
  static const _kBlockedUntil = 'lock_blocked_until';
  static const _freeAttempts = 5;
  var _failed = 0;
  DateTime? _blockedUntil;
  Timer? _ticker;
  var _canRecover = false;
  var _recovering = false;

  /// Con PIN (y quizá huella) o solo con huella.
  bool get _pinMode => _config?.pinActive ?? true;
  var _checking = false;
  String? _username;
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pin.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final lock = AppScope.of(context).appLock;
    final config = lock.current();
    final canBio = config.useBiometrics && await lock.canCheckBiometrics();
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_kBlockedUntil);
    final user = await AppAuthService().username();
    if (!mounted) return;
    setState(() {
      _config = config;
      _ready = true;
      _biometricsAvailable = canBio;
      _failed = prefs.getInt(_kFailed) ?? 0;
      _blockedUntil = until == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(until);
      _username = user;
      _canRecover =
          AppAuthService.isConfigured && (user?.trim().isNotEmpty ?? false);
    });
    _startTickerIfBlocked();
    if (canBio) {
      await _tryBiometrics();
    }
  }

  Future<void> _tryBiometrics() async {
    final ok = await AppScope.of(context).appLock.authenticateBiometrics();
    if (!mounted) return;
    if (ok) await _unlock();
  }

  Duration get _remaining {
    final until = _blockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get _blocked => _remaining > Duration.zero;

  void _startTickerIfBlocked() {
    _ticker?.cancel();
    if (!_blocked) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (!_blocked) timer.cancel();
    });
  }

  Future<void> _resetAttempts() async {
    _failed = 0;
    _blockedUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFailed);
    await prefs.remove(_kBlockedUntil);
  }

  Future<void> _unlock() async {
    await _resetAttempts();
    if (mounted) widget.onUnlocked();
  }

  Future<void> _submitPin() async {
    final config = _config;
    if (!_ready || config == null || _blocked) return;
    final lock = AppScope.of(context).appLock;
    if (lock.verifyPin(_pin.text.trim(), config)) {
      await lock.upgradePinIfLegacy(_pin.text.trim());
      await _unlock();
      return;
    }
    _failed++;
    _pin.clear();
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFailed, _failed);
    if (_failed >= _freeAttempts) {
      // 30 s tras 5 fallos; se dobla con cada fallo más (máx. 15 min).
      final extra = (_failed - _freeAttempts).clamp(0, 5);
      final seconds = (30 * (1 << extra)).clamp(30, 900);
      _blockedUntil = DateTime.now().add(Duration(seconds: seconds));
      await prefs.setInt(_kBlockedUntil, _blockedUntil!.millisecondsSinceEpoch);
    }
    if (!mounted) return;
    setState(() {
      final left = _freeAttempts - _failed;
      _error = left > 0
          ? 'PIN incorrecto. Te quedan $left intentos.'
          : 'PIN incorrecto.';
    });
    _startTickerIfBlocked();
  }

  /// Olvidé el PIN: con la contraseña de la cuenta AMG se quita el PIN.
  /// Va en la propia pantalla: está encima del navegador y un diálogo
  /// quedaría tapado.
  Future<void> _submitRecovery() async {
    final password = _password.text;
    if (password.isEmpty || _checking) return;
    final auth = AppAuthService();
    final user = await auth.username();
    if (user == null || !mounted) return;
    setState(() {
      _checking = true;
      _error = '';
    });
    final result = await auth.login(username: user, password: password);
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _checking = false;
        _error =
            'No se ha podido comprobar la contraseña. '
                    '${result.message ?? ''}'
                .trim();
      });
      return;
    }
    _password.clear();
    if (_pinMode) {
      // Olvidó el PIN: se quita (la huella, si estaba, sigue).
      final lock = AppScope.of(context).appLock;
      await lock.save(lock.current().copyWith(enabled: false, pinHash: ''));
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'PIN quitado. Puedes poner otro en Configuración → Bloqueo.',
          ),
        ),
      );
    }
    // Solo huella: la contraseña de la cuenta sirve para entrar esta vez.
    await _unlock();
  }

  void _setRecovering(bool value) {
    setState(() {
      _recovering = value;
      _checking = false;
      _error = '';
      _password.clear();
    });
  }

  List<Widget> _recoveryFields() {
    return [
      Text(
        _pinMode
            ? 'Escribe la contraseña de tu cuenta AMG ($_username). '
                  'Se quitará el PIN y podrás poner otro en Configuración. '
                  'Necesitas conexión a internet.'
            : 'Escribe la contraseña de tu cuenta AMG ($_username) para '
                  'entrar sin huella. Necesitas conexión a internet.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.subtitle),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _password,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Contraseña de la cuenta'),
        onSubmitted: (_) => _submitRecovery(),
      ),
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          _error,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.danger),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _checking ? null : _submitRecovery,
        child: Text(
          _checking ? 'Comprobando…' : (_pinMode ? 'Quitar PIN' : 'Entrar'),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _checking ? null : () => _setRecovering(false),
        child: Text(_pinMode ? 'Volver al PIN' : 'Volver a la huella'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: AppColors.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'SaludAMG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.title,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _pinMode
                      ? 'Introduce el PIN para ver tus datos de salud.'
                      : 'Usa tu huella para ver tus datos de salud.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.subtitle),
                ),
                const SizedBox(height: 28),
                if (_recovering)
                  ..._recoveryFields()
                else ...[
                  if (_pinMode) ...[
                    TextField(
                      controller: _pin,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'PIN',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _submitPin(),
                    ),
                    if (_blocked) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Demasiados intentos. Espera ${_remaining.inSeconds + 1} s.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ] else if (_error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _ready && !_blocked ? _submitPin : null,
                      child: const Text('Desbloquear'),
                    ),
                  ],
                  if (_biometricsAvailable) ...[
                    const SizedBox(height: 12),
                    _pinMode
                        ? OutlinedButton.icon(
                            onPressed: _tryBiometrics,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Usar huella'),
                          )
                        : FilledButton.icon(
                            onPressed: _tryBiometrics,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Usar huella'),
                          ),
                  ],
                  if (_canRecover) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _setRecovering(true),
                      child: Text(
                        _pinMode
                            ? '¿Olvidaste el PIN?'
                            : 'Entrar con la contraseña de la cuenta',
                      ),
                    ),
                  ],
                ],
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
