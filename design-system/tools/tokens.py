"""Comparo — génération des tokens (v2 : primitives + sémantiques).

Usage : python3 tokens.py <dossier project du DS>
Écrit tokens.json, tokens.css, tokens-root.css (bloc :root pour le prototype)
et flutter/comparo_tokens.dart. Toute valeur visible reste identique à la v1.
"""
import json, sys, os

D = sys.argv[1]

# ---------- 1. Primitives : la palette brute, sans usage ----------
P = [
 # Sauge : neutres légèrement verts (fonds, filets, textes secondaires)
 ("sage-0", "#ffffff"), ("sage-25", "#fafbf5"), ("sage-40", "#f3f6ee"), ("sage-50", "#eff2e6"),
 ("sage-60", "#eef3ea"), ("sage-100", "#e2e7da"), ("sage-150", "#dde4d2"), ("sage-300", "#b9c8bd"),
 ("sage-350", "#a8b8ad"), ("sage-450", "#7f9486"), ("sage-500", "#76877b"), ("sage-700", "#52645a"),
 ("sage-800", "#2b3c32"), ("sage-830", "#26352c"), ("sage-850", "#1f2d25"), ("sage-900", "#16221b"),
 ("sage-950", "#0f1813"),
 # Forêt : encre et ardoise
 ("forest-800", "#20392d"), ("forest-850", "#1d3428"), ("forest-950", "#0d2417"),
 # Vert marché (P07)
 ("green-50", "#e3f1e7"), ("green-400", "#5cc98b"), ("green-600", "#24834b"), ("green-900", "#1c3a29"),
 # Citron (P07)
 ("lemon-300", "#d7e96b"), ("lemon-350", "#cfe262"), ("lemon-950", "#1a2a10"),
 # Turquoise (P07)
 ("teal-200", "#7fd9d3"), ("teal-400", "#3cc0ba"), ("teal-500", "#29a6a1"), ("teal-700", "#1b706c"),
 # Rouge
 ("red-300", "#ff9b91"), ("red-700", "#b3261e"),
 # Terres : repères de marque des pictos
 ("earth-700", "#7a4f12"), ("violet-700", "#5b3f8c"), ("brick-700", "#9b3a26"),
]
PV = dict(P)

# ---------- 2. Sémantiques : un usage, une primitive par thème ----------
# (nom, primitive clair, primitive sombre, usage)
S = [
 ("canvas", "sage-25", "sage-950", "Fond d'écran de l'app (P07 fond)."),
 ("paper", "sage-0", "sage-900", "Cartes, feuilles, barres ; texte `ink` dessus."),
 ("fill-100", "sage-50", "sage-850", "Surfaces secondaires : champ de recherche, puces, vignettes."),
 ("fill-200", "sage-150", "sage-800", "Pistes de jauge, segments inactifs, séparateurs épais."),
 ("line", "sage-500", "sage-450", "Bordures porteuses de sens : champs, contours de badges, ficelle (≥3:1 sur `paper` et `canvas`)."),
 ("line-soft", "sage-100", "sage-830", "Filet des cartes à plat et séparateurs de liste."),
 ("ink", "forest-800", "sage-60", "Texte principal et prix sur `paper`, `canvas`, `fill-100`, `primary-soft`. Sur `accent`, utiliser `on-accent`."),
 ("ink-muted", "sage-700", "sage-350", "Métadonnées : vendeur, zone, date, écart de prix."),
 ("primary", "green-600", "green-400", "Vert marché : action principale, preuve « Fiable », onglet actif. Texte vert seulement sur `paper` et `canvas`."),
 ("on-primary", "sage-0", "forest-950", "Texte et icônes sur `primary`."),
 ("primary-soft", "green-50", "green-900", "Fond doux des états positifs."),
 ("accent", "lemon-300", "lemon-350", "Citron : l'étiquette du meilleur prix, une par produit ; preuve « Plutôt fiable »."),
 ("on-accent", "forest-800", "lemon-950", "Texte posé sur `accent`."),
 ("slate", "forest-800", "forest-850", "Ardoise du marché : Prix du jour, Ma liste par boutique, tableau du marchand ; texte `on-slate` dessus."),
 ("on-slate", "sage-40", "sage-60", "Texte et grands chiffres posés sur `slate`."),
 ("slate-muted", "sage-300", "sage-350", "Légendes et pointillés sur `slate`."),
 ("teal", "teal-500", "teal-400", "Turquoise : graphiques, illustrations, pictos ; jamais pour du texte courant."),
 ("teal-ink", "teal-700", "teal-200", "Liens et texte d'information turquoise sur `paper` et `canvas`."),
 ("danger", "red-700", "red-300", "Erreurs de saisie et échecs ; toujours avec un mot ou une icône."),
 ("focus", "teal-700", "teal-200", "Anneau de focus : 2px plein, décalé de 2px."),
 ("note", "sage-700", "sage-350", "Annotations de maquette uniquement."),
]

