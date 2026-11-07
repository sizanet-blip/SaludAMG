import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../help/help_content.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/salud_amg_app_bar.dart';

class AyudaDocumentoScreen extends StatelessWidget {
  const AyudaDocumentoScreen({super.key, required this.doc});

  final HelpDoc doc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SaludAmgAppBar(section: doc.title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            doc.subtitle,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              color: AppColors.subtitle,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < doc.sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            AppSectionCard(
              title: doc.sections[i].title,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final p in doc.sections[i].paragraphs) ...[
                    Text(
                      p,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.title.withValues(alpha: 0.9),
                      ),
                    ),
                    if (doc.sections[i].bullets.isNotEmpty ||
                        p != doc.sections[i].paragraphs.last)
                      const SizedBox(height: 10),
                  ],
                  for (final b in doc.sections[i].bullets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              b,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: AppColors.title.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
