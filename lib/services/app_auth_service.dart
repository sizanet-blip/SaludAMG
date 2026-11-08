import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../legal/privacy_content.dart';
import '../legal/terms_content.dart';
import 'license_api_http.dart';

/// Auth unificado AMG (panel Yii2 `/app-auth/*`).
class AppAuthService {
  AppAuthService();

  static const String appId = 'SaludAMG';
  static String get privacyPolicyVersion => PrivacyContent.acceptanceVersion;
  static String get termsVersion => TermsContent.acceptanceVersion;

  static const String _apiAuth = String.fromEnvironment(
    'APP_AUTH_API_URL',
    defaultValue: '',
  );
  static const String _apiInstall = String.fromEnvironment(
    'INSTALLATION_API_URL',
    defaultValue: '',
  );
  static const String _apiLicense = String.fromEnvironment(
    'LICENSE_API_URL',
    defaultValue: '',
  );

  static const _kToken = 'app_auth_token';
  static const _kUsername = 'app_auth_username';
  static const _kStatus = 'app_auth_status';
  static const _kDeviceId = 'installation_device_id';
  static const _kActivated = 'app_auth_activated';
  static const _kPrivacyAcceptedVer = 'app_auth_privacy_accepted_version';
  static const _kTermsAcceptedVer = 'app_auth_terms_accepted_version';

