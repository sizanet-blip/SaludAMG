import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/app_lock_config.dart';
import '../../services/app_auth_service.dart';
import '../../services/app_lock_service.dart';
import '../widgets/app_section_card.dart';
import '../widgets/salud_amg_app_bar.dart';

class LockSettingsScreen extends StatefulWidget {
  const LockSettingsScreen({super.key});

  @override
  State<LockSettingsScreen> createState() => _LockSettingsScreenState();
}

class _LockSettingsScreenState extends State<LockSettingsScreen> {
  late AppLockConfig _config;
  var _ready = false;
  var _bioAvailable = false;
  var _saving = false;
  final _pin = TextEditingController();
  final _pinConfirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _pin.dispose();
    _pinConfirm.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final lock = AppScope.of(context).appLock;
    final bio = await lock.canCheckBiometrics();
    if (!mounted) return;
    setState(() {
      _config = lock.current();
      _bioAvailable = bio;
      _ready = true;
    });
  }

  Future<void> _save() async {
    var config = _config;
    final pin = _pin.text.trim();
    final confirm = _pinConfirm.text.trim();

    if (config.enabled) {
      if (!config.hasPin && pin.isEmpty) {
        _message('Define un PIN de 4 a 8 dígitos.');
        return;
      }
      if (pin.isNotEmpty) {
        if (pin.length < 4 || pin.length > 8) {
          _message('El PIN debe tener entre 4 y 8 dígitos.');
          return;
        }
        if (pin != confirm) {
          _message('Los PIN no coinciden.');
          return;
        }
        config = config.copyWith(pinHash: AppLockService.hashPin(pin));
      }
      if (!config.hasPin && pin.isEmpty) {
        _message('Define un PIN para activar el bloqueo.');
        return;
      }
    } else {
      config = config.copyWith(enabled: false);
    }

    if (config.useBiometrics && !_bioAvailable) {
      config = config.copyWith(useBiometrics: false);
    }
    // Sin cuenta AMG no hay contraseña de respaldo: la huella necesita PIN.
    if (config.useBiometrics &&
        !config.pinActive &&
        !AppAuthService.isConfigured) {
      _message('Sin cuenta AMG, la huella necesita también un PIN.');
      return;
    }

    setState(() => _saving = true);
    await AppScope.of(context).appLock.save(config);
    if (!mounted) return;
    setState(() {
      _config = config;
      _saving = false;
      _pin.clear();
      _pinConfirm.clear();
    });
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    messenger.showSnackBar(const SnackBar(content: Text('Bloqueo guardado.')));
  }

  /// Antes de activar la huella se comprueba que funciona.
  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      final ok = await AppScope.of(context).appLock.authenticateBiometrics();
      if (!ok) {
        if (mounted) _message('No se ha podido comprobar la huella.');
        return;
      }
    }
    if (!mounted) return;
    setState(() => _config = _config.copyWith(useBiometrics: value));
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SaludAmgAppBar(section: 'Bloqueo'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'Protege ficha, mediciones y medicaciones en este teléfono.',
            style: TextStyle(color: AppColors.subtitle),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'Acceso',
            icon: Icons.lock_outline,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Abrir con huella'),
                  subtitle: Text(
                    _bioAvailable
                        ? (AppAuthService.isConfigured
                              ? 'Si falla, entras con la contraseña de tu cuenta AMG.'
                              : 'Necesita también un PIN.')
                        : 'Registra una huella o tu cara en los ajustes del '
                              'teléfono para usarla aquí.',
                  ),
                  value: _config.useBiometrics && _bioAvailable,
                  onChanged: _bioAvailable ? _toggleBiometrics : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.pin_outlined),
                  title: const Text('Pedir PIN al abrir'),
                  value: _config.enabled,
                  onChanged: (value) => setState(
                    () => _config = _config.copyWith(enabled: value),
                  ),
                ),
                if (_config.enabled) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: _config.hasPin
                          ? 'Nuevo PIN (opcional)'
                          : 'PIN (4–8 dígitos)',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pinConfirm,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Repetir PIN',
                      counterText: '',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
