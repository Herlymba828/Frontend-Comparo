import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Material themes built from the Socle tokens ([AppPalette], [AppSpace],
/// [AppRadius], [AppSize], [AppMotion]).
class AppTheme {
  static ThemeData get light => _build(AppPalette.light, Brightness.light);

  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    // The derived steps of Socle's components (ink mixed into the ground).
    final card = Color.lerp(p.bg, p.ink, 0.035)!;
    final panel = Color.lerp(p.bg, p.ink, 0.065)!;
    final raise = Color.lerp(p.bg, p.ink, 0.09)!;
    final other = brightness == Brightness.light ? AppPalette.dark : AppPalette.light;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.action,
      onPrimary: p.actionInk,
      primaryContainer: Color.lerp(p.bg, p.accent, 0.18)!,
      onPrimaryContainer: p.ink,
      secondary: p.ink,
      onSecondary: p.bg,
      secondaryContainer: panel,
      onSecondaryContainer: p.ink,
      tertiary: p.accent,
      onTertiary: p.accentInk,
      error: p.error,
      onError: p.errorInk,
      surface: p.bg,
      onSurface: p.ink,
      onSurfaceVariant: p.muted,
      surfaceContainerLowest: p.bg,
      surfaceContainerLow: card,
      surfaceContainer: p.surface,
      surfaceContainerHigh: panel,
      surfaceContainerHighest: raise,
      outline: p.lineStrong,
      outlineVariant: p.line,
      inverseSurface: p.ink,
      onInverseSurface: p.bg,
      inversePrimary: other.action,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      surfaceTint: const Color(0x00000000),
    );

    final text = _textTheme(p);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.btn),
    );
    const buttonSize = Size(64, AppSize.btnH);
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpace.s5);
    final buttonLabel = text.labelLarge;

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      textTheme: text,
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.action,
        selectionColor: p.accent.withValues(alpha: 0.3),
        selectionHandleColor: p.action,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.ink,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleMedium,
        // One hairline under the header from the first paint.
        shape: Border(bottom: BorderSide(color: p.line)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.action,
          foregroundColor: p.actionInk,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonLabel,
          elevation: 0,
          animationDuration: AppMotion.hoverIn,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: p.bg,
          foregroundColor: p.ink,
          side: BorderSide(color: p.lineStrong),
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonLabel,
          animationDuration: AppMotion.hoverIn,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.ink,
          minimumSize: const Size(48, AppSize.btnH),
          shape: buttonShape,
          textStyle: buttonLabel,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: p.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.bg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s3,
          vertical: AppSpace.s3,
        ),
        border: inputBorder(p.lineStrong),
        enabledBorder: inputBorder(p.lineStrong),
        focusedBorder: inputBorder(p.action, 2),
        errorBorder: inputBorder(p.error),
        focusedErrorBorder: inputBorder(p.error, 2),
        labelStyle: text.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        hintStyle: text.bodyMedium?.copyWith(color: p.muted),
        prefixIconColor: p.muted,
        suffixIconColor: p.muted,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        side: BorderSide(color: p.line),
        shape: const StadiumBorder(),
        labelStyle: text.labelSmall,
        iconTheme: IconThemeData(color: p.ink, size: AppSize.icon),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s1),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.muted,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall?.copyWith(color: p.muted),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.action),
      iconTheme: IconThemeData(color: p.ink),
    );
  }

  /// Socle text styles, phone sizes (the app is mobile first). Tracking
  /// -0.025em on titles; nothing under 13 px.
  static TextTheme _textTheme(AppPalette p) {
    TextStyle style(
      double size,
      double height, {
      FontWeight weight = FontWeight.w400,
      double trackingEm = 0,
    }) =>
        TextStyle(
          fontSize: size,
          height: height,
          fontWeight: weight,
          letterSpacing: size * trackingEm,
          color: p.ink,
        );

    return TextTheme(
      // h1, h2, stat
      displayLarge: style(38, 1.04, trackingEm: -0.025),
      displayMedium: style(30, 1.1, trackingEm: -0.025),
      displaySmall: style(28, 1, trackingEm: -0.025),
      // h3 and the card title
      headlineLarge: style(24, 1.2, trackingEm: -0.025),
      headlineMedium: style(24, 1.2, weight: FontWeight.w500, trackingEm: -0.01),
      headlineSmall: style(20, 1.3, weight: FontWeight.w500, trackingEm: -0.01),
      titleLarge: style(20, 1.3, weight: FontWeight.w500, trackingEm: -0.01),
      titleMedium: style(18, 1.3, weight: FontWeight.w500, trackingEm: -0.01),
      titleSmall: style(16, 1.4, weight: FontWeight.w500),
      // lead, body, small
      bodyLarge: style(18, 1.5),
      bodyMedium: style(16, 1.55),
      bodySmall: style(14, 1.5),
      // button label, label
      labelLarge: style(16, 1, weight: FontWeight.w500),
      labelMedium: style(14, 1.4, weight: FontWeight.w500),
      labelSmall: style(13, 1.4, weight: FontWeight.w500, trackingEm: 0.01),
    );
  }
}
