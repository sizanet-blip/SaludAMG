import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/app_lock_config.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final lock = AppScope.of(context).appLock;
    final config = lock.current();
    final canBio = config.useBiometrics && await lock.canCheckBiometrics();
    if (!mounted) return;
    setState(() {
      _config = config;
      _ready = true;
      _biometricsAvailable = canBio;
    });
    if (canBio) {
      await _tryBiometrics();
    }
  }

  Future<void> _tryBiometrics() async {
    final ok = await AppScope.of(context).appLock.authenticateBiometrics();
    if (!mounted) return;
    if (ok) widget.onUnlocked();
  }

  void _submitPin() {
    final config = _config;
    if (!_ready || config == null) return;
    final lock = AppScope.of(context).appLock;
    if (lock.verifyPin(_pin.text.trim(), config)) {
      widget.onUnlocked();
      return;
    }
    setState(() => _error = 'PIN incorrecto');
    HapticFeedback.heavyImpact();
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
                const Text(
                  'Introduce el PIN para ver tus datos de salud.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.subtitle),
                ),
                const SizedBox(height: 28),
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
                  onPressed: _ready ? _submitPin : null,
                  child: const Text('Desbloquear'),
                ),
                if (_biometricsAvailable) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _tryBiometrics,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Usar biometría'),
                  ),
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
