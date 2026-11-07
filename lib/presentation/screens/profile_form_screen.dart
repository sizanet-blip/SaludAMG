import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/enums/health_enums.dart';
import '../widgets/app_section_card.dart';
import '../widgets/salud_amg_app_bar.dart';

class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _pulse = TextEditingController();
  final _margin = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();

  DateTime? _birthDate;
  BloodType _bloodType = BloodType.unknown;
  var _ready = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final profile = AppScope.of(context).profiles.current();
    _nickname.text = profile.nickname;
    _height.text = profile.heightCm == null ? '' : formatWeight(profile.heightCm!);
    _weight.text = profile.referenceWeightKg == null ? '' : formatWeight(profile.referenceWeightKg!);
    _systolic.text = '${profile.systolicReference}';
    _diastolic.text = '${profile.diastolicReference}';
    _pulse.text = '${profile.restingPulseReference}';
    _margin.text = '${profile.alertMarginPercent}';
    _contactName.text = profile.emergencyContactName;
    _contactPhone.text = profile.emergencyContactPhone;
    setState(() {
      _birthDate = profile.birthDate;
      _bloodType = profile.bloodType;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    _height.dispose();
    _weight.dispose();
    _systolic.dispose();
    _diastolic.dispose();
    _pulse.dispose();
    _margin.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 40, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final systolic = int.parse(_systolic.text.trim());
    final diastolic = int.parse(_diastolic.text.trim());
    if (diastolic >= systolic) {
      _message('La diastólica de referencia tiene que ser menor que la sistólica.');
      return;
    }
    final profile = UserProfile(
      id: UserProfile.storageKey,
      nickname: _nickname.text.trim(),
      birthDate: _birthDate,
      bloodType: _bloodType,
      heightCm: _optionalDouble(_height.text),
      referenceWeightKg: _optionalDouble(_weight.text),
      systolicReference: systolic,
      diastolicReference: diastolic,
      restingPulseReference: int.parse(_pulse.text.trim()),
      alertMarginPercent: int.parse(_margin.text.trim()),
      emergencyContactName: _contactName.text.trim(),
      emergencyContactPhone: _contactPhone.text.trim(),
      updatedAt: DateTime.now(),
    );
    setState(() => _saving = true);
    await AppScope.of(context).profiles.save(profile);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  double? _optionalDouble(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.parse(text);
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final age = _birthDate == null ? null : ageInYears(_birthDate!, DateTime.now());
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SaludAmgAppBar(section: 'Ficha'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const Text(
              'Estos datos salen al principio de los informes Excel y PDF. '
              'Los umbrales solo sirven para marcar tus lecturas.',
              style: TextStyle(color: AppColors.subtitle),
            ),
            const SizedBox(height: 16),
            AppSectionCard(
              title: 'Datos personales',
              icon: Icons.person_outline,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nickname,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre o apodo',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (value) {
                      if ((value?.trim().length ?? 0) > 60) return 'Máximo 60 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha de nacimiento'),
                    subtitle: Text(
                      _birthDate == null
                          ? 'Sin indicar'
                          : '${formatDate(_birthDate!)}${age == null ? '' : ' · $age años'}',
                    ),
                    trailing: _birthDate == null
                        ? const Icon(Icons.calendar_today_outlined)
                        : IconButton(
                            tooltip: 'Quitar fecha',
                            onPressed: () => setState(() => _birthDate = null),
                            icon: const Icon(Icons.close),
                          ),
                    onTap: _pickBirth,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<BloodType>(
                    initialValue: _bloodType,
                    decoration: const InputDecoration(labelText: 'Grupo sanguíneo'),
                    items: [
                      for (final type in BloodType.values)
                        DropdownMenuItem(value: type, child: Text(type.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _bloodType = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppSectionCard(
              title: 'Antropometría',
              icon: Icons.straighten,
              child: Row(
                children: [
                  Expanded(child: _decimal(_height, 'Altura', 'cm', 50, 250)),
                  const SizedBox(width: 12),
                  Expanded(child: _decimal(_weight, 'Peso de referencia', 'kg', 20, 400)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppSectionCard(
              title: 'Referencias',
              icon: Icons.flag_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _bound(_systolic, 'Sistólica', 'mmHg', 70, 200),
                  const SizedBox(height: 12),
                  _bound(_diastolic, 'Diastólica', 'mmHg', 40, 130),
                  const SizedBox(height: 12),
                  _bound(_pulse, 'Pulso en reposo', 'lpm', 40, 120),
                  const SizedBox(height: 12),
                  _bound(_margin, 'Margen de aviso', '%', 0, 50),
                  const SizedBox(height: 8),
                  const Text(
                    'Solo avisa si tensión o pulso se desvían más de este '
                    'porcentaje respecto a tu referencia. Por defecto 10 %.',
                    style: TextStyle(color: AppColors.subtitle, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppSectionCard(
              title: 'Contacto de emergencia',
              icon: Icons.phone_outlined,
              child: Column(
                children: [
                  TextFormField(
                    controller: _contactName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (value) {
                      if ((value?.length ?? 0) > 80) return 'Máximo 80 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactPhone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+() \-]')),
                    ],
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                    validator: (value) {
                      if ((value?.length ?? 0) > 20) return 'Máximo 20 caracteres';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar ficha'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _decimal(
  TextEditingController controller,
  String label,
  String unit,
  double min,
  double max,
) {
  return TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    decoration: InputDecoration(labelText: label, suffixText: unit),
    validator: (raw) {
      final text = raw?.trim() ?? '';
      if (text.isEmpty) return null;
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value == null) return 'Número';
      if (value < min || value > max) return '${min.toStringAsFixed(0)}–${max.toStringAsFixed(0)}';
      return null;
    },
  );
}

Widget _bound(
  TextEditingController controller,
  String label,
  String unit,
  int min,
  int max,
) {
  return TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: label, suffixText: unit),
    validator: (raw) {
      final value = int.tryParse(raw?.trim() ?? '');
      if (value == null) return 'Obligatorio';
      if (value < min || value > max) return 'Entre $min y $max';
      return null;
    },
  );
}