# ---------- 3. Tokens de composant : alias d'un sémantique ----------
# (nom, référence clair, référence sombre, usage) ; une référence = un token sémantique ou une primitive
K = [
 ("price-best-bg", "accent", "accent", "Fond de l'étiquette du meilleur prix et de l'étiquette de gauche de la corde."),
 ("price-best-fg", "on-accent", "on-accent", "Texte de l'étiquette du meilleur prix."),
 ("price-tag-bg", "fill-100", "fill-100", "Étiquette grise : prix affiché par un marchand sur son ardoise. Dépréciée pour les prix consommateur."),
 ("corde-string", "line", "line", "Ficelle et fils de la corde à prix."),
 ("proof-high", "primary", "primary", "Pastille pleine de la preuve « Fiable »."),
 ("proof-medium", "accent", "accent", "Demi-pastille de la preuve « Plutôt fiable »."),
 ("proof-low", "line", "line", "Contour de la preuve « À vérifier »."),
 ("brand-mark-1", "primary", "primary", "Repère de marque des pictos (initiale), 1/5."),
 ("brand-mark-2", "teal-ink", "teal-ink", "Repère de marque, 2/5."),
 ("brand-mark-3", "earth-700", "earth-700", "Repère de marque, 3/5."),
 ("brand-mark-4", "violet-700", "violet-700", "Repère de marque, 4/5."),
 ("brand-mark-5", "brick-700", "brick-700", "Repère de marque, 5/5."),
 ("on-brand-mark", "sage-0", "sage-0", "Initiale posée sur un repère de marque."),
 ("proof-medium-fg", "on-accent", "on-accent", "Texte posé sur `proof-medium` (pastille, verdict, niveau moyen)."),
 ("save-bg", "accent", "accent", "Étiquette d'économie (« −800 F »)."),
 ("save-fg", "on-accent", "on-accent", "Texte de l'étiquette d'économie."),
 ("badge-beta-bg", "accent", "accent", "Badge « Bêta »."),
 ("badge-beta-fg", "on-accent", "on-accent", "Texte du badge « Bêta »."),
 ("badge-promo-bg", "accent", "accent", "Badge « Promo » sur une offre."),
 ("badge-promo-fg", "on-accent", "on-accent", "Texte du badge « Promo »."),
 ("badge-count-bg", "accent", "accent", "Pastille de compteur sur un onglet (articles de la liste)."),
 ("badge-count-fg", "on-accent", "on-accent", "Chiffre de la pastille de compteur."),
 ("nav-indicator", "accent", "accent", "Mini-étiquette au-dessus de l'onglet actif."),
 ("section-knot", "primary", "primary", "Nœud de la ficelle devant un titre de section."),
 ("slate-highlight", "accent", "accent", "Coche ou chiffre mis en avant sur l'ardoise."),
 ("camera-frame", "accent", "accent", "Coins du viseur photo."),
 ("camera-action-bg", "accent", "accent", "Bouton « Prendre la photo »."),
 ("camera-action-fg", "on-accent", "on-accent", "Texte du bouton photo."),
 ("price-input-bg", "accent", "accent", "Champ de prix en forme d'étiquette."),
 ("price-input-fg", "on-accent", "on-accent", "Chiffres saisis dans le champ étiquette."),
 ("warning-bg", "accent", "accent", "Avertissement (prix à vérifier, prix ancien)."),
 ("warning-fg", "on-accent", "on-accent", "Texte d'un avertissement."),
 ("highlight-bg", "accent", "accent", "Carte ou pastille mise en avant (commande prête, notification)."),
 ("highlight-fg", "on-accent", "on-accent", "Texte posé sur `highlight-bg`."),
 ("highlight-ring", "accent", "accent", "Contour d'une carte mise en avant (Ma liste de la semaine)."),
 ("notify-dot", "accent", "accent", "Point de notification non lue."),
 ("avatar-bg", "accent", "accent", "Fond d'avatar (profil, support)."),
 ("avatar-fg", "on-accent", "on-accent", "Initiales d'un avatar."),
 ("link-on-dark", "accent", "accent", "Lien posé sur un bandeau sombre (hors connexion)."),
 ("range-low", "primary", "primary", "Segment « bas » d'une fourchette de prix."),
 ("range-mid", "accent", "accent", "Segment « habituel » d'une fourchette de prix."),
 ("range-high", "fill-200", "fill-200", "Segment « haut » d'une fourchette de prix."),
 ("logo-tag", "accent", "accent", "Mini-étiquette du logotype."),
 ("skeleton", "fill-100", "fill-100", "Blocs de chargement (squelettes)."),
 ("illu-lemon", "accent", "accent", "Illustrations et pictos : aplat citron."),
 ("illu-teal", "teal", "teal", "Illustrations et pictos : aplat turquoise."),
 ("illu-green", "primary", "primary", "Illustrations et pictos : aplat vert."),
 ("illu-soft", "primary-soft", "primary-soft", "Illustrations et pictos : aplat vert doux."),
 ("illu-paper", "paper", "paper", "Illustrations et pictos : aplat clair."),
 ("illu-shade", "fill-200", "fill-200", "Illustrations et pictos : ombre, couvercle."),
 ("illu-line", "ink", "ink", "Illustrations et pictos : trait."),
]
OVERLAY = [("on-primary-overlay", "rgba(255,255,255,0.18)", "rgba(255,255,255,0.18)", "Pastilles posées sur l'en-tête vert (zone, cloche).")]

