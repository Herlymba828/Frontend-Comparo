Système de design du Comparateur de prix – Gabon. Identité « Marché & étiquettes » sur la palette P07 « Fraîcheur quotidienne » : le vert du marché pour agir et rassurer, le citron de l'étiquette pour le meilleur prix, beaucoup de blanc pour que les chiffres respirent.

## Principes

- **Un prix n'est jamais seul.** `PriceTag` vit dans une `OfferRow` ou une `ProductCard` avec produit, format, vendeur, zone, date, fraîcheur, confiance et disponibilité (PJ-PR-001).
- **Le meilleur prix porte l'étiquette.** Une seule étiquette citron par produit (`PriceTag variant="tag"`, `.ptag.best` ou l'étiquette de gauche d'une `PriceLine`), réservée à l'offre `is_best_offer` renvoyée par le serveur. Jamais sur une offre expirée ou indisponible.
- **On compare une liste, pas un prix.** L'usager achète ses courses de la semaine et chaque déplacement coûte : l'unité de valeur est l'économie en FCFA sur la liste, montrée sur l'accueil et dans Ma liste.
- **Rien d'inventé.** Une donnée absente s'affiche comme absente : « Date inconnue », « Dispo. inconnue », « — » (RC-003).
- **Expiré à part.** Prix expirés et offres indisponibles dans une section repliée en bas de liste, prix barré (RC-001).
- **Sens sans couleur seule.** Chaque niveau a un mot et une forme : fond plein, contour, pointillé. Le vert et le citron diffèrent nettement en luminosité.
- **Une action principale par écran**, en bas, à portée de pouce.

## Références UX (benchmark)

Mobbin n'était pas consultable (compte gratuit limité). Les références viennent d'apps connues qui résolvent des problèmes proches ; ce qui est repris :

| App | Problème proche | Repris ici |
| --- | --- | --- |
| GasBuddy | Prix participatifs qui vieillissent vite | L'âge du prix collé au prix (« il y a 2 j ») ; bouton « Toujours valable » pour confirmer sans ressaisir |
| Yuka | Rendre un jugement lisible en un regard | Écran Fiabilité : un verdict en gros, une jauge, une phrase d'explication, puis les détails |
| Too Good To Go | Cartes d'offres avec contraintes | Hiérarchie d'une offre : vendeur et prix d'abord, conditions en dessous ; prix promo avec ancien prix barré |
| Instacart | Comparer des formats différents | Prix à l'unité de référence sous chaque prix (« 990 FCFA / kg ») ; tuiles de catégories |
| Waze | Signalements communautaires | Contribution en moins de 30 secondes, champs minimaux, valeur par défaut « aujourd'hui » |
| Google Flights | Dire si un prix est bon | (P1) Barre de fourchette « bas / habituel / haut » sur la fiche, à partir de l'historique |
| Glovo, Jumia | Contexte africain mobile | Images légères, chiffres en FCFA sans décimales, interface utilisable en 3G |

## Marqueurs d'identité

Ces marqueurs rendent Comparo reconnaissable sans logo, et chacun sert l'usage. Le premier est la signature.

- **La corde à prix (`PriceLine`).** Les offres d'un produit pendent à une ficelle, placées selon leur prix, la moins chère en citron à gauche. En petit dans chaque résultat de recherche, en grand sur la fiche. C'est la comparaison en un regard.
- **L'étiquette, rare.** L'étiquette citron (`.ptag.best`) est réservée au meilleur prix. Les autres prix sont de simples chiffres (`.pnum`) suivis de leur écart (`.ecart`, « +150 F »). `.ptag` gris reste pour le prix affiché par un marchand sur son ardoise.
- **La preuve en une ligne (`ProofLine`).** « Vu il y a 2 j · vendeur vérifié · Fiable » remplace les badges fraîcheur + confiance dans les listes.
- **L'ardoise du marché.** `.slate` pour le « Prix du jour » de l'accueil, la liste comparée boutique par boutique et le tableau du marchand.
- **Ma liste.** Le panier devient une liste de courses : total par boutique, deux choix (`.choice`) « Tout au même endroit » ou « Le moins cher · N arrêts », économie affichée en étiquette.
- **Les pictogrammes produits.** Un picto plat par famille (sac de riz, bidon d'huile, paquet de sucre, boîte de lait, sardines, bouteille d'eau, savon, conserve), avec un repère de marque (initiale sur pastille colorée) pour distinguer deux produits voisins.
- **La saisie en étiquette.** Le relevé de prix commence par l'appareil photo ; le montant se tape dans une grande étiquette citron (`.tag-in`) et un écart de plus de 30 % avec les prix connus déclenche un avertissement avant l'envoi.
- **La ficelle, les aplats, la voix du marché.** `.sec` accroche les titres de section ; cartes à plat avec un filet `line-soft` (ombres réservées à ce qui flotte) ; « Au marché aujourd'hui », « Prix du jour », « le kilo revient à 990 F », « Toujours ce prix ? — Oui, toujours / Non, modifier ». L'onglet actif porte une mini-étiquette citron.

