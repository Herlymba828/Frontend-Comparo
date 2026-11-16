import 'package:comparo_ui/comparo_ui.dart';
import 'package:flutter/material.dart';

/// Couleurs de l'app : des alias du design system Comparo v2.4 (palette P07
/// « Fraîcheur quotidienne »). Aucune valeur n'est écrite ici : tout vient de
/// [ComparoPalette], donc de `design-system/tokens.json`.
class AppColors {
  static const primary = ComparoPalette.green600;
  static const accent = ComparoPalette.lemon300;
  static const secondary = ComparoPalette.teal500;
  static const background = ComparoPalette.sage25;
  static const surface = ComparoPalette.sage0;
  static const textPrimary = ComparoPalette.forest800;
  static const textSecondary = ComparoPalette.sage700;
  static const border = ComparoPalette.sage100;
  static const error = ComparoPalette.red700;
  static const warning = Color(0xFFA16207);
  static const info = Color(0xFF1769AA);
  static const disabled = ComparoPalette.sage50;

  /// Remplissage neutre (ancien « kraft »).
  static const kraft = ComparoPalette.sage100;

  /// Filet plus marqué (ancien « bord kraft »).
  static const kraftEdge = ComparoPalette.sage500;

  /// Alerte, indisponible, action sensible (ancien « terracotta »).
  static const terracotta = ComparoPalette.red700;
  static const ink = ComparoPalette.forest800;

  const AppColors._();
}

/// Polices embarquées par `comparo_ui` : Flutter les enregistre sous
/// `packages/comparo_ui/…`. Il n'y a plus de police manuscrite : les anciens
/// styles « prix » et « note à la main » passent sur Bricolage Grotesque et
/// Manrope.
class AppFonts {
  static const body = ComparoText.fontSans;
  static const display = ComparoText.fontDisplay;
  static const price = ComparoText.fontDisplay;
  static const hand = ComparoText.fontSans;

  const AppFonts._();
}

class AppSpacing {
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const space48 = 48.0;

  const AppSpacing._();
}

/// Les polices sont variables : le poids se règle par l'axe `wght`. Un style
/// qui le fixe ne suit plus un simple `copyWith(fontWeight: …)` : passer par
/// [AppTextStyles.weighted].
class AppTextStyles {
  static const pricePrimary = TextStyle(
    fontFamily: AppFonts.price,
    color: AppColors.ink,
    fontSize: 28,
    height: 1,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800), FontVariation('opsz', 28)],
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const priceSecondary = TextStyle(
    fontFamily: AppFonts.price,
    color: AppColors.ink,
    fontSize: 19,
    height: 1,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700), FontVariation('opsz', 19)],
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const display = TextStyle(
    fontFamily: AppFonts.display,
    color: AppColors.ink,
    fontSize: 34,
    height: 1.05,
    letterSpacing: -0.6,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800), FontVariation('opsz', 34)],
  );

  /// Remarque courte (libellé de promotion) : plus de manuscrit, du Manrope.
  static const handNote = TextStyle(
    fontFamily: AppFonts.hand,
    color: AppColors.primary,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
  );
  static const stamp = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 11,
    letterSpacing: 0.4,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800)],
  );

  /// [style] au poids [weight] (100 à 800), sur l'axe `wght` de la police.
  static TextStyle weighted(TextStyle style, int weight) => style.copyWith(
    fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
    fontVariations: [
      FontVariation('wght', weight.toDouble()),
      for (final variation in style.fontVariations ?? const <FontVariation>[])
        if (variation.axis != 'wght') variation,
    ],
  );

  const AppTextStyles._();
}

/// Ombre franche, sans flou. Réservée à ce qui flotte : le design à plat
/// n'en met plus sur les cartes.
List<BoxShadow> inkShadow({double offset = 3, Color color = AppColors.ink}) => [
  BoxShadow(color: color, offset: Offset(0, offset)),
];

class AppTheme {
  static ThemeData get light {
    final comparo = ComparoColors.light;
    const controlRadius = BorderRadius.all(
      Radius.circular(ComparoDims.radiusMd),
    );
    const controlShape = RoundedRectangleBorder(borderRadius: controlRadius);
    const minimumSize = Size(ComparoDims.targetMin, ComparoDims.targetPrimary);
    OutlineInputBorder inputBorder(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: color, width: width),
        );