def hexof(ref, theme):
    if ref in PV: return PV[ref]
    for n, l, d, u in S:
        if n == ref: return PV[l if theme == "light" else d]
    raise KeyError(ref)

SEM_NAMES = {n for n, *_ in S}

toks = {"name": "Comparo", "version": 2,
 "meta": {"source": "Palette P07 « Fraîcheur quotidienne » + identité « Marché & étiquettes » ; parcours et API du dépôt New-comparateur-de-prix",
          "architecture": "3 niveaux : primitives (palette brute) → sémantiques (usage, par thème) → composant (alias). Les écrans n'utilisent que les sémantiques et les tokens de composant."},
 "color": {"themes": [{"id": "light", "name": "Clair"}, {"id": "dark", "name": "Sombre"}],
  "tokens": [{"name": n, "value": {"light": PV[l], "dark": PV[d]}, "ref": {"light": l, "dark": d}, "usage": u} for n, l, d, u in S]
          + [{"name": n, "value": {"light": hexof(l, "light"), "dark": hexof(d, "dark")}, "ref": {"light": l, "dark": d}, "usage": u} for n, l, d, u in K]
          + [{"name": n, "value": {"light": l, "dark": d}, "usage": u} for n, l, d, u in OVERLAY]
          + [{"name": n, "value": {"light": v, "dark": v}, "usage": "Primitive : ne pas utiliser directement dans un écran."} for n, v in P]},
 "type": {"fonts": [], "families": {"display": "\"Bricolage Grotesque\", system-ui, sans-serif", "sans": "Manrope, system-ui, sans-serif", "mono": "ui-monospace, \"SF Mono\", Menlo, Consolas, monospace"},
  "groups": [
   {"name": "Titres", "family": "display", "styles": [
    {"name": "display", "fontSize": "30px", "lineHeight": "34px", "fontWeight": 800, "usage": "Titre d'écran d'accueil, une fois par écran.", "sample": "Au marché aujourd'hui"},
    {"name": "title", "fontSize": "20px", "lineHeight": "26px", "fontWeight": 600, "usage": "Titre de barre d'app et de fiche produit.", "sample": "Riz parfumé 5 kg"}]},
   {"name": "Interface", "family": "sans", "styles": [
    {"name": "subtitle", "fontSize": "16px", "lineHeight": "22px", "fontWeight": 600, "usage": "Titre de section, nom de vendeur dans une offre.", "sample": "Toutes les offres"},
    {"name": "body", "fontSize": "15px", "lineHeight": "22px", "fontWeight": 400, "usage": "Texte courant, champs, listes.", "sample": "Prix relevé il y a 2 jours à Owendo."},
    {"name": "caption", "fontSize": "13px", "lineHeight": "18px", "fontWeight": 400, "usage": "Métadonnées : zone, date, source.", "sample": "Libreville · relevé le 3 nov."},
    {"name": "label", "fontSize": "12px", "lineHeight": "16px", "fontWeight": 600, "letterSpacing": "0.02em", "usage": "Badges, onglets de navigation, boutons compacts.", "sample": "Vérifié"}]},
   {"name": "Prix", "family": "display", "styles": [
    {"name": "price-lg", "fontSize": "30px", "lineHeight": "32px", "fontWeight": 800, "usage": "Meilleur prix sur la fiche produit.", "sample": "4 950 FCFA"},
    {"name": "price", "fontSize": "19px", "lineHeight": "22px", "fontWeight": 700, "usage": "Prix dans une étiquette.", "sample": "5 200 FCFA"},
    {"name": "price-plain", "fontSize": "17px", "lineHeight": "22px", "fontWeight": 700, "usage": "Prix sans étiquette (`.pnum`) : toutes les offres sauf la meilleure.", "sample": "5 350 FCFA"},
    {"name": "price-gap", "family": "sans", "fontSize": "12px", "lineHeight": "16px", "fontWeight": 700, "usage": "Écart au meilleur prix (`.ecart`).", "sample": "+400 F"},
    {"name": "unit-price", "family": "sans", "fontSize": "12px", "lineHeight": "16px", "fontWeight": 500, "usage": "Prix à l'unité de référence sous le prix.", "sample": "990 FCFA / kg"},
    {"name": "corde-price", "fontSize": "14px", "lineHeight": "16px", "fontWeight": 800, "usage": "Prix dans une étiquette de la grande corde.", "sample": "4 950"},
    {"name": "corde-vendor", "family": "sans", "fontSize": "8.5px", "lineHeight": "10px", "fontWeight": 700, "usage": "Vendeur sous le prix dans la grande corde. Sous le minimum de 11px : à corriger lors de la passe visuelle.", "sample": "Rond-Point"}]},
   {"name": "Maquette", "family": "mono", "styles": [
    {"name": "annotation", "fontSize": "12px", "lineHeight": "16px", "fontWeight": 400, "usage": "Notes de wireframe en `note` ; n'apparaît pas dans l'app finale.", "sample": "① Le prix expiré n'est jamais présenté comme actuel"}]}]},
 "spacing": {"tokens": [
  {"name": "space-1", "value": "4px", "usage": "Écart icône–texte, entre badges."},
  {"name": "space-2", "value": "8px", "usage": "Écart interne des badges, entre lignes de méta."},
  {"name": "space-3", "value": "12px", "usage": "Padding vertical des lignes d'offre et des champs."},
  {"name": "space-4", "value": "16px", "usage": "Padding de carte."},
  {"name": "space-5", "value": "20px", "usage": "Marge latérale d'écran."},
  {"name": "space-6", "value": "24px", "usage": "Écart entre sections d'un écran."},
  {"name": "space-8", "value": "32px", "usage": "Respiration avant un état vide ou un bloc principal."}]},
 "radius": {"tokens": [
  {"name": "radius-sm", "value": "6px", "usage": "Badges, étiquettes, vignettes produit."},
  {"name": "radius-md", "value": "12px", "usage": "Boutons, champs, lignes d'offre."},
  {"name": "radius-card", "value": "16px", "usage": "Cartes à plat, choix d'achat."},
  {"name": "radius-lg", "value": "20px", "usage": "Ardoise, viseur photo, carte du meilleur prix, feuilles."},
  {"name": "radius-pill", "value": "999px", "usage": "Barre de recherche, puces de filtre."}]},
 "shadow": {"tokens": [
  {"name": "shadow-1", "value": {"light": "0 1px 2px rgba(32,57,45,0.08), 0 2px 8px rgba(32,57,45,0.06)", "dark": "0 1px 2px rgba(0,0,0,0.4)"}, "usage": "Réservée à ce qui flotte au repos (recherche) ; les cartes sont à plat."},
  {"name": "shadow-2", "value": {"light": "0 8px 24px rgba(32,57,45,0.14)", "dark": "0 8px 24px rgba(0,0,0,0.5)"}, "usage": "Feuille du bas, barre d'action, notification."}]},
 "border": {"tokens": [
  {"name": "border-hairline", "value": "1px", "usage": "Filet des cartes, champs, séparateurs."},
  {"name": "border-strong", "value": "2px", "usage": "Élément sélectionné, focus, meilleure offre."}]},
 "size": {"tokens": [
  {"name": "target-min", "value": "48px", "usage": "Cible tactile minimale (boutons d'icône, Ajouter, quantités)."},
  {"name": "target-primary", "value": "48px", "usage": "Hauteur des boutons principaux et des champs."},
  {"name": "icon-sm", "value": "16px", "usage": "Icône dans un bouton compact ou une puce."},
  {"name": "icon-md", "value": "20px", "usage": "Icône de navigation et de liste."},
  {"name": "icon-lg", "value": "24px", "usage": "Icône seule, état vide."},
  {"name": "thumb-md", "value": "48px", "usage": "Vignette picto dans une liste."},
  {"name": "thumb-lg", "value": "56px", "usage": "Vignette picto d'un résultat de recherche."}]},
 "motion": {"tokens": [
  {"name": "duration-fast", "value": "120ms", "usage": "Retour de pression, changement d'état d'un bouton."},
  {"name": "duration-base", "value": "200ms", "usage": "Ouverture d'un panneau, glissement de navigation."},
  {"name": "duration-slow", "value": "320ms", "usage": "Apparition d'une feuille du bas, message de confirmation."},
  {"name": "ease-standard", "value": "cubic-bezier(0.2, 0, 0, 1)", "usage": "Courbe par défaut des transitions."},
  {"name": "ease-exit", "value": "cubic-bezier(0.3, 0, 1, 1)", "usage": "Sortie d'un élément."}]},
 "zIndex": {"tokens": [
  {"name": "z-raised", "value": "1", "usage": "Barre d'onglets et pied d'écran collants."},
  {"name": "z-toast", "value": "5", "usage": "Message de confirmation."},
  {"name": "z-overlay", "value": "20", "usage": "Panneau de navigation ouvert, feuille du bas."},
  {"name": "z-overlay-control", "value": "21", "usage": "Bouton qui ferme un panneau ouvert."}]},
 "breakpoint": {"tokens": [
  {"name": "bp-phone", "value": "390px", "usage": "Largeur de référence des maquettes mobiles."},
  {"name": "bp-compact", "value": "900px", "usage": "En dessous : plein écran mobile ; au-dessus : back-office et vue bureau."}]},
}
os.makedirs(D, exist_ok=True)
json.dump(toks, open(D + "/tokens.json", "w"), ensure_ascii=False, indent=1)