Logotype (provisoire, à valider) : mini-étiquette citron avec son trou, suivie de « Comparo » en Bricolage Grotesque 800.

## Ton et contenu

- Français, vouvoiement, phrases courtes. Boutons à l'infinitif, sans point final. Pas d'emoji.
- Montants : `4 950 FCFA` (espace fine, devise XAF affichée FCFA, sans décimales). Prix à l'unité en `unit-price`.
- Dates relatives jusqu'à 7 jours (« il y a 2 j »), puis absolues (« 3 nov. »).
- Vendeurs et prix fictifs en maquette entre crochets : [Vendeur], [PRIX].

## Architecture des tokens

Trois niveaux, générés depuis `tokens.json` par `tools/tokens.py` (ne modifiez jamais `tokens.css` à la main) :

| Niveau | Exemples | Qui l'utilise |
| --- | --- | --- |
| Primitives | `sage-25`, `green-600`, `lemon-300`, `earth-700` | Personne dans les écrans : seulement les sémantiques |
| Sémantiques | `canvas`, `ink`, `primary`, `accent`, `slate`, `line-soft` | Écrans et composants |
| Composant | `price-best-*`, `proof-*`, `save-*`, `badge-*`, `nav-indicator`, `warning-*`, `highlight-*`, `camera-*`, `price-input-*`, `range-*`, `illu-*`, `corde-string`, `brand-mark-1…5` | Les composants concernés |

Familles hors couleur : espacement (`space-1…8`), rayons (`radius-sm…pill`, `radius-card`), tailles (`target-min` et `target-primary` 48px, `icon-sm/md/lg`, `thumb-md/lg`), mouvement (`duration-fast/base/slow`, `ease-standard`, `ease-exit`), superposition (`z-raised`, `z-toast`, `z-overlay`), points de rupture (`bp-phone`, `bp-compact`).

Règle : le citron (`accent`) n'est jamais utilisé directement. Chaque usage passe par son token de composant, qui pointe aujourd'hui vers `accent` : étiquette du meilleur prix, économie, Bêta, Promo, compteur d'onglet, indicateur d'onglet, preuve « Plutôt fiable », avertissement, mise en avant, avatar, viseur photo, champ de prix, pictos (`illu-*`). Changer l'un ne change plus les autres. Les espacements, rayons et hauteurs minimales égaux à un token utilisent ce token.

Contrôle : `python3 tools/lint_tokens.py tokens.json <fichiers>` échoue sur une couleur en dur, un usage direct de `accent` ou un token inconnu, et compte les mesures sans token. `tools/mesures-restantes.md` liste ces mesures.

Contrats des composants : `python3 tools/contracts.py .` régénère les sections « Contrat » et la matrice ; il échoue si un composant n'a pas de contrat.

Une seule source, trois sorties : `tokens.css` (design system et canvas), `tokens-root.css` (bloc `:root` du prototype, recopié entre `tokens:begin` et `tokens:end`) et `flutter/comparo_tokens.dart`. Le script vérifie aussi les contrastes à chaque génération.

## Couleur

