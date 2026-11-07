import 'package:flutter/material.dart';

import '../../services/app_update_service.dart';

Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppUpdateService service,
  required AppUpdateInfo info,
  required bool force,
  String? currentVersion,
  int? currentBuild,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !force,
    builder: (ctx) {
      return PopScope(
        canPop: !force,
        child: AlertDialog(
          title: Text(
            force
                ? 'Actualización obligatoria'
                : 'Nueva actualización disponible',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentVersion != null)
                  Text(
                    'Versión actual: $currentVersion'
                    '${currentBuild != null ? '+$currentBuild' : ''}',
                  ),
                Text(
                  'Versión nueva: ${info.latestVersion}+${info.latestBuild}',
                ),
                if (info.changelog.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Cambios:'),
                  const SizedBox(height: 6),
                  ...info.changelog.take(6).map((line) => Text('• $line')),
                ],
              ],
            ),
          ),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Más tarde'),
              ),
            FilledButton(
              onPressed: () async {
                final opened = await service.openDownloadUrl(info);
                if (!ctx.mounted) return;
                if (!opened) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo abrir la descarga.'),
                    ),
                  );
                  return;
                }
                if (!force) Navigator.of(ctx).pop();
              },
              child: const Text('Actualizar'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> handleManualUpdateCheck(
  BuildContext context, {
  AppUpdateService service = const AppUpdateService(),
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    const SnackBar(content: Text('Buscando actualizaciones…')),
  );

  final result = await service.checkForUpdates();
  if (!context.mounted) return;
  messenger.hideCurrentSnackBar();

  if (result.openPlayStore) {
    final opened = await service.openPlayStore();
    if (!context.mounted) return;
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Play.')),
      );
    }
    return;
  }

  if (result.hasUpdate && result.info != null) {
    await showAppUpdateDialog(
      context,
      service: service,
      info: result.info!,
      force: result.forceUpdate,
      currentVersion: result.currentVersion,
      currentBuild: result.currentBuild,
    );
    return;
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        result.message?.trim().isNotEmpty == true
            ? result.message!
            : 'Ya tienes la última versión'
                '${result.currentVersion != null ? ' (${result.currentVersion}+${result.currentBuild})' : ''}.',
      ),
    ),
  );
}
