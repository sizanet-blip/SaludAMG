import 'dart:async';
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
  static const _kLastCheck = 'app_auth_last_account_check';

  /// Cada cuánto se pregunta al panel si la cuenta sigue activa.
  static const accountCheckInterval = Duration(hours: 12);

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
            _serverError(response.statusCode),
        code: code,
      );
    } catch (e) {
      return AppAuthResult(ok: false, message: friendlyError(e));
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

      // 428: falta aceptar privacidad/condiciones. Si ya se enviaron, no tiene
      // sentido repetir la misma petición: se muestra el mensaje del panel.
      if (response.statusCode == 428) {
        await _syncLocalLegalAcceptance();
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
            _serverError(response.statusCode),
        code: code,
      );
    } catch (e) {
      return AppAuthResult(ok: false, message: friendlyError(e));
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
            _serverError(response.statusCode),
        code: code,
      );
    } catch (e) {
      return AppAuthResult(ok: false, message: friendlyError(e));
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
        message: data['message']?.toString() ?? _serverError(response.statusCode),
      );
    } catch (e) {
      return AppAuthResult(ok: false, message: friendlyError(e));
    }
  }

  /// ¿Sigue la cuenta activa y con SaludAMG en el panel?
  ///
  /// No pide contraseña ni bloquea: sin internet, con error del servidor o si
  /// se miró hace menos de [accountCheckInterval], responde `null` (seguir).
  /// Solo devuelve un mensaje cuando el panel dice claramente que la cuenta
  /// está bloqueada, rechazada, pendiente, borrada o sin SaludAMG.
  Future<String?> accountRevokedMessage({bool force = false}) async {
    if (!isConfigured || !await hasSession()) return null;
    final user = (await username())?.trim();
    if (user == null || user.isEmpty) return null;
    final p = await _prefs;
    final last = p.getInt(_kLastCheck);
    if (!force &&
        last != null &&
        DateTime.now().millisecondsSinceEpoch - last <
            accountCheckInterval.inMilliseconds) {
      return null;
    }
    try {
      final base = Uri.parse(apiBaseUrl);
      final uri = base.replace(
        path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/app-auth/status',
        queryParameters: {'username': user, 'app_id': appId},
      );
      final response =
          await LicenseApiHttp.get(uri, timeout: const Duration(seconds: 8));
      final data = _decode(response.body);
      final status = data['status']?.toString();
      final hasAccess = data['has_app_access'];
      final known = response.statusCode == 200 || response.statusCode == 404;
      if (!known || (response.statusCode == 200 && status == null)) {
        return null; // Respuesta rara: mejor no echar a nadie.
      }
      await p.setInt(_kLastCheck, DateTime.now().millisecondsSinceEpoch);
      if (status == 'missing' || response.statusCode == 404) {
        return 'Tu cuenta AMG ya no existe en el panel.';
      }
      if (status == 'blocked') return 'Tu cuenta AMG está bloqueada.';
      if (status == 'rejected') return 'Tu cuenta AMG ha sido rechazada.';
      if (status == 'pending') {
        return 'Tu cuenta AMG está pendiente de aprobación.';
      }
      if (status == 'active' && hasAccess == false) {
        return 'El administrador ha quitado SaludAMG de tu cuenta.';
      }
      return null;
    } catch (e) {
      debugPrint('[AppAuth] comprobación de cuenta sin respuesta: $e');
      return null;
    }
  }

  /// Borra la sesión local al instante (antes de cambiar de pantalla).
  Future<void> clearLocalSession() async {
    final p = await _prefs;
    await p.remove(_kToken);
    await p.remove(_kStatus);
    await p.remove(_kLastCheck);
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

  /// Errores de red en lenguaje claro (nada de «SocketException…»).
  static String friendlyError(Object error) {
    debugPrint('[AppAuth] error: $error');
    if (error is TimeoutException) {
      return 'El servidor tarda demasiado en responder. Inténtalo de nuevo '
          'en un momento.';
    }
    if (error is SocketException ||
        error is HandshakeException ||
        error is http.ClientException) {
      return 'No hay conexión con el servidor. Revisa que tengas internet '
          'e inténtalo de nuevo.';
    }
    return 'No se ha podido completar. Inténtalo de nuevo en un momento.';
  }

  static String _serverError(int statusCode) => statusCode >= 500
      ? 'El servidor no está disponible ahora mismo. Inténtalo más tarde.'
      : 'No se ha podido completar (código $statusCode). Inténtalo de nuevo.';

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