# ---------- CSS ----------
def css_root(selector_light=':root, [data-theme="light"]', prefix=""):
    L = []
    L.append(":root {")
    L.append("  /* Primitives : palette brute, ne pas utiliser directement dans un écran */")
    L += [f"  --{n}: {v};" for n, v in P]
    L.append("}")
    SH = toks["shadow"]["tokens"]
    for theme, sel in (("light", selector_light), ("dark", '[data-theme="dark"]')):
        L.append(sel + " {")
        L.append("  /* Sémantiques */")
        L += [f"  --{n}: var(--{l if theme == 'light' else d});" for n, l, d, u in S]
        L.append("  /* Composant */")
        L += [f"  --{n}: var(--{l if theme == 'light' else d});" for n, l, d, u in K]
        L += [f"  --{n}: {l if theme == 'light' else d};" for n, l, d, u in OVERLAY]
        L += [f"  --{t['name']}: {t['value'][theme]};" for t in SH]
        L.append("}")
    L.append(":root {")
    for fam in ("spacing", "radius", "border", "size", "motion", "zIndex", "breakpoint"):
        L += [f"  --{t['name']}: {t['value']};" for t in toks[fam]["tokens"]]
    for k, v in toks["type"]["families"].items(): L.append(f"  --font-{k}: {v};")
    L.append("}")
    return L

