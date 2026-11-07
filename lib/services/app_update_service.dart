import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'license_api_http.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.minSupportedVersion,
    required this.mandatory,
    required this.changelog,
    required this.downloadUrl,
  });

  final String latestVersion;
  final int latestBuild;
  final String minSupportedVersion;
  final bool mandatory;
  final List<String> changelog;
  final String? downloadUrl;
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.hasUpdate,
    required this.forceUpdate,
    this.openPlayStore = false,
    this.info,
    this.message,
    this.currentVersion,
    this.currentBuild,
  });

  final bool hasUpdate;
  final bool forceUpdate;

  /// Sin UPDATE_METADATA_URL en Android: abrir ficha de Google Play.
  final bool openPlayStore;
  final AppUpdateInfo? info;
  final String? message;
  final String? currentVersion;
  final int? currentBuild;
}

/// Comprueba versión remota (JSON) y abre la descarga o Play Store.
class AppUpdateService {
  const AppUpdateService();

  static const String metadataUrl = String.fromEnvironment(
    'UPDATE_METADATA_URL',
    defaultValue: '',
  );

  static const String playStorePackageId = 'com.amg.salud_amg';

  /// Build con `--dart-define=UPDATE_METADATA_URL=https://…/version.json`.
  static bool get usesServerUpdates => metadataUrl.trim().isNotEmpty;

  Future<AppUpdateCheckResult> checkForUpdates() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

    if (!usesServerUpdates) {
      if (!kIsWeb && Platform.isAndroid) {
        return AppUpdateCheckResult(
          hasUpdate: false,
          forceUpdate: false,
          openPlayStore: true,
          currentVersion: currentVersion,
          currentBuild: currentBuild,
        );
      }
      return AppUpdateCheckResult(
        hasUpdate: false,
        forceUpdate: false,
        message: 'Sin canal de actualizaciones configurado.',
        currentVersion: currentVersion,
        currentBuild: currentBuild,
      );
    }

    try {
      final response = await LicenseApiHttp.get(
        Uri.parse(metadataUrl),
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode != 200) {
        return AppUpdateCheckResult(
          hasUpdate: false,
          forceUpdate: false,
          message: 'No se pudo leer metadata remota (${response.statusCode}).',
          currentVersion: currentVersion,
          currentBuild: currentBuild,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = (data['latestVersion'] as String?)?.trim() ?? '';
      final latestBuild = _asInt(data['latestBuild']) ?? 0;
      final minSupportedVersion =
          (data['minSupportedVersion'] as String?)?.trim() ?? '0.0.0';
      final mandatory = data['mandatory'] as bool? ?? false;
      final changelog = (data['changelog'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      final downloadUrl = _extractDownloadUrl(data);

      if (latestVersion.isEmpty) {
        return AppUpdateCheckResult(
          hasUpdate: false,
          forceUpdate: false,
          message: 'Metadata remota inválida: falta latestVersion.',
          currentVersion: currentVersion,
          currentBuild: currentBuild,
        );
      }

      final hasUpdate = latestBuild > currentBuild ||
          _compareSemver(latestVersion, currentVersion) > 0;
      final forceUpdate =
          mandatory || _compareSemver(currentVersion, minSupportedVersion) < 0;

      return AppUpdateCheckResult(
        hasUpdate: hasUpdate,
        forceUpdate: forceUpdate,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        info: AppUpdateInfo(
          latestVersion: latestVersion,
          latestBuild: latestBuild,
          minSupportedVersion: minSupportedVersion,
          mandatory: mandatory,
          changelog: changelog,
          downloadUrl: downloadUrl,
        ),
      );
    } catch (error) {
      return AppUpdateCheckResult(
        hasUpdate: false,
        forceUpdate: false,
        message: 'Error al comprobar actualizaciones: $error',
        currentVersion: currentVersion,
        currentBuild: currentBuild,
      );
    }
  }

  Future<bool> openDownloadUrl(AppUpdateInfo info) async {
    final url = info.downloadUrl;
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> openPlayStore() async {
    final market = Uri.parse('market://details?id=$playStorePackageId');
    try {
      if (await canLaunchUrl(market)) {
        return await launchUrl(market, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    final web = Uri.parse(
      'https://play.google.com/store/apps/details?id=$playStorePackageId',
    );
    return launchUrl(web, mode: LaunchMode.externalApplication);
  }

  String? _extractDownloadUrl(Map<String, dynamic> data) {
    final downloads = data['downloads'];
    if (downloads is! Map<String, dynamic>) return null;

    final byPlatform = downloads[_platformKey];
    if (byPlatform is Map<String, dynamic>) {
      final url = byPlatform['url'] as String?;
      if (url != null && url.trim().isNotEmpty) return url.trim();
    }

    final defaultDownload = downloads['default'];
    if (defaultDownload is Map<String, dynamic>) {
      final url = defaultDownload['url'] as String?;
      if (url != null && url.trim().isNotEmpty) return url.trim();
    }
    return null;
  }

  String get _platformKey {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static int _compareSemver(String a, String b) {
    final partsA = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final maxLen =
        partsA.length > partsB.length ? partsA.length : partsB.length;
    for (var i = 0; i < maxLen; i++) {
      final valueA = i < partsA.length ? partsA[i] : 0;
      final valueB = i < partsB.length ? partsB[i] : 0;
      if (valueA > valueB) return 1;
      if (valueA < valueB) return -1;
    }
    return 0;
  }
}
