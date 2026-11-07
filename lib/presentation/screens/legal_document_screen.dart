import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../legal/privacy_content.dart';
import '../../legal/terms_content.dart';
import '../widgets/salud_amg_app_bar.dart';

enum LegalDocumentKind { privacy, terms }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.kind});

  final LegalDocumentKind kind;

  @override
  Widget build(BuildContext context) {
    final title = kind == LegalDocumentKind.privacy
        ? PrivacyContent.title
        : TermsContent.title;
    final body = kind == LegalDocumentKind.privacy
        ? PrivacyContent.fullText
        : TermsContent.fullText;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SaludAmgAppBar(section: title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SelectableText(
          body,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.title,
          ),
        ),
      ),
    );
  }
}