    return ComparoTheme.light().copyWith(
      disabledColor: AppColors.disabled,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: comparo.canvas,
        foregroundColor: comparo.ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: ComparoText.title.copyWith(color: comparo.ink),
      ),
      textTheme: TextTheme(
        headlineLarge: ComparoText.display.copyWith(color: comparo.ink),
        headlineMedium: ComparoText.title.copyWith(color: comparo.ink),
        headlineSmall: ComparoText.title.copyWith(
          fontSize: 18,
          color: comparo.ink,
        ),
        titleLarge: ComparoText.title.copyWith(color: comparo.ink),
        titleMedium: ComparoText.subtitle.copyWith(color: comparo.ink),
        titleSmall: ComparoText.subtitle.copyWith(
          fontSize: 14,
          color: comparo.ink,
        ),
        bodyLarge: ComparoText.body.copyWith(color: comparo.ink),
        bodyMedium: ComparoText.body.copyWith(
          fontSize: 14,
          color: comparo.inkMuted,
        ),
        bodySmall: ComparoText.caption.copyWith(color: comparo.inkMuted),
        labelLarge: ComparoText.subtitle.copyWith(
          fontSize: 14,
          color: comparo.ink,
        ),
        labelMedium: ComparoText.label.copyWith(color: comparo.inkMuted),
        labelSmall: ComparoText.label.copyWith(color: comparo.inkMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: comparo.primary,
          foregroundColor: comparo.onPrimary,
          disabledBackgroundColor: comparo.fill100,
          disabledForegroundColor: comparo.inkMuted,
          minimumSize: minimumSize,
          shape: controlShape,
          textStyle: ComparoText.subtitle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: comparo.paper,
          foregroundColor: comparo.ink,
          minimumSize: minimumSize,
          side: BorderSide(color: comparo.line),
          shape: controlShape,
          textStyle: ComparoText.subtitle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: comparo.tealInk,
          minimumSize: minimumSize,
          textStyle: ComparoText.subtitle.copyWith(fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: inputBorder(comparo.line, 1),
        enabledBorder: inputBorder(comparo.line, 1),
        focusedBorder: inputBorder(comparo.primary, 2),
        errorBorder: inputBorder(comparo.danger, 1),
        focusedErrorBorder: inputBorder(comparo.danger, 2),
        filled: true,
        fillColor: comparo.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space12,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: comparo.paper,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.only(bottom: AppSpacing.space12),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: comparo.lineSoft),
          borderRadius: BorderRadius.circular(ComparoDims.radiusCard),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: comparo.paper,
        selectedColor: comparo.slate,
        checkmarkColor: comparo.accent,
        side: BorderSide(color: comparo.line),
        shape: const StadiumBorder(),
        labelStyle: ComparoText.label.copyWith(
          fontSize: 13,
          // A selected chip is slate-filled: its label must turn light.
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? comparo.paper
                : comparo.ink,
          ),
        ),
        secondaryLabelStyle: ComparoText.label.copyWith(
          fontSize: 13,
          color: comparo.accent,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: comparo.slate,
        contentTextStyle: ComparoText.body.copyWith(
          fontSize: 14,
          color: comparo.paper,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: comparo.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: comparo.lineSoft),
          borderRadius: BorderRadius.circular(ComparoDims.radiusLg),
        ),
      ),
      // Wide screens: the same destinations as the bottom bar, on the side.
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: comparo.paper,
        indicatorColor: comparo.accent,
        selectedIconTheme: IconThemeData(color: comparo.ink),
        unselectedIconTheme: IconThemeData(color: comparo.inkMuted),
        selectedLabelTextStyle: ComparoText.label.copyWith(color: comparo.ink),
        unselectedLabelTextStyle: ComparoText.label.copyWith(
          color: comparo.inkMuted,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: comparo.paper,
        surfaceTintColor: Colors.transparent,
        indicatorColor: comparo.accent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => ComparoText.label.copyWith(
            color: states.contains(WidgetState.selected)
                ? comparo.primary
                : comparo.inkMuted,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: comparo.lineSoft),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: comparo.primary,
      ),
    );
  }
}
