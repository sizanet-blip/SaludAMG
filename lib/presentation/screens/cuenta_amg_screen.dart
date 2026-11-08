import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../services/app_auth_service.dart';
import '../widgets/app_section_card.dart';
import '../widgets/salud_amg_app_bar.dart';

/// Sesión AMG: usuario, estado y cerrar sesión (como en TiroAMG).
class CuentaAmgScreen extends StatefulWidget {
  const CuentaAmgScreen({super.key});

  @override
  State<CuentaAmgScreen> createState() => _CuentaAmgScreenState();
}

class _CuentaAmgScreenState extends State<CuentaAmgScreen> {
  final _auth = AppAuthService();
  var _username = '—';
  var _status = '—';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await _auth.username();
    final status = await _auth.status();
    if (!mounted) return;
    setState(() {
      _username = (user == null || user.isEmpty) ? '—' : user;
      _status = (status == null || status.isEmpty) ? '—' : status;
    });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Cerrar la sesión de la cuenta AMG en este dispositivo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Como Tiro: borrar sesión local → login; el POST al panel no bloquea.
    await _auth.logout();
    if (!mounted) return;
    SaludAmgApp.signOut(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SaludAmgAppBar(section: 'Cuenta AMG'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          AppSectionCard(
            title: 'Sesión',
            icon: Icons.badge_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row('Usuario', _username),
                const SizedBox(height: 8),
                _row('Estado', _status),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.subtitle, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.title,
            ),
          ),
        ),
      ],
    );
  }
}
