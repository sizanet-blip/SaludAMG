import 'dart:convert';

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

  static String hashPin(String pin) {
    final digest = sha256.convert(utf8.encode('saludamg|$pin'));
    return digest.toString();
  }

  bool verifyPin(String pin, AppLockConfig config) {
    if (!config.hasPin) return false;
    return hashPin(pin) == config.pinHash;
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
