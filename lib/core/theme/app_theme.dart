import 'package:flutter/material.dart';

/// Palette « Marché & étiquettes » — miroir de la collection Figma « Colors ».
class AppColors {
  static const primary = Color(0xFF24834B);
  static const accent = Color(0xFFD7E96B);
  static const secondary = Color(0xFF29A6A1);
  static const background = Color(0xFFF6F0E3);
  static const surface = Color(0xFFFFFDF7);
  static const textPrimary = Color(0xFF14281D);
  static const textSecondary = Color(0xFF5D6359);
  static const border = Color(0xFFDCCFB4);
  static const error = Color(0xFFB42318);
  static const warning = Color(0xFFA16207);
  static const info = Color(0xFF1769AA);
  static const disabled = Color(0xFFECE4D2);

  static const kraft = Color(0xFFEAD7B0);
  static const kraftEdge = Color(0xFFB98E52);
  static const terracotta = Color(0xFFC4512C);
  static const ink = Color(0xFF14281D);

  const AppColors._();
}

class AppFonts {
  static const body = 'Inter';
  static const display = 'BricolageGrotesque';
  static const price = 'BigShouldersDisplay';
  static const hand = 'Caveat';

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

class AppTextStyles {
  static const pricePrimary = TextStyle(
    fontFamily: AppFonts.price,
    color: AppColors.ink,
    fontSize: 28,
    height: 1,
    fontWeight: FontWeight.w900,
  );
  static const priceSecondary = TextStyle(
    fontFamily: AppFonts.price,
    color: AppColors.ink,
    fontSize: 19,
    height: 1,
    fontWeight: FontWeight.w800,
  );
  static const display = TextStyle(
    fontFamily: AppFonts.display,
    color: AppColors.ink,
    fontSize: 38,
    height: 0.95,
    letterSpacing: -1.1,
    fontWeight: FontWeight.w800,
  );
  static const handNote = TextStyle(
    fontFamily: AppFonts.hand,
    color: AppColors.terracotta,
    fontSize: 20,
    height: 1,
    fontWeight: FontWeight.w700,
  );
  static const stamp = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 11,
    letterSpacing: 0.9,
    fontWeight: FontWeight.w800,
  );

  const AppTextStyles._();
}

/// Ombre « imprimée » : décalage franc, sans flou.
List<BoxShadow> inkShadow({double offset = 3, Color color = AppColors.ink}) => [
  BoxShadow(color: color, offset: Offset(0, offset)),
];

class AppTheme {
  static ThemeData get light {
    const inkSide = BorderSide(color: AppColors.ink, width: 1.5);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.space12),
      side: inkSide,
    );
    const buttonText = TextStyle(
      fontFamily: AppFonts.display,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppFonts.body,
      disabledColor: AppColors.disabled,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.light,
          ).copyWith(
            primary: AppColors.primary,
            onPrimary: AppColors.surface,
            primaryContainer: AppColors.accent,
            onPrimaryContainer: AppColors.ink,
            secondary: AppColors.secondary,
            onSecondary: Colors.white,
            tertiary: AppColors.accent,
            onTertiary: AppColors.ink,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
            surfaceContainerHighest: AppColors.disabled,
            outline: AppColors.border,
            error: AppColors.error,
            onError: Colors.white,
            errorContainer: const Color(0xFFF6D9CE),
            onErrorContainer: AppColors.ink,
          ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.display,
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: AppFonts.display,
          color: AppColors.textPrimary,
          fontSize: 30,
          height: 1.05,
          letterSpacing: -0.6,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: TextStyle(
          fontFamily: AppFonts.display,
          color: AppColors.textPrimary,
          fontSize: 21,
          height: 1.15,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: TextStyle(
          fontFamily: AppFonts.display,
          color: AppColors.textPrimary,
          fontSize: 18,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          fontFamily: AppFonts.display,
          color: AppColors.textPrimary,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          fontFamily: AppFonts.display,
          color: AppColors.textPrimary,
          fontSize: 16,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        labelLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.textSecondary,
          minimumSize: const Size(48, 52),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          minimumSize: const Size(48, 52),
          side: inkSide,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.space12),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.space12),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.space12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space12,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.only(bottom: AppSpacing.space12),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.ink, width: 1.2),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.ink,
        checkmarkColor: AppColors.accent,
        side: const BorderSide(color: AppColors.ink, width: 1.2),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontFamily: AppFonts.body,
          // A selected chip is ink-filled: its label must turn light.
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.surface
                : AppColors.ink,
          ),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: AppFonts.body,
          color: AppColors.accent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(color: AppColors.surface, fontSize: 14),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.ink, width: 1.5),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accent,
        indicatorShape: const StadiumBorder(
          side: BorderSide(color: AppColors.ink, width: 1.2),
        ),
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const TextStyle(
                  fontFamily: AppFonts.display,
                  color: AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                )
              : const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }
}
