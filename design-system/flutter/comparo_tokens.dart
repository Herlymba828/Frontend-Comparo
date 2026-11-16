// Comparo — tokens Flutter générés depuis tokens.json par tools/tokens.py.
// Ne pas modifier à la main : régénérez après toute modification des tokens.
// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

/// Primitives : palette brute. Les widgets n'utilisent que [ComparoColors].
abstract final class ComparoPalette {
  static const Color sage0 = Color(0xFFFFFFFF);
  static const Color sage25 = Color(0xFFFAFBF5);
  static const Color sage40 = Color(0xFFF3F6EE);
  static const Color sage50 = Color(0xFFEFF2E6);
  static const Color sage60 = Color(0xFFEEF3EA);
  static const Color sage100 = Color(0xFFE2E7DA);
  static const Color sage150 = Color(0xFFDDE4D2);
  static const Color sage300 = Color(0xFFB9C8BD);
  static const Color sage350 = Color(0xFFA8B8AD);
  static const Color sage450 = Color(0xFF7F9486);
  static const Color sage500 = Color(0xFF76877B);
  static const Color sage700 = Color(0xFF52645A);
  static const Color sage800 = Color(0xFF2B3C32);
  static const Color sage830 = Color(0xFF26352C);
  static const Color sage850 = Color(0xFF1F2D25);
  static const Color sage900 = Color(0xFF16221B);
  static const Color sage950 = Color(0xFF0F1813);
  static const Color forest800 = Color(0xFF20392D);
  static const Color forest850 = Color(0xFF1D3428);
  static const Color forest950 = Color(0xFF0D2417);
  static const Color green50 = Color(0xFFE3F1E7);
  static const Color green400 = Color(0xFF5CC98B);
  static const Color green600 = Color(0xFF24834B);
  static const Color green900 = Color(0xFF1C3A29);
  static const Color lemon300 = Color(0xFFD7E96B);
  static const Color lemon350 = Color(0xFFCFE262);
  static const Color lemon950 = Color(0xFF1A2A10);
  static const Color teal200 = Color(0xFF7FD9D3);
  static const Color teal400 = Color(0xFF3CC0BA);
  static const Color teal500 = Color(0xFF29A6A1);
  static const Color teal700 = Color(0xFF1B706C);
  static const Color red300 = Color(0xFFFF9B91);
  static const Color red700 = Color(0xFFB3261E);
  static const Color earth700 = Color(0xFF7A4F12);
  static const Color violet700 = Color(0xFF5B3F8C);
  static const Color brick700 = Color(0xFF9B3A26);
}

/// Couleurs sémantiques et de composant, par thème. Accès : `Theme.of(context).extension<ComparoColors>()!`.
@immutable
class ComparoColors extends ThemeExtension<ComparoColors> {
  const ComparoColors({
    required this.canvas,
    required this.paper,
    required this.fill100,
    required this.fill200,
    required this.line,
    required this.lineSoft,
    required this.ink,
    required this.inkMuted,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.accent,
    required this.onAccent,
    required this.slate,
    required this.onSlate,
    required this.slateMuted,
    required this.teal,
    required this.tealInk,
    required this.danger,
    required this.focus,
    required this.note,
    required this.priceBestBg,
    required this.priceBestFg,
    required this.priceTagBg,
    required this.cordeString,
    required this.proofHigh,
    required this.proofMedium,
    required this.proofLow,
    required this.brandMark1,
    required this.brandMark2,
    required this.brandMark3,
    required this.brandMark4,
    required this.brandMark5,
    required this.onBrandMark,
    required this.proofMediumFg,
    required this.saveBg,
    required this.saveFg,
    required this.badgeBetaBg,
    required this.badgeBetaFg,
    required this.badgePromoBg,
    required this.badgePromoFg,
    required this.badgeCountBg,
    required this.badgeCountFg,
    required this.navIndicator,
    required this.sectionKnot,
    required this.slateHighlight,
    required this.cameraFrame,
    required this.cameraActionBg,
    required this.cameraActionFg,
    required this.priceInputBg,
    required this.priceInputFg,
    required this.warningBg,
    required this.warningFg,
    required this.highlightBg,
    required this.highlightFg,
    required this.highlightRing,
    required this.notifyDot,
    required this.avatarBg,
    required this.avatarFg,
    required this.linkOnDark,
    required this.rangeLow,
    required this.rangeMid,
    required this.rangeHigh,
    required this.logoTag,
    required this.skeleton,
    required this.illuLemon,
    required this.illuTeal,
    required this.illuGreen,
    required this.illuSoft,
    required this.illuPaper,
    required this.illuShade,
    required this.illuLine,
    required this.onPrimaryOverlay,
  });

