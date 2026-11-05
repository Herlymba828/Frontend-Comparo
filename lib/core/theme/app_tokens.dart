import 'package:flutter/material.dart';

/// Design tokens from the "Socle" design system, adapted to Comparateur Prix.
///
/// The design system (tokens.json) is the source of truth: change a value
/// there first, then mirror it here. Names follow the tokens (`s-4` ->
/// [AppSpace.s4], `r-lg` -> [AppRadius.lg]).
@immutable
class AppPalette {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentInk,
    required this.action,
    required this.actionInk,
    required this.line,
    required this.lineStrong,
    required this.error,
    required this.errorInk,
  });

  /// Page background.
  final Color bg;

  /// Alternate background, cards, image placeholders.
  final Color surface;

  /// The one ink: titles, body text, interface glyphs.
  final Color ink;

  /// Labels, dates and meta only, never a paragraph.
  final Color muted;

  /// The one accent (the project's green), under 3 % of a screen.
  final Color accent;

  /// Text on [accent].
  final Color accentInk;

  /// Primary button, links, focus ring, prices.
  final Color action;

  /// Label on [action].
  final Color actionInk;

  /// Default hairline: card borders, separators (ink at 11 %).
  final Color line;

  /// Strong hairline: secondary button, input borders (ink at 20 %).
  final Color lineStrong;

  /// Error state. OPEN DECISION: Socle defines no error colour; these are the
  /// Material 3 baseline error tones until the design system picks one.
  final Color error;

  /// Text on [error].
  final Color errorInk;

  /// Light theme. `action` is #1A7A50 (5.3:1 with white): the former seed
  /// #1F8A5B only reaches 4.3:1 with white text.
  static const light = AppPalette(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF4F4F4),
    ink: Color(0xFF111111),
    muted: Color(0xFF6B6B6B),
    accent: Color(0xFF1A7A50),
    accentInk: Color(0xFFFFFFFF),
    action: Color(0xFF1A7A50),
    actionInk: Color(0xFFFFFFFF),
    line: Color(0x1C111111),
    lineStrong: Color(0x33111111),
    error: Color(0xFFB3261E),
    errorInk: Color(0xFFFFFFFF),
  );

  /// Dark theme: Socle's inverse ground with a lighter green (8:1 on #111111)
  /// carrying dark text.
  static const dark = AppPalette(
    bg: Color(0xFF111111),
    surface: Color(0xFF1C1C1C),
    ink: Color(0xFFF4F4F4),
    muted: Color(0xFFA3A3A3),
    accent: Color(0xFF3FBF85),
    accentInk: Color(0xFF111111),
    action: Color(0xFF3FBF85),
    actionInk: Color(0xFF111111),
    line: Color(0x1CF4F4F4),
    lineStrong: Color(0x33F4F4F4),
    error: Color(0xFFF2B8B5),
    errorInk: Color(0xFF601410),
  );
}

/// Spacing scale `s-1` to `s-10`: every margin, gap and padding.
abstract final class AppSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;
  static const double s8 = 64;
  static const double s9 = 96;
  static const double s10 = 128;
}

/// Radius set "soft".
abstract final class AppRadius {
  /// Controls: inputs, chips, keys.
  static const double sm = 8;

  /// Panels.
  static const double md = 12;

  /// Cards, frames, plans.
  static const double lg = 20;

  /// Buttons.
  static const double btn = 8;

  /// Pills and badges.
  static const double pill = 999;
}

/// Control sizes.
abstract final class AppSize {
  static const double btnH = 44;
  static const double btnHSm = 36;
  static const double icon = 16;
}

/// Durations and curves. OPEN DECISION (see the design system README): the
/// components use taste-skill's curves; Emil Kowalski's [easeOut] is the
/// stronger alternative.
abstract final class AppMotion {
  static const press = Duration(milliseconds: 90);
  static const hoverIn = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 180);
  static const hoverOut = Duration(milliseconds: 200);
  static const panel = Duration(milliseconds: 200);
  static const slide = Duration(milliseconds: 240);
  static const image = Duration(milliseconds: 600);

  /// Emil Kowalski: entering elements and interface responses.
  static const easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Emil Kowalski: an on-screen element that moves.
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// Emil Kowalski: drawers and sheets.
  static const easeDrawer = Cubic(0.32, 0.72, 0, 1);

  /// taste-skill: system transitions (buttons, links).
  static const ease = Cubic(0.2, 0.7, 0.2, 1);

  /// taste-skill: every step of the hover layer.
  static const mEase = Cubic(0.2, 0.8, 0.2, 1);

  /// taste-skill: travel only (a moving indicator).
  static const mEaseIo = Cubic(0.65, 0, 0.35, 1);
}
