import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';

void main() {
  test('app theme matches the frontend color and typography tokens', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.secondary, AppColors.secondary);
    expect(theme.colorScheme.tertiary, AppColors.accent);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.surface, AppColors.surface);
    expect(theme.colorScheme.error, AppColors.error);
    expect(theme.disabledColor, AppColors.disabled);
    expect(theme.textTheme.headlineLarge?.fontSize, 30);
    expect(theme.textTheme.headlineMedium?.fontSize, 21);
    expect(theme.textTheme.headlineSmall?.fontSize, 18);
    expect(theme.textTheme.bodyLarge?.fontSize, 16);
    expect(theme.textTheme.bodyMedium?.fontSize, 14);
    expect(theme.textTheme.labelMedium?.fontSize, 12);
    expect(AppTextStyles.pricePrimary.fontSize, 28);
    expect(AppTextStyles.priceSecondary.fontSize, 19);
    expect(AppTextStyles.pricePrimary.fontFamily, AppFonts.price);
    expect(theme.textTheme.headlineLarge?.fontFamily, AppFonts.display);
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