  final Color canvas;
  final Color paper;
  final Color fill100;
  final Color fill200;
  final Color line;
  final Color lineSoft;
  final Color ink;
  final Color inkMuted;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color accent;
  final Color onAccent;
  final Color slate;
  final Color onSlate;
  final Color slateMuted;
  final Color teal;
  final Color tealInk;
  final Color danger;
  final Color focus;
  final Color note;
  final Color priceBestBg;
  final Color priceBestFg;
  final Color priceTagBg;
  final Color cordeString;
  final Color proofHigh;
  final Color proofMedium;
  final Color proofLow;
  final Color brandMark1;
  final Color brandMark2;
  final Color brandMark3;
  final Color brandMark4;
  final Color brandMark5;
  final Color onBrandMark;
  final Color proofMediumFg;
  final Color saveBg;
  final Color saveFg;
  final Color badgeBetaBg;
  final Color badgeBetaFg;
  final Color badgePromoBg;
  final Color badgePromoFg;
  final Color badgeCountBg;
  final Color badgeCountFg;
  final Color navIndicator;
  final Color sectionKnot;
  final Color slateHighlight;
  final Color cameraFrame;
  final Color cameraActionBg;
  final Color cameraActionFg;
  final Color priceInputBg;
  final Color priceInputFg;
  final Color warningBg;
  final Color warningFg;
  final Color highlightBg;
  final Color highlightFg;
  final Color highlightRing;
  final Color notifyDot;
  final Color avatarBg;
  final Color avatarFg;
  final Color linkOnDark;
  final Color rangeLow;
  final Color rangeMid;
  final Color rangeHigh;
  final Color logoTag;
  final Color skeleton;
  final Color illuLemon;
  final Color illuTeal;
  final Color illuGreen;
  final Color illuSoft;
  final Color illuPaper;
  final Color illuShade;
  final Color illuLine;
  final Color onPrimaryOverlay;

  static const light = ComparoColors(
    canvas: ComparoPalette.sage25,
    paper: ComparoPalette.sage0,
    fill100: ComparoPalette.sage50,
    fill200: ComparoPalette.sage150,
    line: ComparoPalette.sage500,
    lineSoft: ComparoPalette.sage100,
    ink: ComparoPalette.forest800,
    inkMuted: ComparoPalette.sage700,
    primary: ComparoPalette.green600,
    onPrimary: ComparoPalette.sage0,
    primarySoft: ComparoPalette.green50,
    accent: ComparoPalette.lemon300,
    onAccent: ComparoPalette.forest800,
    slate: ComparoPalette.forest800,
    onSlate: ComparoPalette.sage40,
    slateMuted: ComparoPalette.sage300,
    teal: ComparoPalette.teal500,
    tealInk: ComparoPalette.teal700,
    danger: ComparoPalette.red700,
    focus: ComparoPalette.teal700,
    note: ComparoPalette.sage700,
    priceBestBg: ComparoPalette.lemon300,
    priceBestFg: ComparoPalette.forest800,
    priceTagBg: ComparoPalette.sage50,
    cordeString: ComparoPalette.sage500,
    proofHigh: ComparoPalette.green600,
    proofMedium: ComparoPalette.lemon300,
    proofLow: ComparoPalette.sage500,
    brandMark1: ComparoPalette.green600,
    brandMark2: ComparoPalette.teal700,
    brandMark3: ComparoPalette.earth700,
    brandMark4: ComparoPalette.violet700,
    brandMark5: ComparoPalette.brick700,
    onBrandMark: ComparoPalette.sage0,
    proofMediumFg: ComparoPalette.forest800,
    saveBg: ComparoPalette.lemon300,
    saveFg: ComparoPalette.forest800,
    badgeBetaBg: ComparoPalette.lemon300,
    badgeBetaFg: ComparoPalette.forest800,
    badgePromoBg: ComparoPalette.lemon300,
    badgePromoFg: ComparoPalette.forest800,
    badgeCountBg: ComparoPalette.lemon300,
    badgeCountFg: ComparoPalette.forest800,
    navIndicator: ComparoPalette.lemon300,
    sectionKnot: ComparoPalette.green600,
    slateHighlight: ComparoPalette.lemon300,
    cameraFrame: ComparoPalette.lemon300,
    cameraActionBg: ComparoPalette.lemon300,
    cameraActionFg: ComparoPalette.forest800,
    priceInputBg: ComparoPalette.lemon300,
    priceInputFg: ComparoPalette.forest800,
    warningBg: ComparoPalette.lemon300,
    warningFg: ComparoPalette.forest800,
    highlightBg: ComparoPalette.lemon300,
    highlightFg: ComparoPalette.forest800,
    highlightRing: ComparoPalette.lemon300,
    notifyDot: ComparoPalette.lemon300,
    avatarBg: ComparoPalette.lemon300,
    avatarFg: ComparoPalette.forest800,
    linkOnDark: ComparoPalette.lemon300,
    rangeLow: ComparoPalette.green600,
    rangeMid: ComparoPalette.lemon300,
    rangeHigh: ComparoPalette.sage150,
    logoTag: ComparoPalette.lemon300,
    skeleton: ComparoPalette.sage50,
    illuLemon: ComparoPalette.lemon300,
    illuTeal: ComparoPalette.teal500,
    illuGreen: ComparoPalette.green600,
    illuSoft: ComparoPalette.green50,
    illuPaper: ComparoPalette.sage0,
    illuShade: ComparoPalette.sage150,
    illuLine: ComparoPalette.forest800,
    onPrimaryOverlay: Color(0x2EFFFFFF),
  );

