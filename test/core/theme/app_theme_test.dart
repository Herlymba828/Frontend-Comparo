import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/app_tokens.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final entry in {
    'light': AppPalette.light,
    'dark': AppPalette.dark,
  }.entries) {
    final p = entry.value;
    group('${entry.key} palette', () {
      test('text pairs reach 4.5:1', () {
        expect(_contrast(p.ink, p.bg), greaterThanOrEqualTo(4.5));
        expect(_contrast(p.ink, p.surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(p.muted, p.bg), greaterThanOrEqualTo(4.5));
        expect(_contrast(p.muted, p.surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(p.actionInk, p.action), greaterThanOrEqualTo(4.5));
        expect(_contrast(p.accentInk, p.accent), greaterThanOrEqualTo(4.5));
        expect(_contrast(p.errorInk, p.error), greaterThanOrEqualTo(4.5));
      });

      test('action and error read on the grounds (3:1)', () {
        expect(_contrast(p.action, p.bg), greaterThanOrEqualTo(3));
        expect(_contrast(p.action, p.surface), greaterThanOrEqualTo(3));
        expect(_contrast(p.error, p.surface), greaterThanOrEqualTo(3));
      });
    });
  }

  test('themes map the tokens', () {
    final light = AppTheme.light;
    final dark = AppTheme.dark;
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.primary, AppPalette.light.action);
    expect(dark.colorScheme.primary, AppPalette.dark.action);
    expect(light.scaffoldBackgroundColor, AppPalette.light.bg);
    expect(light.textTheme.bodyMedium?.fontSize, 16);
  });
}