L = ["/* Comparo — généré depuis tokens.json par tools/tokens.py. Ne pas modifier à la main. */"] + css_root()
for g in toks["type"]["groups"]:
    for s in g["styles"]:
        p = [f"font-family: var(--font-{s.get('family', g['family'])})", f"font-size: {s['fontSize']}", f"line-height: {s['lineHeight']}", f"font-weight: {s['fontWeight']}"]
        if "letterSpacing" in s: p.append(f"letter-spacing: {s['letterSpacing']}")
        if s["name"] in ("price-plain", "price-gap", "corde-price", "corde-vendor"): continue  # portés par .pnum / .ecart / la corde
        L.append(f".{s['name']} {{ " + "; ".join(p) + "; }")
open(D + "/tokens.css", "w").write("\n".join(L) + "\n")

# Bloc :root du prototype (même contenu, thème sombre aussi via prefers-color-scheme)
R = ["/* tokens:begin — généré par tools/tokens.py depuis tokens.json, ne pas modifier à la main */"]
R += css_root()
dark = [l for l in css_root()]
# media query sombre (le prototype suit aussi le réglage du système)
i0 = dark.index('[data-theme="dark"] {'); i1 = dark.index("}", i0)
body = dark[i0 + 1:i1]
R.append('@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {')
R += body
R.append("  color-scheme: dark; } }")
R.append('[data-theme="dark"] { color-scheme: dark; }')
R.append("/* tokens:end */")
open(D + "/tokens-root.css", "w").write("\n".join(R) + "\n")

