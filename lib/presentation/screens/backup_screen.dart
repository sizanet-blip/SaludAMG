import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/app_section_card.dart';
import '../widgets/salud_amg_app_bar.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  var _busy = false;

  Future<String?> _askExportPassword() {
    return showDialog<String>(
      context: context,
      builder: (context) => const _ExportPasswordDialog(),
    );
  }

  Future<String?> _askRestorePassword() {
    return showDialog<String>(
      context: context,
      builder: (context) => const _RestorePasswordDialog(),
    );
  }

  Future<void> _export() async {
    final password = await _askExportPassword();
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await AppScope.of(context).backup.exportBackup(password: password);
      if (!mounted) return;
      _message(
        password.trim().isEmpty
            ? 'Copia lista (sin cifrar).'
            : 'Copia cifrada lista para guardar o enviar.',
      );
    } catch (error) {
      if (!mounted) return;
      _message('No se ha podido exportar. $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar copia'),
        content: const Text(
          'Se sustituirán ficha, mediciones, medicaciones y preferencias '
          'por el contenido del archivo. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final password = await _askRestorePassword();
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final deps = AppScope.of(context);
      final message = await deps.backup.restoreFromPicker(password: password);
      await deps.notifications.syncSchedule(deps.reminders.current());
      await deps.notifications.syncMedicationSchedule(
        medications: deps.medications.getAll(),
        preferences: deps.medicationPreferences.current(),
      );
      if (!mounted) return;
      if (message != 'Restauración cancelada.') {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context, true);
        messenger.showSnackBar(SnackBar(content: Text(message)));
      } else {
        _message(message);
      }
    } catch (error) {
      if (!mounted) return;
      final detail = error is StateError ? error.message : '$error';
      _message('No se ha podido restaurar. $detail');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SaludAmgAppBar(section: 'Copia de seguridad'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'Puedes exportar en claro o con contraseña (AES). '
            'El PIN de bloqueo de la app no se incluye en la copia.',
            style: TextStyle(color: AppColors.subtitle),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'Respaldo',
            icon: Icons.cloud_upload_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Exportar copia'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _restore,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Restaurar desde archivo'),
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _ExportPasswordDialog extends StatefulWidget {
  const _ExportPasswordDialog();

  @override
  State<_ExportPasswordDialog> createState() => _ExportPasswordDialogState();
}

class _ExportPasswordDialogState extends State<_ExportPasswordDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  var _error = '';

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _exportEncrypted() {
    if (_first.text != _second.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    if (_first.text.trim().length < 4) {
      setState(() => _error = 'Mínimo 4 caracteres.');
      return;
    }
    Navigator.pop(context, _first.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cifrar copia'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Opcional: protege el archivo con contraseña (mín. 4 caracteres).',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _first,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Contraseña'),
            onChanged: (_) {
              if (_error.isNotEmpty) setState(() => _error = '');
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _second,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Repetir contraseña'),
            onChanged: (_) {
              if (_error.isNotEmpty) setState(() => _error = '');
            },
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error, style: const TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Sin cifrar'),
        ),
        FilledButton(
          onPressed: _exportEncrypted,
          child: const Text('Cifrar y exportar'),
        ),
      ],
    );
  }
}

class _RestorePasswordDialog extends StatefulWidget {
  const _RestorePasswordDialog();

  @override
  State<_RestorePasswordDialog> createState() => _RestorePasswordDialogState();
}

class _RestorePasswordDialogState extends State<_RestorePasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contraseña'),
      content: TextField(
        controller: _controller,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Si la copia está cifrada',
          hintText: 'Déjalo vacío si no lo está',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