  static const dark = ComparoColors(
    canvas: ComparoPalette.sage950,
    paper: ComparoPalette.sage900,
    fill100: ComparoPalette.sage850,
    fill200: ComparoPalette.sage800,
    line: ComparoPalette.sage450,
    lineSoft: ComparoPalette.sage830,
    ink: ComparoPalette.sage60,
    inkMuted: ComparoPalette.sage350,
    primary: ComparoPalette.green400,
    onPrimary: ComparoPalette.forest950,
    primarySoft: ComparoPalette.green900,
    accent: ComparoPalette.lemon350,
    onAccent: ComparoPalette.lemon950,
    slate: ComparoPalette.forest850,
    onSlate: ComparoPalette.sage60,
    slateMuted: ComparoPalette.sage350,
    teal: ComparoPalette.teal400,
    tealInk: ComparoPalette.teal200,
    danger: ComparoPalette.red300,
    focus: ComparoPalette.teal200,
    note: ComparoPalette.sage350,
    priceBestBg: ComparoPalette.lemon350,
    priceBestFg: ComparoPalette.lemon950,
    priceTagBg: ComparoPalette.sage850,
    cordeString: ComparoPalette.sage450,
    proofHigh: ComparoPalette.green400,
    proofMedium: ComparoPalette.lemon350,
    proofLow: ComparoPalette.sage450,
    brandMark1: ComparoPalette.green400,
    brandMark2: ComparoPalette.teal200,
    brandMark3: ComparoPalette.earth700,
    brandMark4: ComparoPalette.violet700,
    brandMark5: ComparoPalette.brick700,
    onBrandMark: ComparoPalette.sage0,
    proofMediumFg: ComparoPalette.lemon950,
    saveBg: ComparoPalette.lemon350,
    saveFg: ComparoPalette.lemon950,
    badgeBetaBg: ComparoPalette.lemon350,
    badgeBetaFg: ComparoPalette.lemon950,
    badgePromoBg: ComparoPalette.lemon350,
    badgePromoFg: ComparoPalette.lemon950,
    badgeCountBg: ComparoPalette.lemon350,
    badgeCountFg: ComparoPalette.lemon950,
    navIndicator: ComparoPalette.lemon350,
    sectionKnot: ComparoPalette.green400,
    slateHighlight: ComparoPalette.lemon350,
    cameraFrame: ComparoPalette.lemon350,
    cameraActionBg: ComparoPalette.lemon350,
    cameraActionFg: ComparoPalette.lemon950,
    priceInputBg: ComparoPalette.lemon350,
    priceInputFg: ComparoPalette.lemon950,
    warningBg: ComparoPalette.lemon350,
    warningFg: ComparoPalette.lemon950,
    highlightBg: ComparoPalette.lemon350,
    highlightFg: ComparoPalette.lemon950,
    highlightRing: ComparoPalette.lemon350,
    notifyDot: ComparoPalette.lemon350,
    avatarBg: ComparoPalette.lemon350,
    avatarFg: ComparoPalette.lemon950,
    linkOnDark: ComparoPalette.lemon350,
    rangeLow: ComparoPalette.green400,
    rangeMid: ComparoPalette.lemon350,
    rangeHigh: ComparoPalette.sage800,
    logoTag: ComparoPalette.lemon350,
    skeleton: ComparoPalette.sage850,
    illuLemon: ComparoPalette.lemon350,
    illuTeal: ComparoPalette.teal400,
    illuGreen: ComparoPalette.green400,
    illuSoft: ComparoPalette.green900,
    illuPaper: ComparoPalette.sage900,
    illuShade: ComparoPalette.sage800,
    illuLine: ComparoPalette.sage60,
    onPrimaryOverlay: Color(0x2EFFFFFF),
  );

