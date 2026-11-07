import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../legal/privacy_content.dart';
import '../../../legal/terms_content.dart';
import '../../../services/app_auth_service.dart';
import '../../widgets/salud_amg_app_bar_title.dart';
import '../legal_document_screen.dart';

/// Login / registro / recuperación / pendiente de aprobación.
/// Boceto 1: AppBar de marca + SegmentedButton (estilo familia AMG / Tiro).
class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key, required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

enum _AuthTab { login, register, recover, pending }

class _AuthGateScreenState extends State<AuthGateScreen> {
  final _auth = AppAuthService();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();

  var _tab = _AuthTab.login;
  var _busy = false;
  var _acceptLegal = false;

  /// Login 428: hay que marcar privacidad/condiciones (como TiroAMG).
  var _needsLegal = false;

  /// Solo tras login con cuenta válida sin acceso a esta app.
  var _showRequestAccess = false;
  String? _message;
  String? _recoveryCode;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final status = await _auth.status();
    final user = await _auth.username();
    if (!mounted) return;
    if (user != null) _userCtrl.text = user;
    if (status == 'pending' || status == 'app_access_pending') {
      setState(() => _tab = _AuthTab.pending);
    } else if (status == 'no_app_access') {
      setState(() {
        _tab = _AuthTab.login;
        _showRequestAccess = true;
      });
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  void _selectTab(_AuthTab tab) {
    setState(() {
      _tab = tab;
      _message = null;
      if (tab != _AuthTab.login) {
        _showRequestAccess = false;
        _needsLegal = false;
      }
    });
  }

  Future<void> _submitLogin() async {
    if (_needsLegal && !_acceptLegal) {
      setState(() {
        _message =
            'Marca la casilla para aceptar la política de privacidad y las condiciones.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    var r = await _auth.login(
      username: _userCtrl.text,
      password: _passCtrl.text,
      acceptedLegal: _acceptLegal,
    );
    // Cuenta AMG sin SaludAMG: si el legal ya está (casilla o local), envía
    // la solicitud al panel en el mismo paso.
    if (!r.ok && r.needsAppAccess && !r.pending && mounted) {
      final legalOk =
          _acceptLegal || await _auth.hasLocalLegalAcceptance();
      if (legalOk) {
        final req = await _auth.requestAccess(
          username: _userCtrl.text,
          password: _passCtrl.text,
          acceptedLegal: true,
        );
        if (req.ok || req.pending) {
          r = AppAuthResult(
            ok: req.ok,
            pending: true,
            message: req.message ??
                'Solicitud enviada al panel. Cuando activen SaludAMG '
                    'podrás iniciar sesión.',
            code: req.code ?? 'app_access_pending',
          );
        } else if (req.alreadyHasAccess) {
          r = AppAuthResult(
            ok: false,
            alreadyHasAccess: true,
            message: req.message ??
                'Ya tienes acceso. Inicia sesión con tu usuario y contraseña.',
            code: req.code,
          );
        } else {
          // Mantener needsAppAccess para que el botón siga siendo «Enviar solicitud».
          r = AppAuthResult(
            ok: false,
            needsAppAccess: true,
            message: req.message ??
                'No se pudo enviar la solicitud. Revisa usuario/contraseña '
                    'e inténtalo de nuevo.',
            code: req.code ?? 'no_app_access',
          );
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = r.message;
      if (r.needsLegal) {
        _needsLegal = true;
      } else if (r.ok || r.pending) {
        _needsLegal = false;
      }
      // Pendiente (cuenta o acceso a app) tiene prioridad sobre «solicitar».
      if (r.pending) {
        _showRequestAccess = false;
        _tab = _AuthTab.pending;
      } else if (r.needsAppAccess) {
        _showRequestAccess = true;
        _tab = _AuthTab.login;
        _needsLegal = true;
        _message =
            'Tu usuario AMG es correcto. Acepta privacidad y condiciones '
            'y envía la solicitud al panel para activar SaludAMG.';
      } else if (!r.needsLegal) {
        _showRequestAccess = false;
      }
    });
    if (r.ok) widget.onAuthenticated();
  }

  Future<void> _submitRegister() async {
    setState(() {
      _busy = true;
      _message = null;
      _recoveryCode = null;
    });
    final r = await _auth.register(
      username: _userCtrl.text,
      password: _passCtrl.text,
      email: _emailCtrl.text,
      acceptedLegal: _acceptLegal,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = r.message;
      _recoveryCode = r.recoveryCode;
      if (r.ok || r.pending) _tab = _AuthTab.pending;
      if (r.alreadyHasAccess) _tab = _AuthTab.login;
    });
  }

  Future<void> _submitRequestAccess() async {
    final legalOk =
        _acceptLegal || await _auth.hasLocalLegalAcceptance();
    if (!legalOk) {
      setState(() {
        _needsLegal = true;
        _message =
            'Marca la casilla de privacidad y condiciones y pulsa de nuevo '
            '«Enviar solicitud al panel».';
      });
      return;
    }
    if (!_acceptLegal) {
      setState(() => _acceptLegal = true);
    }
    await _auth.markLegalAcceptedLocally();
    setState(() {
      _busy = true;
      _message = null;
    });
    final r = await _auth.requestAccess(
      username: _userCtrl.text,
      password: _passCtrl.text,
      acceptedLegal: true,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = r.message;
      if (r.ok || r.pending) {
        _showRequestAccess = false;
        _tab = _AuthTab.pending;
        _message = r.message ??
            'Solicitud enviada al panel. Cuando activen SaludAMG '
                'podrás iniciar sesión.';
      }
      if (r.alreadyHasAccess) {
        _showRequestAccess = false;
        _tab = _AuthTab.login;
        _message = r.message ??
            'Ya tienes acceso. Inicia sesión con tu usuario y contraseña.';
      }
    });
  }

  Future<void> _submitRecover() async {
    setState(() {
      _busy = true;
      _message = null;
      _recoveryCode = null;
    });
    final r = await _auth.recover(
      username: _userCtrl.text,
      recoveryCode: _codeCtrl.text,
      newPassword: _newPassCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = r.message;
      _recoveryCode = r.recoveryCode;
      if (r.ok) _tab = _AuthTab.login;
    });
  }

  InputDecoration _field({
    required String label,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _authSwitch() {
    if (_tab == _AuthTab.login) {
      return Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '¿No tienes cuenta?',
                style: TextStyle(color: AppColors.subtitle, fontSize: 13.5),
              ),
              TextButton(
                onPressed: _busy ? null : () => _selectTab(_AuthTab.register),
                child: const Text('Crear cuenta'),
              ),
            ],
          ),
          TextButton(
            onPressed: _busy ? null : () => _selectTab(_AuthTab.recover),
            child: const Text('Tengo un código de recuperación'),
          ),
        ],
      );
    }

    return Center(
      child: TextButton(
        onPressed: _busy ? null : () => _selectTab(_AuthTab.login),
        child: const Text('Ya tengo cuenta'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = const [
      SaludAmgWordmark(),
      SizedBox(height: 8),
    ];

    if (!AppAuthService.isConfigured) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              ...header,
              const Text(
                'API de autenticación no configurada '
                '(APP_AUTH_API_URL / LICENSE_API_URL).',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.subtitle, height: 1.45),
              ),
            ],
          ),
        ),
      );
    }

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + bottomInset),
              children: [
                ...header,
                const Text(
                  'Cuenta AMG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.subtitle,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                if (_tab == _AuthTab.pending)
                  _AuthCard(
                    title: 'Pendiente de aprobación',
                    icon: Icons.hourglass_top_outlined,
                    iconColor: AppColors.warn,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ..._pendingBody(),
                        ..._feedback(),
                      ],
                    ),
                  )
                else ...[
                  if (_tab == _AuthTab.login)
                    _AuthCard(
                      title: 'Entrar',
                      icon: Icons.login,
                      iconColor: AppColors.accent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ..._loginBody(),
                          ..._feedback(),
                        ],
                      ),
                    ),
                  if (_tab == _AuthTab.register)
                    _AuthCard(
                      title: 'Crear cuenta',
                      icon: Icons.person_add_outlined,
                      iconColor: AppColors.accent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ..._registerBody(),
                          ..._feedback(),
                        ],
                      ),
                    ),
                  if (_tab == _AuthTab.recover)
                    _AuthCard(
                      title: 'Código de recuperación',
                      icon: Icons.key_outlined,
                      iconColor: AppColors.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ..._recoverBody(),
                          ..._feedback(),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  _authSwitch(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _feedback() => [
        if (_message != null) ...[
          const SizedBox(height: 16),
          _InfoBanner(
            text: _message!,
            tone: _showRequestAccess ? _BannerTone.warn : _BannerTone.neutral,
          ),
        ],
        if (_recoveryCode != null) ...[
          const SizedBox(height: 14),
          _RecoveryCodeCard(code: _recoveryCode!),
        ],
      ];

  List<Widget> _pendingBody() => [
        Text(
          'Solicitud enviada al panel',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.title,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          _message?.trim().isNotEmpty == true
              ? _message!
              : 'Hemos avisado al panel AMG. Cuando un administrador active '
                  'SaludAMG en tu cuenta podrás iniciar sesión con el mismo '
                  'usuario y contraseña.',
          style: const TextStyle(color: AppColors.subtitle, height: 1.4),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy
              ? null
              : () {
                  setState(() {
                    _tab = _AuthTab.login;
                    _showRequestAccess = false;
                    _message = null;
                  });
                },
          child: const Text('Volver a iniciar sesión'),
        ),
      ];

  List<Widget> _loginBody() => [
        TextField(
          controller: _userCtrl,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          decoration: _field(label: 'Usuario'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) {
            if (!_busy) _submitLogin();
          },
          decoration: _field(label: 'Contraseña'),
        ),
        if (_needsLegal) ...[
          const SizedBox(height: 8),
          _LegalAcceptance(
            value: _acceptLegal,
            onChanged: (v) {
              setState(() => _acceptLegal = v);
              if (v) {
                // Persiste ya: el login enviará accepted_version aunque
                // vuelvas del documento legal.
                _auth.markLegalAcceptedLocally();
              }
            },
          ),
        ],
        if (_showRequestAccess) ...[
          const SizedBox(height: 16),
          const Text(
            'Tu cuenta AMG ya existe. SaludAMG todavía no está activada. '
            'Acepta las condiciones y envía la solicitud: el administrador '
            'recibirá el aviso en el panel.',
            style: TextStyle(
              color: AppColors.subtitle,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _busy
                ? null
                : (_showRequestAccess ? _submitRequestAccess : _submitLogin),
            child: Text(
              _busy
                  ? (_showRequestAccess ? 'Enviando solicitud…' : 'Entrando…')
                  : (_showRequestAccess
                      ? 'Enviar solicitud al panel'
                      : 'Iniciar sesión'),
            ),
          ),
        ),
      ];

  List<Widget> _registerBody() => [
        const Text(
          'Crea tu usuario o, si ya tienes cuenta en otra app AMG, '
          'usa la misma contraseña para pedir acceso a SaludAMG.',
          style: TextStyle(
            color: AppColors.subtitle,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _userCtrl,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newUsername],
          decoration: _field(label: 'Usuario'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          decoration: _field(label: 'Contraseña (mín. 6)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: _field(
            label: 'Email (opcional)',
            hint: 'Para avisos y recuperación',
          ),
        ),
        const SizedBox(height: 8),
        _LegalAcceptance(
          value: _acceptLegal,
          onChanged: (v) {
            setState(() => _acceptLegal = v);
            if (v) _auth.markLegalAcceptedLocally();
          },
        ),
        const SizedBox(height: 8),
        Text(
          TermsContent.resumenCorto,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.subtitle,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _busy ? null : _submitRegister,
            child: Text(_busy ? 'Enviando…' : 'Crear y solicitar acceso'),
          ),
        ),
      ];

  List<Widget> _recoverBody() => [
        const Text(
          'Usa el código mostrado al crear la cuenta (o el regenerado en el panel) '
          'para definir una nueva contraseña.',
          style: TextStyle(
            color: AppColors.subtitle,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _userCtrl,
          textInputAction: TextInputAction.next,
          decoration: _field(label: 'Usuario'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _codeCtrl,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.characters,
          decoration: _field(label: 'Código de recuperación'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPassCtrl,
          obscureText: true,
          decoration: _field(label: 'Nueva contraseña'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _busy ? null : _submitRecover,
            child: Text(_busy ? 'Guardando…' : 'Cambiar contraseña'),
          ),
        ),
      ];
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.title,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _LegalAcceptance extends StatelessWidget {
  const _LegalAcceptance({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.accent,
      title: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.title,
            height: 1.35,
          ),
          children: [
            const TextSpan(text: 'Acepto la '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LegalDocumentScreen(
                        kind: LegalDocumentKind.privacy,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'privacidad',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const TextSpan(text: ' y las '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LegalDocumentScreen(
                        kind: LegalDocumentKind.terms,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'condiciones',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            TextSpan(text: ' de SaludAMG (v. ${PrivacyContent.version}).'),
          ],
        ),
      ),
    );
  }
}

enum _BannerTone { neutral, warn }

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, required this.tone});

  final String text;
  final _BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final bg = tone == _BannerTone.warn
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFF3F8FB);
    final border = tone == _BannerTone.warn
        ? const Color(0xFFFFE0B8)
        : AppColors.border;
    final fg = tone == _BannerTone.warn
        ? const Color(0xFF9A5B12)
        : AppColors.subtitle;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          text,
          style: TextStyle(color: fg, fontSize: 13, height: 1.4),
        ),
      ),
    );
  }
}

class _RecoveryCodeCard extends StatelessWidget {
  const _RecoveryCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF6E2A8)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Guarda este código de recuperación',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.title,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Solo se muestra ahora. Sin él puede no haber otra vía de restablecimiento.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.subtitle,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.title,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copiar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