# ---------- Flutter ----------
def dart_color(h):
    if h.startswith("rgba"):
        r, g, b, a = [x.strip() for x in h[5:-1].split(",")]
        return "Color(0x%02X%02X%02X%02X)" % (round(float(a) * 255), int(r), int(g), int(b))
    return "Color(0xFF" + h.lstrip("#").upper() + ")"
def camel(n):
    a = n.replace("-", " ").split(); return a[0] + "".join(w[:1].upper() + w[1:] for w in a[1:])
def px(v): return v.replace("px", "").replace("ms", "")

Dt = ["// Comparo — tokens Flutter générés depuis tokens.json par tools/tokens.py.",
      "// Ne pas modifier à la main : régénérez après toute modification des tokens.",
      "// ignore_for_file: constant_identifier_names", "",
      "import 'package:flutter/material.dart';", "",
      "/// Primitives : palette brute. Les widgets n'utilisent que [ComparoColors].",
      "abstract final class ComparoPalette {"]
Dt += [f"  static const Color {camel(n)} = {dart_color(v)};" for n, v in P]
Dt += ["}", "",
       "/// Couleurs sémantiques et de composant, par thème. Accès : `Theme.of(context).extension<ComparoColors>()!`.",
       "@immutable", "class ComparoColors extends ThemeExtension<ComparoColors> {", "  const ComparoColors({"]
