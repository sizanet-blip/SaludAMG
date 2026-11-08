import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../legal/privacy_content.dart';
import '../../legal/terms_content.dart';
import '../../services/app_update_service.dart';
import '../../services/app_auth_service.dart';
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

  var _version = '…';
  var _build = '…';
  var _checking = false;
  var _deviceId = '…';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadDeviceId();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = info.version;
      _build = info.buildNumber;
    });
  }

  /// Mismo identificador que se envía al panel al entrar con la cuenta AMG.
  Future<void> _loadDeviceId() async {
    final id = await AppAuthService().deviceId();
    if (!mounted) return;
    setState(() => _deviceId = id);
  }

  Future<void> _checkUpdates() async {
    setState(() => _checking = true);
    try {
      await handleManualUpdateCheck(context, service: _updateService);
    } finally {
      if (mounted) setState(() => _checking = false);
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
            title: 'Dispositivo',
            icon: Icons.phonelink_setup_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Identificador de este móvil en tu cuenta AMG. Puede '
                  'pedírtelo soporte. Tus mediciones y medicación no salen '
                  'del teléfono.',
                  style: TextStyle(color: AppColors.subtitle, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  'ID: $_deviceId',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
