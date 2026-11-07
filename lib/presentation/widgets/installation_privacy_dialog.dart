import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/installation_service.dart';

/// Aviso de registro anónimo + email opcional (una vez por instalación).
Future<void> showInstallationPrivacyFlow(
  BuildContext context, {
  required InstallationService service,
}) async {
  if (!InstallationService.isConfigured) return;
  if (await service.hasAcceptedPrivacy()) {
    await service.sync();
    return;
  }
  if (!context.mounted) return;

  final emailController = TextEditingController();
  var accepted = false;

  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Registro de instalación'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SaludAMG puede registrar de forma anónima un identificador '
                  'de este dispositivo en el panel del desarrollador, junto con '
                  'la versión de la app. Sirve para soporte y actualizaciones; '
                  'no incluye tus mediciones ni medicación.',
                  style: TextStyle(fontSize: 14, height: 1.35),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Opcional: deja un email para que podamos contactarte si hace falta.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.subtitle,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email (opcional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                accepted = true;
                Navigator.of(ctx).pop();
              },
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );

    if (!accepted) return;

    final email = emailController.text.trim();
    await service.acceptPrivacy();
    if (email.isNotEmpty && email.contains('@')) {
      await service.identify(email);
    } else {
      await service.sync();
    }
  } finally {
    emailController.dispose();
  }
}