ALLC = [(n, l, d) for n, l, d, u in S] + [(n, l, d) for n, l, d, u in K]
Dt += [f"    required this.{camel(n)}," for n, *_ in ALLC] + [f"    required this.{camel(n)}," for n, *_ in OVERLAY] + ["  });", ""]
Dt += [f"  final Color {camel(n)};" for n, *_ in ALLC] + [f"  final Color {camel(n)};" for n, *_ in OVERLAY] + [""]
for theme in ("light", "dark"):
    Dt.append(f"  static const {theme} = ComparoColors(")
    for n, l, d, *_ in [(a, b, c) for a, b, c in ALLC]:
        ref = l if theme == "light" else d
        if ref in PV: Dt.append(f"    {camel(n)}: ComparoPalette.{camel(ref)},")
        else:
            rr = [x for x in S if x[0] == ref][0]; Dt.append(f"    {camel(n)}: ComparoPalette.{camel(rr[1] if theme == 'light' else rr[2])},")
    for n, l, d, u in OVERLAY: Dt.append(f"    {camel(n)}: {dart_color(l if theme == 'light' else d)},")
    Dt.append("  );"); Dt.append("")
Dt += ["  @override", "  ComparoColors copyWith({" ] + [f"    Color? {camel(n)}," for n, *_ in ALLC + [(o[0],) for o in OVERLAY]] + ["  }) {", "    return ComparoColors("]
Dt += [f"      {camel(n)}: {camel(n)} ?? this.{camel(n)}," for n, *_ in ALLC + [(o[0],) for o in OVERLAY]] + ["    );", "  }", ""]
Dt += ["  @override", "  ComparoColors lerp(ThemeExtension<ComparoColors>? other, double t) {", "    if (other is! ComparoColors) return this;", "    return ComparoColors("]
Dt += [f"      {camel(n)}: Color.lerp({camel(n)}, other.{camel(n)}, t)!," for n, *_ in ALLC + [(o[0],) for o in OVERLAY]] + ["    );", "  }", "}", ""]
Dt += ["/// Espacements, rayons, tailles, mouvement (valeurs logiques en dp et ms).", "abstract final class ComparoDims {"]
for fam in ("spacing", "radius", "border", "size"):
    Dt += [f"  static const double {camel(t['name'])} = {px(t['value'])};" for t in toks[fam]["tokens"]]
Dt += [f"  static const Duration {camel(t['name'])} = Duration(milliseconds: {px(t['value'])});" for t in toks["motion"]["tokens"] if t["name"].startswith("duration")]
def bez(v):
    a = v[v.index("(") + 1:-1].split(","); return "Cubic(" + ", ".join(x.strip() for x in a) + ")"
Dt += [f"  static const Curve {camel(t['name'])} = {bez(t['value'])};" for t in toks["motion"]["tokens"] if t["name"].startswith("ease")]
Dt += [f"  static const double {camel(t['name'])} = {px(t['value'])};" for t in toks["breakpoint"]["tokens"]]
Dt += ["}", "", "/// Styles de texte. Polices variables embarquées (Bricolage Grotesque, Manrope) : le poids passe par `fontVariations`.",
       "abstract final class ComparoText {", "  /// Polices embarquées par comparo_ui : dans une application, Flutter les enregistre sous `packages/comparo_ui/…`.", "  static const String fontDisplay = 'packages/comparo_ui/Bricolage Grotesque';", "  static const String fontSans = 'packages/comparo_ui/Manrope';", ""]