  static String get apiBaseUrl {
    for (final c in [_apiAuth, _apiInstall, _apiLicense]) {
      final t = c.trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  static bool get isConfigured => apiBaseUrl.isNotEmpty;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> token() async => (await _prefs).getString(_kToken);

  Future<String?> username() async => (await _prefs).getString(_kUsername);

  Future<String?> status() async => (await _prefs).getString(_kStatus);

  Future<bool> hasSession() async {
    final t = await token();
    return t != null && t.isNotEmpty;
  }

  Future<String> deviceId() async {
    final p = await _prefs;
    final existing = p.getString(_kDeviceId)?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateDeviceId();
    await p.setString(_kDeviceId, generated);
    return generated;
  }

  Future<AppAuthResult> register({
    required String username,
    required String password,
    required String email,
    required String emailRepeat,
    required bool acceptedLegal,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      return const AppAuthResult(
        ok: false,
        message: 'El email es obligatorio: se usa para recuperar la contraseña.',
      );
    }
    if (cleanEmail != emailRepeat.trim().toLowerCase()) {
      return const AppAuthResult(
        ok: false,
        message: 'Los emails no coinciden.',
      );
    }

    if (!acceptedLegal) {
      return const AppAuthResult(
        ok: false,
        message: 'Debes aceptar privacidad y condiciones.',
      );
    }
    if (!isConfigured) {
      return const AppAuthResult(
        ok: false,
        skipped: true,
        message: 'API no configurada.',
      );
    }

    try {
      final package = await PackageInfo.fromPlatform();
      final id = await deviceId();
      final body = {
        'username': username.trim(),
        'password': password,
        'email': cleanEmail,
        'email_repeat': emailRepeat.trim().toLowerCase(),
        'app_id': appId,
        'device_id': id,
        'platform': _platformKey,
        'app_version': package.version,
        'build_number': package.buildNumber,
        'privacy_accepted_version': privacyPolicyVersion,
        'terms_accepted_version': termsVersion,
      };
      final response = await _post('/app-auth/register', body);
      final data = _decode(response.body);
      final code = data['code']?.toString();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final account = data['account'];
        final status = account is Map
            ? account['status']?.toString()
            : 'pending';
        final p = await _prefs;
        await p.setString(_kUsername, username.trim());
        await p.setString(
          _kStatus,
          code == 'app_access_pending' ? 'app_access_pending' : (status ?? 'pending'),
        );
        await p.setBool(_kActivated, true);
        await _syncLocalLegalAcceptance();
        return AppAuthResult(
          ok: true,
          pending: true,
          message: data['message']?.toString() ?? 'Solicitud enviada.',
          code: code,
        );
      }
      return AppAuthResult(
        ok: false,
        alreadyHasAccess: code == 'already_has_access',
        message: data['message']?.toString() ??
            'Error ${response.statusCode}',
        code: code,
      );
    } catch (e) {
      return AppAuthResult(ok: false, message: e.toString());
    }
  }

  /// ¿Privacidad + condiciones ya aceptadas en local para la versión actual?
  Future<bool> hasLocalLegalAcceptance() async {
    final p = await _prefs;
    final pv = p.getString(_kPrivacyAcceptedVer);
    final tv = p.getString(_kTermsAcceptedVer);
    return (pv == privacyPolicyVersion || pv == PrivacyContent.version) &&
        (tv == termsVersion || tv == TermsContent.version);
  }

  Future<void> _syncLocalLegalAcceptance() async {
    final p = await _prefs;
    await p.setString(_kPrivacyAcceptedVer, privacyPolicyVersion);
    await p.setString(_kTermsAcceptedVer, termsVersion);
  }

  /// Guarda en local que el usuario marcó privacidad/condiciones (versión actual).
  Future<void> markLegalAcceptedLocally() => _syncLocalLegalAcceptance();

  Future<AppAuthResult> login({
    required String username,
    required String password,
    bool acceptedLegal = false,
  }) async {
    if (!isConfigured) {
      return const AppAuthResult(
        ok: false,
        skipped: true,
        message: 'API no configurada.',
      );
    }
    try {
      final package = await PackageInfo.fromPlatform();
      final id = await deviceId();
      // Como TiroAMG / panel Yii2: NUNCA enviar privacy_current_version ni
      // terms_current_version. Si van informados, el panel responde 428 en bucle
      // aunque mandes privacy_accepted_version (y aunque marques la casilla).
      if (acceptedLegal) {
        await _syncLocalLegalAcceptance();
      }
      final sendAcceptance =
          acceptedLegal || await hasLocalLegalAcceptance();
      final body = <String, dynamic>{
        'username': username.trim(),
        'password': password,
        'app_id': appId,
        'device_id': id,
        'platform': _platformKey,
        'app_version': package.version,
        'build_number': package.buildNumber,
        if (sendAcceptance) ...{
          'privacy_accepted_version': privacyPolicyVersion,
          'terms_accepted_version': termsVersion,
        },
      };
      assert(
        !body.containsKey('privacy_current_version') &&
            !body.containsKey('terms_current_version'),
        'No enviar *_current_version: provoca 428 en bucle',
      );
      debugPrint(
        '[AppAuth] login sendAcceptance=$sendAcceptance '
        'privacy=${sendAcceptance ? privacyPolicyVersion : "-"}',
      );
      final response = await _post('/app-auth/login', body);
      final data = _decode(response.body);
      final account = data['account'];
      final status = account is Map ? account['status']?.toString() : null;
      final code = data['code']?.toString();
      debugPrint(
        '[AppAuth] login ← HTTP ${response.statusCode} code=$code '
        'status=$status msg=${data['message']}',
      );

      final msg = data['message']?.toString() ?? '';
      final accessPending = code == 'app_access_pending' ||
          status == 'app_access_pending';
      final accountPending =
          status == 'pending' || code == 'pending';
      // Producción a veces no manda `code`; detectar también por mensaje.
      final canRequest = _asTruthy(data['can_request_access']) ||
          code == 'no_app_access' ||
          _messageLooksLikeNoAppAccess(msg);

      if (response.statusCode == 403 && (accountPending || accessPending)) {
        final p = await _prefs;
        await p.setString(_kUsername, username.trim());
        await p.setString(
          _kStatus,
          accessPending ? 'app_access_pending' : 'pending',
        );
        await p.remove(_kToken);
        return AppAuthResult(
          ok: false,
          pending: true,
          message: accessPending
              ? 'Solicitud de SaludAMG pendiente en el panel. '
                  'Cuando la activen podrás entrar.'
              : (msg.isNotEmpty
                  ? msg
                  : 'Cuenta pendiente de aprobación.'),
          code: accessPending ? 'app_access_pending' : (code ?? 'pending'),
        );
      }

      if (response.statusCode == 403 && canRequest) {
        final p = await _prefs;
        await p.setString(_kUsername, username.trim());
        await p.setString(_kStatus, 'no_app_access');
        await p.remove(_kToken);
        return AppAuthResult(
          ok: false,
          needsAppAccess: true,
          message:
              'Tu usuario AMG es correcto. Falta activar SaludAMG: '
              'envía la solicitud al panel para que un administrador la active.',
          code: code ?? 'no_app_access',
        );
      }

      if (response.statusCode == 403 && code == 'inactive') {
        final p = await _prefs;
        await p.setString(_kUsername, username.trim());
        await p.setString(_kStatus, 'inactive');
        await p.remove(_kToken);
        return AppAuthResult(
          ok: false,
          pending: true,
          message: msg.isNotEmpty ? msg : 'Tu cuenta no está activa.',
          code: 'inactive',
        );
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['token'] != null) {
        final token = data['token'].toString();
        final p = await _prefs;
        await p.setString(_kToken, token);
        await p.setBool(_kActivated, true);
        await p.setString(_kUsername, username.trim());
        await p.setString(_kStatus, status ?? 'active');
        await _syncLocalLegalAcceptance();
        await _acceptLegalOnServer(token);
        return AppAuthResult(
          ok: true,
          message: data['message']?.toString() ?? 'Login correcto.',
        );
      }

      // 428 solo debería ocurrir con *_current_version (app antigua).
      if (response.statusCode == 428) {
        await _syncLocalLegalAcceptance();
        if (sendAcceptance) {
          // Reintento sin campos legales conflictivos: solo accepted.
          final retry = await _post('/app-auth/login', {
            'username': username.trim(),
            'password': password,
            'app_id': appId,
            'device_id': id,
            'platform': _platformKey,
            'app_version': package.version,
            'build_number': package.buildNumber,
            'privacy_accepted_version': privacyPolicyVersion,
            'terms_accepted_version': termsVersion,
          });
          final retryData = _decode(retry.body);
          debugPrint(
            '[AppAuth] login retry tras 428 ← HTTP ${retry.statusCode} '
            'msg=${retryData['message']}',
          );
          if (retry.statusCode >= 200 &&
              retry.statusCode < 300 &&
              retryData['token'] != null) {
            final token = retryData['token'].toString();
            final p = await _prefs;
            await p.setString(_kToken, token);
            await p.setBool(_kActivated, true);
            await p.setString(_kUsername, username.trim());
            final st = retryData['account'] is Map
                ? (retryData['account'] as Map)['status']?.toString()
                : 'active';
            await p.setString(_kStatus, st ?? 'active');
            await _acceptLegalOnServer(token);
            return AppAuthResult(
              ok: true,
              message: retryData['message']?.toString() ?? 'Login correcto.',
            );
          }
          final retryCode = retryData['code']?.toString();
          final retryMsg = retryData['message']?.toString() ?? '';
          if (retry.statusCode == 403 &&
              (retryCode == 'no_app_access' ||
                  _asTruthy(retryData['can_request_access']) ||
                  _messageLooksLikeNoAppAccess(retryMsg))) {
            return AppAuthResult(
              ok: false,
              needsAppAccess: true,
              message:
                  'Tu usuario AMG es correcto. Falta activar SaludAMG: '
                  'envía la solicitud al panel para que un administrador '
                  'la active.',
              code: retryCode ?? 'no_app_access',
            );
          }
          if (retry.statusCode == 403 &&
              (retryCode == 'pending' ||
                  retryCode == 'app_access_pending')) {
            return AppAuthResult(
              ok: false,
              pending: true,
              message: retryData['message']?.toString() ??
                  'Pendiente de activación en el panel.',
              code: retryCode,
            );
          }
        }
        return AppAuthResult(
          ok: false,
          needsLegal: !sendAcceptance,
          message: sendAcceptance
              ? (data['message']?.toString() ??
                  'No se pudo completar el acceso. Prueba «Solicitar '
                      'activación» o contacta con soporte.')
              : (data['message']?.toString() ??
                  'Debes aceptar la política de privacidad y las condiciones.'),
          code: code ?? 'legal_required',
        );
      }

      return AppAuthResult(
        ok: false,
        message: data['message']?.toString() ??
            'Error ${response.statusCode}',
        code: code,
      );
    } catch (e) {
      return AppAuthResult(ok: false, message: e.toString());
    }
  }

  /// Cuenta AMG existente sin acceso a SaludAMG → avisa al panel.
  Future<AppAuthResult> requestAccess({
    required String username,
    required String password,
    required bool acceptedLegal,
  }) async {
    if (!acceptedLegal) {
      return const AppAuthResult(
        ok: false,
        message: 'Debes aceptar privacidad y condiciones.',
      );
    }
    if (!isConfigured) {
      return const AppAuthResult(ok: false, message: 'API no configurada.');
    }
    try {
      final package = await PackageInfo.fromPlatform();
      final id = await deviceId();
      final response = await _post('/app-auth/request-access', {
        'username': username.trim(),
        'password': password,
        'app_id': appId,
        'device_id': id,
        'platform': _platformKey,
        'app_version': package.version,
        'build_number': package.buildNumber,
        'privacy_accepted_version': privacyPolicyVersion,
        'terms_accepted_version': termsVersion,
      });
      final data = _decode(response.body);
      final code = data['code']?.toString();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final p = await _prefs;
        await p.setString(_kUsername, username.trim());
        await p.setString(_kStatus, 'app_access_pending');
        await p.setBool(_kActivated, true);
        await p.remove(_kToken);
        await _syncLocalLegalAcceptance();
        return AppAuthResult(
          ok: true,
          pending: true,
          message: data['message']?.toString() ??
              'Solicitud enviada al panel. Cuando activen SaludAMG en tu cuenta '
                  'podrás iniciar sesión.',
          code: code ?? 'app_access_pending',
        );
      }
      return AppAuthResult(
        ok: false,
        alreadyHasAccess: code == 'already_has_access',
        message: data['message']?.toString() ??
            'Error ${response.statusCode}',
        code: code,
      );
    } catch (e) {
      return AppAuthResult(ok: false, message: e.toString());
    }
  }

