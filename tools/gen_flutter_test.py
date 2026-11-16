"""Génère flutter-check/test/tokens_test.dart depuis tokens.json. Usage : python3 gen_flutter_test.py <tokens.json> <sortie.dart>"""
import json, sys
t = json.load(open(sys.argv[1]))
def camel(n):
    a = n.replace('-', ' ').split(); return a[0] + ''.join(w[:1].upper() + w[1:] for w in a[1:])
def dc(h):
    if h.startswith('rgba'):
        r, g, b, a = [x.strip() for x in h[5:-1].split(',')]; return '0x%02X%02X%02X%02X' % (round(float(a) * 255), int(r), int(g), int(b))
    return '0xFF' + h.lstrip('#').upper()
L = ["import 'package:flutter/material.dart';", "import 'package:flutter_test/flutter_test.dart';", "import 'package:comparo_tokens_check/comparo_tokens.dart';", "", "void main() {", "  test('couleurs = tokens.json', () {"]
for tk in t['color']['tokens']:
    if 'Primitive' in tk['usage']: continue
    for th in ('light', 'dark'):
        L.append(f"    expect(ComparoColors.{th}.{camel(tk['name'])}.toARGB32(), {dc(tk['value'][th])}, reason: '{tk['name']} {th}');")
L += ["  });", "  test('dimensions = tokens.json', () {"]
for fam in ('spacing', 'radius', 'size'):
    for tk in t[fam]['tokens']: L.append(f"    expect(ComparoDims.{camel(tk['name'])}, {float(tk['value'].replace('px', ''))});")
L += ["  });", """  testWidgets('les thèmes se construisent et exposent ComparoColors', (tester) async {
    for (final theme in [ComparoTheme.light(), ComparoTheme.dark()]) {
      late ComparoColors c;
      await tester.pumpWidget(MaterialApp(theme: theme, home: Builder(builder: (ctx) {
        c = Theme.of(ctx).extension<ComparoColors>()!;
        return Text('4 950 FCFA', style: ComparoText.priceLg.copyWith(color: c.priceBestFg));
      })));
      await tester.pumpAndSettle();
      expect(find.text('4 950 FCFA'), findsOneWidget);
      expect(theme.scaffoldBackgroundColor, c.canvas);
      expect(ComparoColors.light.lerp(ComparoColors.dark, 1).canvas, ComparoColors.dark.canvas);
    }
  });
}"""]
open(sys.argv[2], 'w').write("\n".join(L) + "\n")
