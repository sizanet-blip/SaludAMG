import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../legal/privacy_content.dart';
import '../../legal/terms_content.dart';
import '../../services/app_update_service.dart';
import '../../services/installation_service.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_update_dialogs.dart';
import '../widgets/salud_amg_app_bar.dart';
import 'legal_document_screen.dart';

class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({super.key});

  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  final _updateService = const AppUpdateService();
  final _installation = InstallationService();
  final _emailController = TextEditingController();

  var _version = '…';
  var _build = '…';
  var _checking = false;
  var _identifying = false;
  var _deviceId = '…';
  String? _storedEmail;
  String? _licenseKey;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadInstallation();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = info.version;
      _build = info.buildNumber;
    });
  }

  Future<void> _loadInstallation() async {
    final id = await _installation.deviceId();
    final email = await _installation.storedEmail();
    final key = await _installation.storedLicenseKey();
    if (!mounted) return;
    setState(() {
      _deviceId = id;
      _storedEmail = email;
      _licenseKey = key;
      if (email != null) _emailController.text = email;
    });
  }

  Future<void> _checkUpdates() async {
    setState(() => _checking = true);
    try {
      await handleManualUpdateCheck(context, service: _updateService);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submitIdentify() async {
    setState(() => _identifying = true);
    try {
      final result = await _installation.identify(_emailController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? (result.ok ? 'OK' : 'Error'))),
      );
      if (result.ok) await _loadInstallation();
    } finally {
      if (mounted) setState(() => _identifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SaludAmgAppBar(section: 'Acerca de'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          AppSectionCard(
            title: 'Versión',
            icon: Icons.info_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('SaludAMG $_version+$_build'),
                const SizedBox(height: 8),
                const Text(
                  'Seguimiento personal de tensión, pulso, peso y medicación. '
                  'No sustituye el criterio de un profesional sanitario.',
                  style: TextStyle(color: AppColors.subtitle, fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _checking ? null : _checkUpdates,
                  icon: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt),
                  label: Text(
                    _checking ? 'Buscando…' : 'Buscar actualizaciones',
                  ),
                ),
                if (!AppUpdateService.usesServerUpdates) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Sin canal propio configurado: en Android se abrirá Google Play.',
                    style: TextStyle(color: AppColors.subtitle, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'Legal',
            icon: Icons.gavel_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Política de privacidad'),
                  subtitle: Text('Versión ${PrivacyContent.version}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalDocumentScreen(
                          kind: LegalDocumentKind.privacy,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Condiciones de uso'),
                  subtitle: Text('Versión ${TermsContent.version}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalDocumentScreen(
                          kind: LegalDocumentKind.terms,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'Instalación',
            icon: Icons.phonelink_setup_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Registro anónimo en el panel AMG (versión y dispositivo). '
                  'No se envían mediciones ni medicación.',
                  style: TextStyle(color: AppColors.subtitle, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  'ID: $_deviceId',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
                if (_licenseKey != null) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    'Clave: $_licenseKey',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                if (_storedEmail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Email: $_storedEmail',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _deviceId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID copiado')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copiar ID'),
                  ),
                ),
                if (InstallationService.isConfigured) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email de contacto (opcional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _identifying ? null : _submitIdentify,
                    child: Text(
                      _identifying ? 'Enviando…' : 'Asociar email',
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Text(
                    'API no configurada en este build '
                    '(INSTALLATION_API_URL / LICENSE_API_URL).',
                    style: TextStyle(color: AppColors.subtitle, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