  @override
  ComparoColors copyWith({
    Color? canvas,
    Color? paper,
    Color? fill100,
    Color? fill200,
    Color? line,
    Color? lineSoft,
    Color? ink,
    Color? inkMuted,
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? accent,
    Color? onAccent,
    Color? slate,
    Color? onSlate,
    Color? slateMuted,
    Color? teal,
    Color? tealInk,
    Color? danger,
    Color? focus,
    Color? note,
    Color? priceBestBg,
    Color? priceBestFg,
    Color? priceTagBg,
    Color? cordeString,
    Color? proofHigh,
    Color? proofMedium,
    Color? proofLow,
    Color? brandMark1,
    Color? brandMark2,
    Color? brandMark3,
    Color? brandMark4,
    Color? brandMark5,
    Color? onBrandMark,
    Color? proofMediumFg,
    Color? saveBg,
    Color? saveFg,
    Color? badgeBetaBg,
    Color? badgeBetaFg,
    Color? badgePromoBg,
    Color? badgePromoFg,
    Color? badgeCountBg,
    Color? badgeCountFg,
    Color? navIndicator,
    Color? sectionKnot,
    Color? slateHighlight,
    Color? cameraFrame,
    Color? cameraActionBg,
    Color? cameraActionFg,
    Color? priceInputBg,
    Color? priceInputFg,
    Color? warningBg,
    Color? warningFg,
    Color? highlightBg,
    Color? highlightFg,
    Color? highlightRing,
    Color? notifyDot,
    Color? avatarBg,
    Color? avatarFg,
    Color? linkOnDark,
    Color? rangeLow,
    Color? rangeMid,
    Color? rangeHigh,
    Color? logoTag,
    Color? skeleton,
    Color? illuLemon,
    Color? illuTeal,
    Color? illuGreen,
    Color? illuSoft,
    Color? illuPaper,
    Color? illuShade,
    Color? illuLine,
    Color? onPrimaryOverlay,
  }) {
    return ComparoColors(
      canvas: canvas ?? this.canvas,
      paper: paper ?? this.paper,
      fill100: fill100 ?? this.fill100,
      fill200: fill200 ?? this.fill200,
      line: line ?? this.line,
      lineSoft: lineSoft ?? this.lineSoft,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      slate: slate ?? this.slate,
      onSlate: onSlate ?? this.onSlate,
      slateMuted: slateMuted ?? this.slateMuted,
      teal: teal ?? this.teal,
      tealInk: tealInk ?? this.tealInk,
      danger: danger ?? this.danger,
      focus: focus ?? this.focus,
      note: note ?? this.note,
      priceBestBg: priceBestBg ?? this.priceBestBg,
      priceBestFg: priceBestFg ?? this.priceBestFg,
      priceTagBg: priceTagBg ?? this.priceTagBg,
      cordeString: cordeString ?? this.cordeString,
      proofHigh: proofHigh ?? this.proofHigh,
      proofMedium: proofMedium ?? this.proofMedium,
      proofLow: proofLow ?? this.proofLow,
      brandMark1: brandMark1 ?? this.brandMark1,
      brandMark2: brandMark2 ?? this.brandMark2,
      brandMark3: brandMark3 ?? this.brandMark3,
      brandMark4: brandMark4 ?? this.brandMark4,
      brandMark5: brandMark5 ?? this.brandMark5,
      onBrandMark: onBrandMark ?? this.onBrandMark,
      proofMediumFg: proofMediumFg ?? this.proofMediumFg,
      saveBg: saveBg ?? this.saveBg,
      saveFg: saveFg ?? this.saveFg,
      badgeBetaBg: badgeBetaBg ?? this.badgeBetaBg,
      badgeBetaFg: badgeBetaFg ?? this.badgeBetaFg,
      badgePromoBg: badgePromoBg ?? this.badgePromoBg,
      badgePromoFg: badgePromoFg ?? this.badgePromoFg,
      badgeCountBg: badgeCountBg ?? this.badgeCountBg,
      badgeCountFg: badgeCountFg ?? this.badgeCountFg,
      navIndicator: navIndicator ?? this.navIndicator,
      sectionKnot: sectionKnot ?? this.sectionKnot,
      slateHighlight: slateHighlight ?? this.slateHighlight,
      cameraFrame: cameraFrame ?? this.cameraFrame,
      cameraActionBg: cameraActionBg ?? this.cameraActionBg,
      cameraActionFg: cameraActionFg ?? this.cameraActionFg,
      priceInputBg: priceInputBg ?? this.priceInputBg,
      priceInputFg: priceInputFg ?? this.priceInputFg,
      warningBg: warningBg ?? this.warningBg,
      warningFg: warningFg ?? this.warningFg,
      highlightBg: highlightBg ?? this.highlightBg,
      highlightFg: highlightFg ?? this.highlightFg,
      highlightRing: highlightRing ?? this.highlightRing,
      notifyDot: notifyDot ?? this.notifyDot,
      avatarBg: avatarBg ?? this.avatarBg,
      avatarFg: avatarFg ?? this.avatarFg,
      linkOnDark: linkOnDark ?? this.linkOnDark,
      rangeLow: rangeLow ?? this.rangeLow,
      rangeMid: rangeMid ?? this.rangeMid,
      rangeHigh: rangeHigh ?? this.rangeHigh,
      logoTag: logoTag ?? this.logoTag,
      skeleton: skeleton ?? this.skeleton,
      illuLemon: illuLemon ?? this.illuLemon,
      illuTeal: illuTeal ?? this.illuTeal,
      illuGreen: illuGreen ?? this.illuGreen,
      illuSoft: illuSoft ?? this.illuSoft,
      illuPaper: illuPaper ?? this.illuPaper,
      illuShade: illuShade ?? this.illuShade,
      illuLine: illuLine ?? this.illuLine,
      onPrimaryOverlay: onPrimaryOverlay ?? this.onPrimaryOverlay,
    );
  }

