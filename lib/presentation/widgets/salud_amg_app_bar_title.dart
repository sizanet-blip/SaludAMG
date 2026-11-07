import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Marca: mismo wordmark (tamaño y aspecto) en inicio y en el resto.
abstract final class SaludAmgBrand {
  static const String wordmarkAsset = 'assets/branding/saludamg-wordmark.png';
  static const double wordmarkAssetWidth = 933;
  static const double wordmarkAssetHeight = 254;

  /// Altura visual del wordmark en home, auth y AppBar.
  static const double wordmarkHeight = 96;
}

/// Título de AppBar: mismo wordmark que la pantalla de inicio.
/// Se pinta igual que [SaludAmgWordmark] (sin FittedBox) para no deformar la línea.
class SaludAmgAppBarTitle extends StatelessWidget {
  const SaludAmgAppBarTitle({
    super.key,
    this.section,
    this.logoHeight,
    this.sectionFontSize = 13,
  });

  /// Nombre de la pantalla (p. ej. «Historial», «Ayuda»).
  final String? section;

  /// Altura del wordmark. Si es null: [SaludAmgBrand.wordmarkHeight].
  final double? logoHeight;

  final double sectionFontSize;

  static const String assetPath = SaludAmgBrand.wordmarkAsset;
  static const double assetWidth = SaludAmgBrand.wordmarkAssetWidth;
  static const double assetHeight = SaludAmgBrand.wordmarkAssetHeight;

  @override
  Widget build(BuildContext context) {
    final hasSection = section != null && section!.trim().isNotEmpty;
    final h = logoHeight ?? SaludAmgBrand.wordmarkHeight;

    final logo = SaludAmgWordmark(height: h);

    if (!hasSection) return logo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        logo,
        const SizedBox(height: 4),
        Text(
          section!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.appBarSection,
            fontSize: sectionFontSize,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// Wordmark completo: solo escala uniforme (BoxFit.contain), sin estirar.
class SaludAmgWordmark extends StatelessWidget {
  const SaludAmgWordmark({
    super.key,
    this.height = SaludAmgBrand.wordmarkHeight,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      SaludAmgBrand.wordmarkAsset,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Text(
        'SaludAMG',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: height * 0.35,
          fontWeight: FontWeight.w700,
          color: AppColors.title,
        ),
      ),
    );
  }
}
