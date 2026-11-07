import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../help/help_content.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/salud_amg_app_bar.dart';
import '../legal_document_screen.dart';
import 'ayuda_documento_screen.dart';
import 'ayuda_faq_screen.dart';

class AyudaScreen extends StatelessWidget {
  const AyudaScreen({super.key});

  Future<void> _abrirEmail(BuildContext context) async {
    final uri = Uri.parse(
      'mailto:${HelpContent.supportEmail}'
      '?subject=${Uri.encodeComponent('Soporte SaludAMG')}',
    );
    final ok = await launchUrl(uri);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir el correo. Escribe a ${HelpContent.supportEmail}',
          ),
        ),
      );
    }
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SaludAmgAppBar(section: 'Ayuda'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'Documentación para usuarios',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.title,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Elige el formato que necesites: un resumen rápido, el manual '
            'completo o las preguntas más habituales.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.subtitle,
            ),
          ),
          const SizedBox(height: 20),
          AppSectionCard(
            title: 'Documentación',
            icon: Icons.menu_book_outlined,
            child: Column(
              children: [
                _HelpTile(
                  icon: Icons.bolt_outlined,
                  title: HelpContent.guiaRapida.title,
                  subtitle: HelpContent.guiaRapida.subtitle,
                  onTap: () => _push(
                    context,
                    AyudaDocumentoScreen(doc: HelpContent.guiaRapida),
                  ),
                ),
                const Divider(height: 1),
                _HelpTile(
                  icon: Icons.menu_book_outlined,
                  title: HelpContent.manualCompleto.title,
                  subtitle: HelpContent.manualCompleto.subtitle,
                  onTap: () => _push(
                    context,
                    AyudaDocumentoScreen(doc: HelpContent.manualCompleto),
                  ),
                ),
                const Divider(height: 1),
                _HelpTile(
                  icon: Icons.help_outline,
                  title: 'Preguntas y respuestas',
                  subtitle: 'Dudas frecuentes, con respuestas claras',
                  onTap: () => _push(context, const AyudaFaqScreen()),
                ),
                const Divider(height: 1),
                _HelpTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Política de privacidad',
                  subtitle: 'Datos personales y derechos (RGPD)',
                  onTap: () => _push(
                    context,
                    const LegalDocumentScreen(kind: LegalDocumentKind.privacy),
                  ),
                ),
                const Divider(height: 1),
                _HelpTile(
                  icon: Icons.gavel_outlined,
                  title: 'Condiciones de uso',
                  subtitle: 'Sin garantía; uso bajo tu responsabilidad',
                  onTap: () => _push(
                    context,
                    const LegalDocumentScreen(kind: LegalDocumentKind.terms),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: '¿Necesitas ayuda personalizada?',
            icon: Icons.email_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Si no encuentras la respuesta en la documentación, '
                  'escríbenos y te atendemos.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: AppColors.subtitle,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _abrirEmail(context),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text(HelpContent.supportEmail),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.accent),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.title,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: AppColors.subtitle),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
