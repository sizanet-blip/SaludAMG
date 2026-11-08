import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../domain/entities/app_lock_config.dart';
import '../domain/repositories/repositories.dart';

class AppLockService {
  AppLockService(this._repository);

  final AppLockRepository _repository;
  final _auth = LocalAuthentication();

  AppLockConfig current() => _repository.current();

  Future<void> save(AppLockConfig config) => _repository.save(config);

  static const _rounds = 20000;

  /// PIN guardado como `v2$sal$resumen`: sal aleatoria por PIN y muchas
  /// vueltas, para que no se pueda adivinar con una tabla precalculada.
  static String hashPin(String pin, {List<int>? salt}) {
    final s =
        salt ?? List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final saltHex = s.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return ['v2', saltHex, _stretch(pin, saltHex)].join(r'$');
  }

  static String _stretch(String pin, String saltHex) {
    List<int> block = utf8.encode('saludamg|$saltHex|$pin');
    for (var i = 0; i < _rounds; i++) {
      block = sha256.convert(block).bytes;
    }
    return block.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Formato de las primeras versiones (misma sal para todos).
  static String _legacyHash(String pin) =>
      sha256.convert(utf8.encode('saludamg|$pin')).toString();

  static bool isLegacyHash(String stored) => !stored.startsWith(r'v2$');

  bool verifyPin(String pin, AppLockConfig config) {
    if (!config.hasPin) return false;
    final stored = config.pinHash;
    if (isLegacyHash(stored)) return _legacyHash(pin) == stored;
    final parts = stored.split(r'$');
    if (parts.length != 3) return false;
    return _stretch(pin, parts[1]) == parts[2];
  }

  /// Tras un PIN correcto en formato antiguo, se guarda en el nuevo.
  Future<void> upgradePinIfLegacy(String pin) async {
    final config = current();
    if (!config.hasPin || !isLegacyHash(config.pinHash)) return;
    if (!verifyPin(pin, config)) return;
    await save(config.copyWith(pinHash: hashPin(pin)));
  }

  Future<bool> canCheckBiometrics() async {
    try {
      // Hace falta una huella/cara registrada, no solo que el móvil la admita.
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticateBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Desbloquea SaludAMG para ver tus datos de salud',
        biometricOnly: true,
      );
    } on PlatformException {
      return false;
    }
  }
}
