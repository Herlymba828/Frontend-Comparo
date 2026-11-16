# comparo_ui

Composants d'identité Comparo pour l'application Flutter, tirés du design system (mêmes tokens, mêmes règles).

## Installation

```yaml
dependencies:
  comparo_ui:
    path: ../comparo_ui   # ou git
```

```dart
import 'package:comparo_ui/comparo_ui.dart';

MaterialApp(theme: ComparoTheme.light(), darkTheme: ComparoTheme.dark(), …);
final c = context.comparo; // couleurs du thème courant
```

Les polices (Bricolage Grotesque, Manrope, licence OFL) sont embarquées dans `fonts/` ; le poids passe par `fontVariations` (polices variables).

## Composants

| Design system | Flutter | Rôle |
| --- | --- | --- |
| `PriceLine` | `PriceLine(offers:, size:, onSelect:)` | Corde à prix ; en grand, chaque étiquette est un bouton (clavier, lecteur d'écran, cible ≥ 48) |
| `ProofLine` | `ProofLine(level:, age:, source:)` | Ligne de preuve : pastille + « Vu il y a 2 j · vendeur vérifié · Fiable » |
| `PriceTag variant="tag"` | `PriceTag.amount(4950, large: true)` | Étiquette du meilleur prix |
| `.tag-save`, Bêta, Promo | `PriceTag.text('−800 F', kind: PriceTagKind.save)` | Autres étiquettes, chacune sur son token |
| `.pnum` / `.ecart` | `PricePlain(5350)` / `PriceGap(price:, best:)` | Prix sans étiquette et écart « +400 F » |
| `Picto` | `ProductPicto(kind: PictoKind.riz, brand: 'Marque A')` | Picto produit et repère de marque |
| `Slate` | `MarketSlate(title:, rows: [SlateRow(…)])` | Ardoise du marché (5 lignes au plus) |
| `.sec` | `SectionTitle('Toutes les offres')` | Titre accroché à la ficelle |
| Ligne d'offre | `OfferTile(vendor:, price:, bestPrice:, proof:, onAdd:)` | Offre sous la corde, bouton Ajouter de 44 px |
| `.choice` | `ChoiceCard(title:, amount:, subtitle:, selected:)` | Choix d'achat de Ma liste |
| `.tag-in` + `.warn` | `PriceInputTag(controller:, knownLowest:)` / `ComparoWarning` | Saisie du prix en étiquette, alerte au-delà de 30 % d'écart |
| `BottomNav` | `ComparoNavigationBar(items:, currentIndex:, onTap:)` | Onglets avec mini-étiquette et compteur (99+) |
| `ListSummary` | `ListSummary(count:, best:, save:)`, `ListSummary.loading()` | Carte « Ma liste de la semaine » |
| squelettes | `Skeleton` | Bloc de chargement ; pulsation coupée si le système réduit les animations |

`package:comparo_ui/demo.dart` contient `FicheDemo`, `ListeDemo` et `AccueilDemo` (avec liste, sans liste, hors connexion, chargement), composés uniquement de ces widgets ; `demo_states.dart` contient `EtatsDemo`, la planche des états et limites.

## États et limites

Les contrats (source : `contracts.json` du design system) sont codés à l'identique :

- `PriceLine` : `loading`, `offline` ; 8 offres au plus (« +N autres offres dans la liste ») ; prix égaux répartis sur 3 rangs puis à droite et à gauche sans chevauchement ; prix longs resserrés ; 0 ou 1 offre = pas de corde.
- `MarketSlate` : `loading`, `error` + `onRetry`, liste vide, `offline` (date du cache) ; 5 lignes au plus ; libellé long coupé.
- `ListSummary` : défaut, vide (invitation), `loading`, `offline` (pas d'économie promise).
- `ProofLine.loading()`, `offline` ; 2 lignes au plus. `ProductPicto.loading()`. `OfferTile` : vendeur sur 2 lignes au plus.

## Vérification

```sh
flutter pub get
flutter analyze            # flutter_lints, aucune remarque
flutter test               # 53 tests : règles, géométrie de la corde, états et limites, accessibilité, contrastes, captures
flutter test --update-goldens test/golden_test.dart test/golden_states_test.dart   # régénère test/goldens/
```

Les tests d'accessibilité vérifient sur les écrans de démonstration, en clair et en sombre : cibles de 44 px (règle iOS), libellé de chaque cible, contraste des textes.

## Tokens

`lib/src/tokens.dart` est généré par `tools/tokens.py` du design system (`flutter/comparo_tokens.dart`) : recopiez-le après toute modification de `tokens.json`, ne l'éditez pas à la main.

## Décisions ouvertes

- Cible tactile : le design system fixe 44 px. La règle Android (Material) demande 48 dp ; les étiquettes de la grande corde et les lignes cliquables de l'ardoise font 44. Passer `target-min` à 48 pour l'app Android ?
- `ProofLine` reçoit le niveau tel que l'API le calcule (seuils côté serveur, chantier backend 4).
- Prix égaux au plus bas : une seule étiquette citron (`is_best_offer` choisi par le serveur). Faut-il marquer toutes les offres à égalité ?
