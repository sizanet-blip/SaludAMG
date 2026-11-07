import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/enums/health_enums.dart';

class ReferenceBadge extends StatelessWidget {
  const ReferenceBadge({super.key, required this.level});

  final ReferenceLevel? level;

  @override
  Widget build(BuildContext context) {
    if (level == null) return const SizedBox.shrink();
    final color = switch (level!) {
      ReferenceLevel.within => AppColors.ok,
      ReferenceLevel.above => AppColors.danger,
      ReferenceLevel.below => AppColors.warn,
    };
    return Text(
      level!.label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
    );
  }
}
