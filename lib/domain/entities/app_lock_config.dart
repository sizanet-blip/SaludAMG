/// Bloqueo de la app con PIN y/o biometría.
class AppLockConfig {
  const AppLockConfig({
    required this.enabled,
    required this.pinHash,
    required this.useBiometrics,
  });

  static const storageKey = 'app_lock';

  factory AppLockConfig.defaults() {
    return const AppLockConfig(
      enabled: false,
      pinHash: '',
      useBiometrics: false,
    );
  }

  final bool enabled;
  final String pinHash;
  final bool useBiometrics;

  bool get hasPin => pinHash.isNotEmpty;

  AppLockConfig copyWith({
    bool? enabled,
    String? pinHash,
    bool? useBiometrics,
  }) {
    return AppLockConfig(
      enabled: enabled ?? this.enabled,
      pinHash: pinHash ?? this.pinHash,
      useBiometrics: useBiometrics ?? this.useBiometrics,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'pinHash': pinHash,
        'useBiometrics': useBiometrics,
      };

  factory AppLockConfig.fromJson(Map<String, dynamic> json) {
    return AppLockConfig(
      enabled: json['enabled'] as bool? ?? false,
      pinHash: json['pinHash'] as String? ?? '',
      useBiometrics: json['useBiometrics'] as bool? ?? false,
    );
  }
}