- Fond `canvas` (P07 #FAFBF5) ; cartes et listes sur `paper` avec un filet `line-soft` ; `slate` pour l'ardoise du marché.
- Texte `ink` (P07 #20392D) et `ink-muted` pour les métadonnées.
- `primary` (vert P07) : bouton principal, onglet actif, niveau « élevé » ; texte vert seulement sur `paper` et `canvas`.
- `accent` (citron P07) : l'étiquette du meilleur prix et le niveau « moyen », toujours avec `on-accent` dessus.
- `teal` (turquoise P07) : graphiques et illustrations ; `teal-ink` pour les liens.
- `danger` : erreurs de saisie et échecs, toujours avec un mot.
- Thème sombre fourni ; dans le sombre, le citron reste en fond, jamais en texte.

## Typographie

- **Bricolage Grotesque** (`--font-display`) pour les titres et les prix : chiffres larges et francs, comme sur une ardoise de marché.
- **Manrope** (`--font-sans`) pour l'interface : lisible en petit, chiffres tabulaires.
- Deux polices Google Fonts ; dans l'app Flutter, via le paquet `google_fonts` ou embarquées.
- Hiérarchie : `display` (accueil), `title` (barre d'app), `subtitle` (sections, vendeurs), `body`, `caption` (zone, date), `label` (badges, onglets) ; `price-lg` pour le meilleur prix, `price` dans les listes.

## Formes et espace

- Marge d'écran `space-4`, entre sections `space-6`, padding des lignes `space-3`.
- `radius-lg` (20px) pour la carte du meilleur prix et les feuilles, `radius-md` (12px) pour boutons, champs, offres, `radius-sm` (6px) pour vignettes, `radius-pill` pour recherche, onglets et badges.
- Motif signature : l'étiquette — coin gauche coupé en pointe et trou de suspension.
- Cibles tactiles ≥ 48px (règle Android : 48 dp), comme les boutons principaux. Focus : anneau `focus` de 2px, décalé de 2px.

## Iconographie

- Jeu d'icônes à choisir (décision ouverte) : trait arrondi 2px, 24px, style Lucide ou Phosphor. En attendant, formes neutres et glyphes texte (✓ ◐ !).
- Logotype provisoire : mini-étiquette citron + « Comparo » en Bricolage Grotesque 800 (à valider).

## Flutter

Deux livrables, tous deux générés ou tirés de ce design system :

- `flutter/comparo_tokens.dart` : `ComparoPalette` (primitives), `ComparoColors` (sémantiques et composant, `ThemeExtension` clair et sombre), `ComparoDims`, `ComparoText` (polices variables, poids via `fontVariations`) et `ComparoTheme.light()` / `.dark()`.
- `flutter/comparo_ui/` : le paquet des composants d'identité, avec ses tests et ses captures de référence (`test/goldens/`). Vérifié avec Flutter 3.47.9 : `flutter analyze` sans remarque (règles `flutter_lints`), 53 tests réussis, dont les états et limites des contrats et les règles d'accessibilité (cibles de 44 px, libellés, contrastes) sur deux écrans de démonstration en clair et en sombre.

```dart
MaterialApp(theme: ComparoTheme.light(), darkTheme: ComparoTheme.dark());
final c = context.comparo;
PriceLine(offers: offres, size: PriceLineSize.large, onSelect: ouvrirFiabilite);
```

| Composant | Widget Flutter (`comparo_ui`) |
| --- | --- |
| `PriceLine` | `PriceLine` (`CustomPainter` ; une cible accessible par étiquette) |
| `ListSummary` | `ListSummary` |
| `ProofLine` | `ProofLine` |
| `PriceTag` `variant="tag"`, économie, Bêta, Promo | `PriceTag.amount` / `PriceTag.text` + `PriceTagKind` |
| `.pnum`, `.ecart` | `PricePlain`, `PriceGap` |
| `Picto` | `ProductPicto` (`flutter_svg`) |
| `Slate` | `MarketSlate` + `SlateRow` |
| `.sec` | `SectionTitle` |
| Ligne d'offre | `OfferTile` |
| `.choice` | `ChoiceCard` |
| `.tag-in`, `.warn` | `PriceInputTag`, `ComparoWarning` |
| `BottomNav` | `ComparoNavigationBar` |
| `Button`, `TextField`, `Tabs` | widgets Material thématisés par `ComparoTheme` |

## Contrats des composants

Chaque composant a un contrat : rôle, props, comportement dans chaque état, limites, accessibilité, tokens. La source est `contracts.json` ; `tools/contracts.py` écrit la section « Contrat » de chaque fiche de composant et ce tableau, et échoue si un composant n'a pas de contrat complet. ✓ = décrit et codé · « à coder » = décrit, pas encore codé · — = sans objet.

| Composant | Statut | Chargement | Vide | Erreur | Hors connexion | Désactivé | Sélectionné / focus | Limites | Flutter |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `AppBar` | actif | — | — | — | — | — | — | 1 | AppBar thématisée |
| `AvailabilityChip` | actif | — | ✓ | — | — | — | — | 1 | à créer (texte + glyphe) |
| `Banner` | actif | — | — | — | ✓ | — | — | 1 | MaterialBanner thématisé |
| `BottomNav` | actif | — | — | — | ✓ | — | ✓ | 2 | ComparoNavigationBar |
| `Button` | actif | à coder | — | — | — | ✓ | ✓ | 2 | FilledButton / OutlinedBut… |
| `EmptyState` | actif | — | — | — | — | — | — | 1 | à créer |
| `Gauge` | actif | — | ✓ | — | — | — | — | 1 | à créer |
| `ListSummary` | actif | ✓ | ✓ | — | ✓ | — | — | 2 | ListSummary |
| `Picto` | actif | ✓ | ✓ | — | — | — | — | 2 | ProductPicto |
| `PriceLine` | actif | ✓ | ✓ | — | ✓ | — | ✓ | 4 | PriceLine |
| `PriceTag` | actif | — | ✓ | — | ✓ | — | — | 2 | PriceTag |
| `ProofLine` | actif | ✓ | ✓ | — | ✓ | — | — | 1 | ProofLine |
| `SearchBar` | actif | à coder | ✓ | — | à coder | — | ✓ | 1 | SearchBar thématisée |
| `Slate` | actif | ✓ | ✓ | ✓ | ✓ | — | ✓ | 2 | MarketSlate |
| `Tabs` | actif | — | — | — | — | à coder | ✓ | 1 | SegmentedButton thématisé |
| `TextField` | actif | — | — | ✓ | — | à coder | ✓ | 1 | TextField thématisé |
| `Annotation` | maquette | — | — | — | — | — | — | 1 | — |
| `FreshnessBadge` | déprécié | — | ✓ | — | — | — | — | 1 | — |
| `OfferRow` | déprécié | à coder | — | — | ✓ | ✓ | — | 2 | OfferTile |
| `Placeholder` | maquette | — | — | — | — | — | — | 1 | — |
| `ProductCard` | déprécié | — | — | — | — | — | — | 1 | — |
| `TrustBadge` | déprécié | — | — | — | — | ✓ | — | 1 | — |

Accessibilité : la grande corde est utilisable au clavier (chaque étiquette est un bouton avec son libellé) ; la liste des offres sous la corde reste l'accès principal pour les lecteurs d'écran.

## Abandons

| Abandonné | Remplacé par | Retrait prévu |
| --- | --- | --- |
| Classes sans préfixe `.ptag`, `.sec`, `.slate`, `.pnum`, `.ecart`, `.tag-in`, `.choice` | `.wf-ptag`, `.wf-sec`, `.wf-slate`, … (déjà disponibles) | à la passe visuelle |
| `.ptag` gris pour un prix consommateur | `.pnum` + `.ecart` | à la passe visuelle |
| `OfferRow` avec badges fraîcheur + confiance | `ProofLine` | à la passe visuelle |
| `ProductCard` avec photo grise et « dès » | `Picto` + `PriceLine` | à la passe visuelle |
| `BottomNav` par défaut « Alertes » et « Panier » | « Accueil, Recherche, Ma liste, Profil » | à la passe visuelle |
| `hf.css` (37 écrans du canvas) | écrans reconstruits depuis le prototype | à la passe visuelle |

## Écarts connus (passe visuelle à venir)

Corrigés dans la structure mais laissés tels quels à l'écran, à la demande :

- Texte du vendeur dans la grande corde à 8,5px (minimum 11px).
- Initiale de marque blanche sur `brand-mark-1` et `brand-mark-2` en thème sombre : contraste 2,1 et 1,6 (minimum 4,5).
- Le canvas force l'ardoise claire en thème sombre (`proto.css`).
- Mesures sans token : 126 dans le CSS des écrans, 40 valeurs distinctes (14px de padding et de rayon, 10px et 6px d'écart, 18px…), plus 233 styles en ligne dans les vues du prototype. Pour chacune : créer un token ou arrondir au plus proche (détail dans `tools/mesures-restantes.md`).

## Décisions ouvertes

- Jeu d'icônes et logo.
- Seuils de confiance et explication : fournis par l'API (à créer).
- Zone et distance : zone en texte, sans distance au MVP (hypothèse à confirmer).
- Légendes fines : une légende de 13 px en graisse 400 et `ink-muted` mesure 4,2:1 une fois rendue (test de contraste Flutter), sous le seuil de 4,5. Sous le titre de l'accueil, elle passe en graisse 600. Généraliser une graisse 500 aux légendes ? (à décider, changement visuel)
- Prix égaux au plus bas : une seule étiquette citron (`is_best_offer` choisi par le serveur) ; marquer toutes les offres à égalité ? (à décider)
- Ma liste : le total par boutique et le meilleur découpage en arrêts doivent être calculés par l'API (endpoint à créer) ; le coût du trajet n'est pas pris en compte (à décider).

## Journal des versions

- **v2.4.1 · 14 nov. 2026** — Cible tactile minimale portée de 44 à 48 px (`target-min`), conformément à la règle Android et aux tests d'accessibilité de l'app ; polices Flutter nommées `packages/comparo_ui/…` pour se charger dans une application. Les maquettes du canvas et du prototype gardent leurs 44 px écrits en dur (à reprendre).

- **v2.4 · 11 nov. 2026** — Accueil revu (changement visuel) : en-tête clair avec logotype, l'ardoise reste la seule surface forte ; « Ma liste de la semaine » passe en premier quand elle existe ; « Vus récemment » remplacé par « Racheter la liste du 4 nov. » ; états premier lancement, hors connexion et réseau lent. Prototype, canvas (3 nouveaux tableaux) et Flutter (`AccueilDemo`).
- **v2.3 · 11 nov. 2026** — Contrats complets pour les 22 composants (`contracts.json`, sections générées, contrôle de complétude). États codés : chargement, vide, erreur, hors connexion pour la corde, l'ardoise, la preuve, le picto et le nouveau `ListSummary` ; limites codées (8 offres, prix égaux sans chevauchement, prix longs, 5 lignes d'ardoise, libellés longs), en web, dans le prototype et en Flutter (45 tests). Écrans existants inchangés.
- **v2.2 · 11 nov. 2026** — Paquet Flutter `comparo_ui` : 11 widgets d'identité, écrans de démonstration, 24 tests (accessibilité comprise), captures de référence. Styles de texte Flutter sur polices variables.
- **v2.1 · 11 nov. 2026** — 37 tokens de composant (le citron n'est plus utilisé directement nulle part), 84 mesures branchées sur les tokens d'espacement, de rayon et de cible, contrôle automatique des valeurs en dur. Aucun changement visuel.
- **v2 · 11 nov. 2026** — Architecture des tokens à trois niveaux, familles taille, mouvement, superposition et points de rupture, tokens de composant (`price-best-*`, `proof-*`, `brand-mark-*`). Composants `Picto` et `Slate`. Corde accessible au clavier. Classes préfixées `wf-`. Tokens Flutter. Aucun changement visuel.
- **10 nov. 2026** — Direction « corde à prix » : `PriceLine`, `ProofLine`, étiquette rare, Ma liste comparée par boutique, saisie en étiquette.
- **10 nov. 2026** — Marqueurs d'identité : étiquette, pictos, ardoise (tokens `slate`), ficelle, aplats, voix du marché.
- **5 nov. 2026** — Première version : palette P07, 17 composants, identité « Marché & étiquettes ».
