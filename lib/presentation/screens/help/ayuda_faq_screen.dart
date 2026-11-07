import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../help/help_content.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/salud_amg_app_bar.dart';

class AyudaFaqScreen extends StatelessWidget {
  const AyudaFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SaludAmgAppBar(section: 'Preguntas y respuestas'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'Dudas frecuentes sobre SaludAMG, con respuestas claras.',
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: AppColors.subtitle,
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'FAQ',
            icon: Icons.help_outline,
            child: Column(
              children: [
                for (var i = 0; i < HelpContent.faq.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.divider),
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      iconColor: AppColors.primary,
                      collapsedIconColor: AppColors.subtitle,
                      title: Text(
                        HelpContent.faq[i].question,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.title,
                        ),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            HelpContent.faq[i].answer,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: AppColors.subtitle,
                            ),
                          ),
                        ),
                      ],
                    ),
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
