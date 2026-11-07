import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'license_api_http.dart';

/// Registro silencioso en el inventario unificado del panel AMG.
///
/// Build: `--dart-define=INSTALLATION_API_URL=https://…` (o `LICENSE_API_URL`).
class InstallationService {
  InstallationService();

  static const String appName = 'SaludAMG';

  static const String _apiFromInstall = String.fromEnvironment(
    'INSTALLATION_API_URL',
    defaultValue: '',
  );
  static const String _apiFromLicense = String.fromEnvironment(
    'LICENSE_API_URL',
    defaultValue: '',
  );

  static const _kDeviceId = 'installation_device_id';
  static const _kLicenseKey = 'installation_license_key';
  static const _kEmail = 'installation_email';
  static const _kPrivacyAccepted = 'installation_privacy_accepted';
  static const _kLastSyncAt = 'installation_last_sync_at';

  static String get apiBaseUrl {
    final a = _apiFromInstall.trim();
    if (a.isNotEmpty) return a;
    return _apiFromLicense.trim();
  }

  static bool get isConfigured => apiBaseUrl.isNotEmpty;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> hasAcceptedPrivacy() async {
    final p = await _prefs;
    return p.getBool(_kPrivacyAccepted) ?? false;
  }

  Future<void> acceptPrivacy() async {
    final p = await _prefs;
    await p.setBool(_kPrivacyAccepted, true);
  }

  Future<String?> storedEmail() async {
    final p = await _prefs;
    final e = p.getString(_kEmail)?.trim();
    return (e == null || e.isEmpty) ? null : e;
  }

  Future<String?> storedLicenseKey() async {
    final p = await _prefs;
    final k = p.getString(_kLicenseKey)?.trim();
    return (k == null || k.isEmpty) ? null : k;
  }

  Future<String> deviceId() async {
    final p = await _prefs;
    final existing = p.getString(_kDeviceId)?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateDeviceId();
    await p.setString(_kDeviceId, generated);
    return generated;
  }

  /// Registro anónimo (o con email si ya se identificó antes).
  Future<InstallationSyncResult> sync({String? email}) async {
    if (!isConfigured) {
      return const InstallationSyncResult(
        ok: false,
        skipped: true,
        message: 'API de instalaciones no configurada.',
      );
    }

    try {
      final package = await PackageInfo.fromPlatform();
      final id = await deviceId();
      final p = await _prefs;
      final knownEmail = (email ?? p.getString(_kEmail))?.trim() ?? '';

      final body = <String, dynamic>{
        'device_id': id,
        'app_name': appName,
        'platform': _platformKey,
        'app_version': package.version,
        'build_number': package.buildNumber,
        if (knownEmail.isNotEmpty) 'email': knownEmail,
      };

      final response = await _postJson('/installations/register', body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[Installation] register HTTP ${response.statusCode}: ${response.body}',
        );
        return InstallationSyncResult(
          ok: false,
          message: 'No se pudo registrar (${response.statusCode}).',
        );
      }

      await _persistPayload(response.body, email: knownEmail);
      return const InstallationSyncResult(
        ok: true,
        message: 'Instalación registrada.',
      );
    } on SocketException {
      return const InstallationSyncResult(
        ok: false,
        message: 'Sin conexión.',
      );
    } catch (e, st) {
      debugPrint('[Installation] sync falló: $e\n$st');
      return InstallationSyncResult(ok: false, message: e.toString());
    }
  }

  /// Asocia un email opcional a la instalación (identify).
  Future<InstallationSyncResult> identify(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      return const InstallationSyncResult(
        ok: false,
        message: 'Introduce un email válido.',
      );
    }
    if (!isConfigured) {
      return const InstallationSyncResult(
        ok: false,
        skipped: true,
        message: 'API de instalaciones no configurada.',
      );
    }

    try {
      final package = await PackageInfo.fromPlatform();
      final id = await deviceId();
      final body = <String, dynamic>{
        'device_id': id,
        'app_name': appName,
        'email': trimmed,
        'platform': _platformKey,
        'app_version': package.version,
        'build_number': package.buildNumber,
      };

      var response = await _postJson('/installations/identify', body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        response = await _postJson('/installations/register', body);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'No se pudo identificar (${response.statusCode}).';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] is String) {
            message = data['message'] as String;
          }
        } catch (_) {}
        return InstallationSyncResult(ok: false, message: message);
      }

      await _persistPayload(response.body, email: trimmed);
      return const InstallationSyncResult(
        ok: true,
        message: 'Email asociado a la instalación.',
      );
    } on SocketException {
      return const InstallationSyncResult(
        ok: false,
        message: 'Sin conexión.',
      );
    } catch (e, st) {
      debugPrint('[Installation] identify falló: $e\n$st');
      return InstallationSyncResult(ok: false, message: e.toString());
    }
  }

  Future<void> _persistPayload(String body, {required String email}) async {
    final p = await _prefs;
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        final license = data['license'];
        if (license is Map) {
          final key = (license['license_key'] ?? license['key'] ?? '')
              .toString()
              .trim();
          if (key.isNotEmpty) {
            await p.setString(_kLicenseKey, key);
          }
        }
      }
    } catch (_) {}
    if (email.isNotEmpty) {
      await p.setString(_kEmail, email);
    }
    await p.setString(_kLastSyncAt, DateTime.now().toUtc().toIso8601String());
  }

  Future<http.Response> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    return LicenseApiHttp.postJson(
      baseUrl: apiBaseUrl,
      path: path,
      body: jsonEncode(body),
      timeout: const Duration(seconds: 10),
    );
  }

  String _generateDeviceId() {
    final rnd = Random.secure();
    final randomPart =
        List.generate(24, (_) => rnd.nextInt(16).toRadixString(16)).join();
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    return 'samg-$ts-$randomPart';
  }

  String get _platformKey {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}

class InstallationSyncResult {
  const InstallationSyncResult({
    required this.ok,
    this.skipped = false,
    this.message,
  });

  final bool ok;
  final bool skipped;
  final String? message;
}
