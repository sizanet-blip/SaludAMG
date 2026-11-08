import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../services/app_auth_service.dart';
import '../../services/app_update_service.dart';
import '../../services/debug_seed_service.dart';
import '../widgets/app_nav.dart';
import '../widgets/app_update_dialogs.dart';
import '../widgets/salud_amg_app_bar.dart';
import '../widgets/salud_amg_app_bar_title.dart';
import 'about_app_screen.dart';
import 'backup_screen.dart';
import 'cuenta_amg_screen.dart';
import 'help/ayuda_screen.dart';
import 'history_screen.dart';
import 'import_settings_screen.dart';
import 'lock_settings_screen.dart';
import 'medication_preferences_screen.dart';
import 'measurement_form_screen.dart';
import 'medications_screen.dart';
import 'profile_form_screen.dart';
import 'reminders_screen.dart';
import 'resumen_screen.dart';

/// Inicio estilo TiroAMG: lo principal aquí; el resto en Configuración.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Se activa al iniciar sesión: el Inicio ofrece abrir la app con huella.
  static var offerBiometricsAfterLogin = false;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static var _updateChecked = false;
  final _updateService = const AppUpdateService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _offerBiometrics();
      await _checkUpdatesOnStart();
    });
  }

  static const _kBioDeclined = 'biometric_offer_declined';

  /// Tras iniciar sesión, una sola vez: «¿Abrir SaludAMG con tu huella?».
  /// Si dice «Ahora no» no se vuelve a preguntar (queda en Configuración).
  Future<void> _offerBiometrics() async {
    if (!HomeScreen.offerBiometricsAfterLogin) return;
    HomeScreen.offerBiometricsAfterLogin = false;
    final lockService = AppScope.of(context).appLock;
    if (lockService.current().useBiometrics) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kBioDeclined) ?? false) return;
    if (!await lockService.canCheckBiometrics() || !mounted) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.fingerprint, size: 40),
        title: const Text('¿Abrir SaludAMG con tu huella?'),
        content: const Text(
          'Así nadie más puede ver tus datos de salud en este teléfono. '
          'Si la huella falla, entras con la contraseña de tu cuenta AMG. '
          'Puedes cambiarlo en Configuración → Bloqueo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    if (accept != true) {
      await prefs.setBool(_kBioDeclined, true);
      return;
    }
    if (!await lockService.authenticateBiometrics()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se ha podido comprobar la huella. Puedes '
                'activarla en Configuración → Bloqueo.'),
          ),
        );
      }
      return;
    }
    await lockService.save(lockService.current().copyWith(useBiometrics: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Huella activada.')),
    );
  }

  /// Una vez por arranque (antes solo se miraba al abrir Resumen).
  Future<void> _checkUpdatesOnStart() async {
    if (_updateChecked || !AppUpdateService.usesServerUpdates) return;
    _updateChecked = true;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final result = await _updateService.checkForUpdates();
    if (!mounted || !result.hasUpdate || result.info == null) return;
    await showAppUpdateDialog(
      context,
      service: _updateService,
      info: result.info!,
      force: result.forceUpdate,
      currentVersion: result.currentVersion,
      currentBuild: result.currentBuild,
    );
  }

  /// Al volver se repinta: p. ej. si se quitó el botón «Medicación».
  Future<void> _push(BuildContext context, Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openMeasurement(BuildContext context) {
    return _push(context, const MeasurementFormScreen());
  }

  Future<void> _openMedications(BuildContext context) {
    return _push(context, const MedicationsScreen());
  }

  Future<void> _confirmSignOut(BuildContext context) async {
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
    if (ok == true && context.mounted) {
      await AppAuthService().logout();
      if (context.mounted) SaludAmgApp.signOut(context);
    }
  }

  Future<void> _seed(BuildContext context) async {
    final seed = DebugSeedService(AppScope.of(context).measurements);
    final n = await seed.seedRandomDays();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Añadidas $n mediciones de prueba.')),
    );
  }

  Future<void> _clearSeed(BuildContext context) async {
    final seed = DebugSeedService(AppScope.of(context).measurements);
    final removed = await seed.clearSeeded();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Eliminadas $removed mediciones de prueba.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showMedicationCta = AppScope.of(context)
        .medicationPreferences
        .current()
        .showHomeButton;

    // Solo el uso diario en inicio (como Tiro: pocas entradas claras).
    final principal = <_HomeMenuItem>[
      _HomeMenuItem(
        title: 'Resumen',
        subtitle: 'Última toma, evolución y accesos rápidos',
        icon: Icons.monitor_heart_outlined,
        color: AppColors.accent,
        onTap: () => _push(context, const ResumenScreen()),
      ),
      _HomeMenuItem(
        title: 'Historial',
        subtitle: 'Mediciones e informes',
        icon: Icons.insights_outlined,
        color: Colors.indigo.shade600,
        onTap: () => _push(context, const HistoryScreen()),
      ),
      _HomeMenuItem(
        title: 'Medicaciones',
        subtitle: 'Tratamientos y tomas del día',
        icon: Icons.medication_outlined,
        color: Colors.teal.shade700,
        onTap: () => _push(context, const MedicationsScreen()),
      ),
      _HomeMenuItem(
        title: 'Configuración',
        subtitle: 'Ficha, avisos, datos, copia y cuenta',
        icon: Icons.settings_outlined,
        color: Colors.blueGrey.shade800,
        onTap: () => _push(context, const ConfigHubScreen()),
      ),
      _HomeMenuItem(
        title: 'Ayuda',
        subtitle: 'Guía, manual y preguntas frecuentes',
        icon: Icons.help_outline,
        color: Colors.blueGrey.shade500,
        onTap: () => _push(context, const AyudaScreen()),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                const SaludAmgWordmark(),
                const SizedBox(height: 24),
                _HomePrimaryActions(
                  showMedication: showMedicationCta,
                  onMedication: () => _openMedications(context),
                  onMeasurement: () => _openMeasurement(context),
                ),
                const SizedBox(height: 24),
                AppNavGroup(
                  children: [
                    for (final item in principal)
                      AppNavTile(
                        title: item.title,
                        subtitle: item.subtitle,
                        icon: item.icon,
                        color: item.color,
                        onTap: item.onTap,
                      ),
                  ],
                ),
                if (AppAuthService.isConfigured) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => _confirmSignOut(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
                if (kDebugMode) ...[
                  const SizedBox(height: 20),
                  AppNavGroup(
                    header: 'Debug',
                    children: [
                      AppNavTile(
                        title: 'Datos de prueba',
                        subtitle: 'Generar mediciones demo',
                        icon: Icons.science_outlined,
                        color: Colors.purple.shade400,
                        onTap: () => _seed(context),
                      ),
                      AppNavTile(
                        title: 'Borrar datos de prueba',
                        subtitle: 'Limpiar seed local',
                        icon: Icons.delete_sweep_outlined,
                        color: AppColors.danger,
                        onTap: () => _clearSeed(context),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePrimaryActions extends StatelessWidget {
  const _HomePrimaryActions({
    required this.showMedication,
    required this.onMedication,
    required this.onMeasurement,
  });

  final bool showMedication;
  final VoidCallback onMedication;
  final VoidCallback onMeasurement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showMedication) ...[
          Expanded(
            child: _HomeActionChip(
              label: 'Medicación',
              icon: Icons.medication_outlined,
              background: AppColors.accent,
              onPressed: onMedication,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: _HomeActionChip(
            label: 'Medición',
            icon: Icons.add,
            background: AppColors.primary,
            onPressed: onMeasurement,
          ),
        ),
      ],
    );
  }
}

class _HomeActionChip extends StatelessWidget {
  const _HomeActionChip({
    required this.label,
    required this.icon,
    required this.background,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black26,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
    );
  }
}

class _HomeMenuItem {
  const _HomeMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// Todo lo secundario: ficha, preferencias, copia, cuenta, acerca de.
class ConfigHubScreen extends StatelessWidget {
  const ConfigHubScreen({super.key});

  Future<void> _push(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SaludAmgAppBar(section: 'Configuración'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          AppNavGroup(
            header: 'Perfil y avisos',
            children: [
              AppNavTile(
                title: 'Ficha',
                subtitle: 'Datos personales y referencias',
                icon: Icons.badge_outlined,
                color: Colors.blueGrey.shade700,
                onTap: () => _push(context, const ProfileFormScreen()),
              ),
              AppNavTile(
                title: 'Recordatorios',
                subtitle: 'Avisos de medicación y mediciones',
                icon: Icons.notifications_outlined,
                color: const Color(0xFFC79100),
                onTap: () => _push(context, const RemindersScreen()),
              ),
              AppNavTile(
                title: 'Datos a medir',
                subtitle: 'Qué métricas registrar',
                icon: Icons.tune_outlined,
                color: AppColors.accent,
                onTap: () => _push(context, const ImportSettingsScreen()),
              ),
              AppNavTile(
                title: 'Opciones de medicación',
                subtitle: 'Preferencias de tomas y botones',
                icon: Icons.medication_liquid_outlined,
                color: Colors.teal.shade700,
                onTap: () =>
                    _push(context, const MedicationPreferencesScreen()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppNavGroup(
            header: 'Seguridad y copia',
            children: [
              AppNavTile(
                title: 'Copia de seguridad',
                subtitle: 'Exportar e importar datos',
                icon: Icons.cloud_sync_outlined,
                color: Colors.blueGrey.shade600,
                onTap: () => _push(context, const BackupScreen()),
              ),
              AppNavTile(
                title: 'Bloqueo',
                subtitle: 'Huella o PIN para abrir la app',
                icon: Icons.lock_outline,
                color: Colors.blueGrey.shade700,
                onTap: () => _push(context, const LockSettingsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppNavGroup(
            header: 'Cuenta y app',
            children: [
              if (AppAuthService.isConfigured)
                AppNavTile(
                  title: 'Cuenta AMG',
                  subtitle: 'Sesión y datos de la cuenta',
                  icon: Icons.manage_accounts_outlined,
                  color: AppColors.primary,
                  onTap: () => _push(context, const CuentaAmgScreen()),
                ),
              AppNavTile(
                title: 'Acerca de',
                subtitle: 'Versión, legal y actualizaciones',
                icon: Icons.info_outline,
                color: Colors.blueGrey.shade400,
                onTap: () => _push(context, const AboutAppScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
