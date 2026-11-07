import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'salud_amg_app_bar_title.dart';

/// AppBar de marca sin el recorte del `title` de Material AppBar (como TiroAMG).
class SaludAmgAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SaludAmgAppBar({
    super.key,
    this.section,
    this.title,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.toolbarHeight,
    this.logoHeight,
  });

  final String? section;
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  /// Altura del área de título (sin SafeArea ni borde).
  /// Si es null: wordmark + sección (mismo tamaño que en inicio).
  final double? toolbarHeight;

  /// Altura del wordmark; si es null usa [SaludAmgBrand.wordmarkHeight].
  final double? logoHeight;

  static const double _borderHeight = 1;
  static const double _sectionBlock = 22;

  double get _resolvedLogoHeight =>
      logoHeight ?? SaludAmgBrand.wordmarkHeight;

  double get _resolvedToolbarHeight {
    if (toolbarHeight != null) return toolbarHeight!;
    final hasSection = section != null && section!.trim().isNotEmpty;
    // Mismo wordmark que la home; un poco de aire arriba/abajo.
    return _resolvedLogoHeight + (hasSection ? _sectionBlock : 8);
  }

  @override
  Size get preferredSize => Size.fromHeight(
        _resolvedToolbarHeight +
            _borderHeight +
            (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.appBar;
    final fg = foregroundColor ?? AppColors.title;
    final theme = Theme.of(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    Widget? leadingWidget = leading;
    if (leadingWidget == null && automaticallyImplyLeading && canPop) {
      leadingWidget = BackButton(color: fg);
    }

    Widget? trailing;
    if (actions != null && actions!.isNotEmpty) {
      trailing = IconTheme(
        data: IconThemeData(color: fg),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: actions!,
        ),
      );
    }

    return Material(
      color: bg,
      elevation: 0,
      child: IconTheme(
        data: IconThemeData(color: fg),
        child: DefaultTextStyle(
          style: theme.textTheme.titleLarge?.copyWith(color: fg) ??
              TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w600),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: _resolvedToolbarHeight,
                  child: NavigationToolbar(
                    leading: leadingWidget,
                    middle: Padding(
                      padding: EdgeInsets.only(
                        left: leadingWidget == null ? 16 : 0,
                        right: 8,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: title ??
                            SaludAmgAppBarTitle(
                              section: section,
                              logoHeight: _resolvedLogoHeight,
                              sectionFontSize: 13,
                            ),
                      ),
                    ),
                    trailing: trailing,
                    centerMiddle: false,
                    middleSpacing: 8,
                  ),
                ),
                if (bottom != null) bottom!,
                if (bottom == null)
                  const SizedBox(
                    height: _borderHeight,
                    width: double.infinity,
                    child: ColoredBox(color: AppColors.border),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