for g in toks["type"]["groups"]:
    for s in g["styles"]:
        fam = s.get("family", g["family"])
        if fam == "mono": continue
        fs = float(px(s["fontSize"])); lh = float(px(s["lineHeight"]))
        ls = f", letterSpacing: {round(float(s['letterSpacing'].replace('em','')) * fs, 2)}" if "letterSpacing" in s else ""
        tab = ", fontFeatures: [FontFeature.tabularFigures()]" if g["name"] == "Prix" else ""
        var = f"FontVariation('wght', {s['fontWeight']})" + (f", FontVariation('opsz', {min(max(fs, 12), 96):g})" if fam == "display" else "")
        Dt.append(f"  static const TextStyle {camel(s['name'])} = TextStyle(fontFamily: font{fam.capitalize()}, fontSize: {fs:g}, height: {lh / fs:.4f}, fontWeight: FontWeight.w{s['fontWeight']}, fontVariations: [{var}]{ls}{tab});")
Dt += ["}", "",
       "/// Thèmes Material prêts à l'emploi, avec l'extension [ComparoColors].",
       "abstract final class ComparoTheme {",
       "  static ThemeData light() => _build(Brightness.light, ComparoColors.light);",
       "  static ThemeData dark() => _build(Brightness.dark, ComparoColors.dark);", "",
       "  static ThemeData _build(Brightness b, ComparoColors c) {",
       "    final scheme = ColorScheme(", "      brightness: b,",
       "      primary: c.primary, onPrimary: c.onPrimary,",
       "      secondary: c.accent, onSecondary: c.onAccent,",
       "      tertiary: c.teal, onTertiary: c.onPrimary,",
       "      error: c.danger, onError: c.onPrimary,",
       "      surface: c.paper, onSurface: c.ink, onSurfaceVariant: c.inkMuted,",
       "      outline: c.line, outlineVariant: c.lineSoft,",
       "    );",
       "    return ThemeData(",
       "      useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: c.canvas,",
       "      fontFamily: ComparoText.fontSans, extensions: [c],",
       "      materialTapTargetSize: MaterialTapTargetSize.padded,",
       "    );", "  }", "}", ""]
os.makedirs(D + "/flutter", exist_ok=True)
open(D + "/flutter/comparo_tokens.dart", "w").write("\n".join(Dt))

# ---------- Contrastes ----------
def lum(h):
    h = h.lstrip('#'); r = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    r = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in r]; return .2126 * r[0] + .7152 * r[1] + .0722 * r[2]
def cr(a, b):
    x, y = sorted([lum(a), lum(b)]); return (y + .05) / (x + .05)
V = {n: (PV[l], PV[d]) for n, l, d, u in S}
for n, l, d, u in K: V[n] = (hexof(l, "light"), hexof(d, "dark"))
CHECKS = [("on-slate", ["slate"], 4.5), ("slate-muted", ["slate"], 4.5), ("accent", ["slate"], 3), ("ink", ["paper", "canvas", "fill-100", "primary-soft"], 4.5),
          ("on-accent", ["accent"], 4.5), ("teal-ink", ["paper", "canvas"], 4.5), ("danger", ["paper", "canvas"], 4.5), ("primary", ["paper", "canvas"], 3),
          ("ink-muted", ["paper", "canvas", "fill-100", "primary-soft"], 4.5), ("line", ["paper", "canvas"], 3), ("on-primary", ["primary"], 4.5),
          ("focus", ["paper", "canvas"], 3), ("price-best-fg", ["price-best-bg"], 4.5),
          ("on-brand-mark", ["brand-mark-1", "brand-mark-2", "brand-mark-3", "brand-mark-4", "brand-mark-5"], 4.5)]
fails = 0
for fg, bgs, need in CHECKS:
    for b in bgs:
        l, d = cr(V[fg][0], V[b][0]), cr(V[fg][1], V[b][1]); ok = min(l, d) >= need
        fails += not ok
        print(("OK  " if ok else "BAS ") + f"{fg} sur {b} : clair {l:.2f} · sombre {d:.2f} (min {need})")
print("contrastes sous le seuil :", fails)