  @override
  ComparoColors lerp(ThemeExtension<ComparoColors>? other, double t) {
    if (other is! ComparoColors) return this;
    return ComparoColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      fill100: Color.lerp(fill100, other.fill100, t)!,
      fill200: Color.lerp(fill200, other.fill200, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineSoft: Color.lerp(lineSoft, other.lineSoft, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      slate: Color.lerp(slate, other.slate, t)!,
      onSlate: Color.lerp(onSlate, other.onSlate, t)!,
      slateMuted: Color.lerp(slateMuted, other.slateMuted, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      tealInk: Color.lerp(tealInk, other.tealInk, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      note: Color.lerp(note, other.note, t)!,
      priceBestBg: Color.lerp(priceBestBg, other.priceBestBg, t)!,
      priceBestFg: Color.lerp(priceBestFg, other.priceBestFg, t)!,
      priceTagBg: Color.lerp(priceTagBg, other.priceTagBg, t)!,
      cordeString: Color.lerp(cordeString, other.cordeString, t)!,
      proofHigh: Color.lerp(proofHigh, other.proofHigh, t)!,
      proofMedium: Color.lerp(proofMedium, other.proofMedium, t)!,
      proofLow: Color.lerp(proofLow, other.proofLow, t)!,
      brandMark1: Color.lerp(brandMark1, other.brandMark1, t)!,
      brandMark2: Color.lerp(brandMark2, other.brandMark2, t)!,
      brandMark3: Color.lerp(brandMark3, other.brandMark3, t)!,
      brandMark4: Color.lerp(brandMark4, other.brandMark4, t)!,
      brandMark5: Color.lerp(brandMark5, other.brandMark5, t)!,
      onBrandMark: Color.lerp(onBrandMark, other.onBrandMark, t)!,
      proofMediumFg: Color.lerp(proofMediumFg, other.proofMediumFg, t)!,
      saveBg: Color.lerp(saveBg, other.saveBg, t)!,
      saveFg: Color.lerp(saveFg, other.saveFg, t)!,
      badgeBetaBg: Color.lerp(badgeBetaBg, other.badgeBetaBg, t)!,
      badgeBetaFg: Color.lerp(badgeBetaFg, other.badgeBetaFg, t)!,
      badgePromoBg: Color.lerp(badgePromoBg, other.badgePromoBg, t)!,
      badgePromoFg: Color.lerp(badgePromoFg, other.badgePromoFg, t)!,
      badgeCountBg: Color.lerp(badgeCountBg, other.badgeCountBg, t)!,
      badgeCountFg: Color.lerp(badgeCountFg, other.badgeCountFg, t)!,
      navIndicator: Color.lerp(navIndicator, other.navIndicator, t)!,
      sectionKnot: Color.lerp(sectionKnot, other.sectionKnot, t)!,
      slateHighlight: Color.lerp(slateHighlight, other.slateHighlight, t)!,
      cameraFrame: Color.lerp(cameraFrame, other.cameraFrame, t)!,
      cameraActionBg: Color.lerp(cameraActionBg, other.cameraActionBg, t)!,
      cameraActionFg: Color.lerp(cameraActionFg, other.cameraActionFg, t)!,
      priceInputBg: Color.lerp(priceInputBg, other.priceInputBg, t)!,
      priceInputFg: Color.lerp(priceInputFg, other.priceInputFg, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      warningFg: Color.lerp(warningFg, other.warningFg, t)!,
      highlightBg: Color.lerp(highlightBg, other.highlightBg, t)!,
      highlightFg: Color.lerp(highlightFg, other.highlightFg, t)!,
      highlightRing: Color.lerp(highlightRing, other.highlightRing, t)!,
      notifyDot: Color.lerp(notifyDot, other.notifyDot, t)!,
      avatarBg: Color.lerp(avatarBg, other.avatarBg, t)!,
      avatarFg: Color.lerp(avatarFg, other.avatarFg, t)!,
      linkOnDark: Color.lerp(linkOnDark, other.linkOnDark, t)!,
      rangeLow: Color.lerp(rangeLow, other.rangeLow, t)!,
      rangeMid: Color.lerp(rangeMid, other.rangeMid, t)!,
      rangeHigh: Color.lerp(rangeHigh, other.rangeHigh, t)!,
      logoTag: Color.lerp(logoTag, other.logoTag, t)!,
      skeleton: Color.lerp(skeleton, other.skeleton, t)!,
      illuLemon: Color.lerp(illuLemon, other.illuLemon, t)!,
      illuTeal: Color.lerp(illuTeal, other.illuTeal, t)!,
      illuGreen: Color.lerp(illuGreen, other.illuGreen, t)!,
      illuSoft: Color.lerp(illuSoft, other.illuSoft, t)!,
      illuPaper: Color.lerp(illuPaper, other.illuPaper, t)!,
      illuShade: Color.lerp(illuShade, other.illuShade, t)!,
      illuLine: Color.lerp(illuLine, other.illuLine, t)!,
      onPrimaryOverlay: Color.lerp(onPrimaryOverlay, other.onPrimaryOverlay, t)!,
    );
  }
}

/// Espacements, rayons, tailles, mouvement (valeurs logiques en dp et ms).
abstract final class ComparoDims {
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double radiusSm = 6;
  static const double radiusMd = 12;
  static const double radiusCard = 16;
  static const double radiusLg = 20;
  static const double radiusPill = 999;
  static const double borderHairline = 1;
  static const double borderStrong = 2;
  static const double targetMin = 48;
  static const double targetPrimary = 48;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double thumbMd = 48;
  static const double thumbLg = 56;
  static const Duration durationFast = Duration(milliseconds: 120);
  static const Duration durationBase = Duration(milliseconds: 200);
  static const Duration durationSlow = Duration(milliseconds: 320);
  static const Curve easeStandard = Cubic(0.2, 0, 0, 1);
  static const Curve easeExit = Cubic(0.3, 0, 1, 1);
  static const double bpPhone = 390;
  static const double bpCompact = 900;
}

/// Styles de texte. Polices variables embarquées (Bricolage Grotesque, Manrope) : le poids passe par `fontVariations`.
abstract final class ComparoText {
  /// Polices embarquées par comparo_ui : dans une application, Flutter les enregistre sous `packages/comparo_ui/…`.
  static const String fontDisplay = 'packages/comparo_ui/Bricolage Grotesque';
  static const String fontSans = 'packages/comparo_ui/Manrope';

  static const TextStyle display = TextStyle(fontFamily: fontDisplay, fontSize: 30, height: 1.1333, fontWeight: FontWeight.w800, fontVariations: [FontVariation('wght', 800), FontVariation('opsz', 30)]);
  static const TextStyle title = TextStyle(fontFamily: fontDisplay, fontSize: 20, height: 1.3000, fontWeight: FontWeight.w600, fontVariations: [FontVariation('wght', 600), FontVariation('opsz', 20)]);
  static const TextStyle subtitle = TextStyle(fontFamily: fontSans, fontSize: 16, height: 1.3750, fontWeight: FontWeight.w600, fontVariations: [FontVariation('wght', 600)]);
  static const TextStyle body = TextStyle(fontFamily: fontSans, fontSize: 15, height: 1.4667, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)]);
  static const TextStyle caption = TextStyle(fontFamily: fontSans, fontSize: 13, height: 1.3846, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)]);
  static const TextStyle label = TextStyle(fontFamily: fontSans, fontSize: 12, height: 1.3333, fontWeight: FontWeight.w600, fontVariations: [FontVariation('wght', 600)], letterSpacing: 0.24);
  static const TextStyle priceLg = TextStyle(fontFamily: fontDisplay, fontSize: 30, height: 1.0667, fontWeight: FontWeight.w800, fontVariations: [FontVariation('wght', 800), FontVariation('opsz', 30)], fontFeatures: [FontFeature.tabularFigures()]);
  static const TextStyle price = TextStyle(fontFamily: fontDisplay, fontSize: 19, height: 1.1579, fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700), FontVariation('opsz', 19)], fontFeatures: [FontFeature.tabularFigures()]);
  static const TextStyle pricePlain = TextStyle(fontFamily: fontDisplay, fontSize: 17, height: 1.2941, fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700), FontVariation('opsz', 17)], fontFeatures: [FontFeature.tabularFigures()]);
  static const TextStyle priceGap = TextStyle(fontFamily: fontSans, fontSize: 12, height: 1.3333, fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)], fontFeatures: [FontFeature.tabularFigures()]);
  static const TextStyle unitPrice = TextStyle(fontFamily: fontSans, fontSize: 12, height: 1.3333, fontWeight: FontWeight.w500, fontVariations: [FontVariation('wght', 500)], fontFeatures: [FontFeature.tabularFigures()]);
  static const TextStyle cordePrice = TextStyle(fontFamily: fontDisplay, fontSize: 14, height: 1.1429, fontWeight: FontWeight.w800, fontVariations: [FontVariation('wght', 800), FontVariation('opsz', 14)], fontFeatures: [FontFeature.tabularFigures()]);
  static const TextStyle cordeVendor = TextStyle(fontFamily: fontSans, fontSize: 8.5, height: 1.1765, fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)], fontFeatures: [FontFeature.tabularFigures()]);
}

/// Thèmes Material prêts à l'emploi, avec l'extension [ComparoColors].
abstract final class ComparoTheme {
  static ThemeData light() => _build(Brightness.light, ComparoColors.light);
  static ThemeData dark() => _build(Brightness.dark, ComparoColors.dark);

  static ThemeData _build(Brightness b, ComparoColors c) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.primary, onPrimary: c.onPrimary,
      secondary: c.accent, onSecondary: c.onAccent,
      tertiary: c.teal, onTertiary: c.onPrimary,
      error: c.danger, onError: c.onPrimary,
      surface: c.paper, onSurface: c.ink, onSurfaceVariant: c.inkMuted,
      outline: c.line, outlineVariant: c.lineSoft,
    );
    return ThemeData(
      useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: c.canvas,
      fontFamily: ComparoText.fontSans, extensions: [c],
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