  /// Pide al panel el enlace de recuperación. La respuesta no revela si existe.
  Future<AppAuthResult> requestPasswordReset({required String email}) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      return const AppAuthResult(ok: false, message: 'Escribe tu email.');
    }
    if (!isConfigured) {
      return const AppAuthResult(ok: false, message: 'API no configurada.');
    }
    try {
      final response = await _post('/app-auth/request-password-reset', {
        'email': cleanEmail,
      });
      final data = _decode(response.body);
      return AppAuthResult(
        ok: response.statusCode >= 200 && response.statusCode < 300,
        message: data['message']?.toString() ?? 'Error ${response.statusCode}',
      );
    } catch (e) {
      return AppAuthResult(ok: false, message: e.toString());
    }
  }

  /// Borra la sesión local al instante (antes de cambiar de pantalla).
  Future<void> clearLocalSession() async {
    final p = await _prefs;
    await p.remove(_kToken);
    await p.remove(_kStatus);
  }

  Future<void> logout() async {
    final t = await token();
    // Primero limpia local: si la UI va al AuthGate con token aún guardado,
    // reabriría el inicio. La red no debe bloquear el cambio de pantalla.
    await clearLocalSession();

    if (t != null && isConfigured) {
      // ignore: unawaited_futures
      _post('/app-auth/logout', {}, bearer: t)
          .timeout(const Duration(seconds: 3))
          .catchError((_) => http.Response('', 500));
    }
  }

  /// «Crear cuenta» solo se ofrece hasta la primera activación en este dispositivo.
  Future<bool> hasActivated() async {
    final p = await _prefs;
    return (p.getBool(_kActivated) ?? false) ||
        (p.getString(_kUsername)?.trim().isNotEmpty ?? false);
  }

  /// Avisa al panel de la versión aceptada (como TiroAMG). No bloquea el login.
  Future<void> _acceptLegalOnServer(String token) async {
    try {
      await _post(
        '/app-auth/accept-legal',
        {
          'privacy_accepted_version': privacyPolicyVersion,
          'terms_accepted_version': termsVersion,
        },
        bearer: token,
      );
    } catch (_) {}
  }

  Future<http.Response> _post(
    String path,
    Map<String, dynamic> body, {
    String? bearer,
  }) async {
    // En Android + *.desarrollo usa el puente 10.0.2.2 (el emulador no resuelve hosts de Windows).
    return LicenseApiHttp.postJson(
      baseUrl: apiBaseUrl,
      path: path,
      body: jsonEncode(body),
      headers: {
        if (bearer != null) 'Authorization': 'Bearer $bearer',
      },
      timeout: const Duration(seconds: 12),
    );
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('[AppAuth] decode: $e');
    }
    return {};
  }

  static bool _asTruthy(dynamic value) =>
      value == true || value == 1 || value == '1' || value == 'true';

  static bool _messageLooksLikeNoAppAccess(String message) {
    final m = message.toLowerCase();
    return m.contains('no tienes acceso') ||
        m.contains('aún no tienes acceso') ||
        m.contains('aun no tienes acceso') ||
        m.contains('puedes solicitarlo') ||
        m.contains('solicitar acceso') ||
        m.contains('no tienes esta aplicación') ||
        m.contains('no tienes esta aplicacion');
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
    return 'unknown';
  }
}

class AppAuthResult {
  const AppAuthResult({
    required this.ok,
    this.skipped = false,
    this.pending = false,
    this.needsLegal = false,
    this.needsAppAccess = false,
    this.alreadyHasAccess = false,
    this.message,
    this.code,
  });

  final bool ok;
  final bool skipped;
  final bool pending;
  final bool needsLegal;
  /// Cuenta válida pero sin permiso para esta app.
  final bool needsAppAccess;
  final bool alreadyHasAccess;
  final String? message;
  final String? code;
}
