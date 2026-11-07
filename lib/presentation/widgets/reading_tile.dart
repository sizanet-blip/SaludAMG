import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/blood_pressure_model.dart';
import '../../domain/entities/user_profile.dart';
import 'reference_badge.dart';

class ReadingTile extends StatelessWidget {
  const ReadingTile({
    super.key,
    required this.reading,
    required this.onOpen,
    required this.onDelete,
    this.profile,
  });

  final BloodPressureModel reading;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final level = profile?.levelFor(reading);
    return Card(
      child: ListTile(
        onTap: onOpen,
        title: Text(
          reading.hasPressure
              ? '${reading.pressureLabel} mmHg · ${reading.context.label}'
              : '${reading.pressureLabel} · ${reading.context.label}',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                formatDateTime(reading.measuredAt),
                if (reading.feeling.trim().isNotEmpty)
                  'Se siente: ${reading.feeling.trim()}',
                reading.extraChips.isEmpty
                    ? 'Sin extras'
                    : reading.extraChips.join(' · '),
                reading.syncInfo.detail,
              ].join('\n'),
            ),
            if (level != null) ...[
              const SizedBox(height: 4),
              ReferenceBadge(level: level),
            ],
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Eliminar',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, color: AppColors.subtitle),
        ),
      ),
    );
  }
}
