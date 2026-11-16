import 'package:comparo_ui/comparo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';

void main() {
  test('app theme matches the frontend color and typography tokens', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, AppColors.primary);
    // The design system's scheme: lemon is the secondary colour, teal the tertiary.
    expect(theme.colorScheme.secondary, AppColors.accent);
    expect(theme.colorScheme.tertiary, AppColors.secondary);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.surface, AppColors.surface);
    expect(theme.colorScheme.error, AppColors.error);
    expect(theme.disabledColor, AppColors.disabled);
    expect(theme.textTheme.headlineLarge?.fontSize, 30);
    expect(theme.textTheme.headlineMedium?.fontSize, 20);
    expect(theme.textTheme.headlineSmall?.fontSize, 18);
    expect(theme.textTheme.bodyLarge?.fontSize, 15);
    expect(theme.textTheme.bodyMedium?.fontSize, 14);
    expect(theme.textTheme.labelMedium?.fontSize, 12);
    expect(AppTextStyles.pricePrimary.fontSize, 28);
    expect(AppTextStyles.priceSecondary.fontSize, 19);
    expect(AppTextStyles.pricePrimary.fontFamily, AppFonts.price);
    expect(theme.textTheme.headlineLarge?.fontFamily, AppFonts.display);
  });

  test('the theme carries the design system colours and its 48 px targets', () {
    final theme = AppTheme.light;

    expect(theme.extension<ComparoColors>(), isNotNull);
    final filled = theme.filledButtonTheme.style!;
    expect(filled.minimumSize!.resolve({}), const Size(48, 48));
    expect(filled.backgroundColor!.resolve({}), AppColors.primary);
  });

  test('fonts are the ones comparo_ui bundles, under their package name', () {
    // Outside the package, a bare "Manrope" would silently fall back to the
    // system font: bundled fonts are registered as packages/comparo_ui/….
    for (final family in [AppFonts.body, AppFonts.display, AppFonts.price]) {
      expect(family, startsWith('packages/comparo_ui/'));
    }
    expect(AppTextStyles.display.fontVariations, isNotEmpty);
  });

  test('weighted() sets the weight on the variable font axis', () {
    final bold = AppTextStyles.weighted(
      const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w400),
      700,
    );

    expect(bold.fontWeight, FontWeight.w700);
    expect(bold.fontVariations!.firstWhere((v) => v.axis == 'wght').value, 700);
  });

  test('app spacing exposes the requested spacing scale', () {
    expect(
      [
        AppSpacing.space4,
        AppSpacing.space8,
        AppSpacing.space12,
        AppSpacing.space16,
        AppSpacing.space24,
        AppSpacing.space32,
        AppSpacing.space48,
      ],
      [4, 8, 12, 16, 24, 32, 48],
    );
  });
}
