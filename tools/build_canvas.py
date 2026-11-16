"""Construit les écrans du canvas depuis le prototype (source unique).
Usage : python3 build_canvas.py <prototype.html> <screens.json> <wf/project>
proto.css et les 5 écrans HF-Accueil/Resultats/Fiche/Panier/Releve sont générés : ne pas les modifier à la main."""
import json, re, sys
proto, sj, out = sys.argv[1:4]
s = open(proto, encoding='utf-8').read()
app = s[s.index('/* App */'):s.index('</style>')]
assert '--f-display' not in app and '--sh1' not in app
head = """/* Comparo — styles des écrans générés depuis le prototype par tools/build_canvas.py. Ne pas modifier à la main.
   Toutes les valeurs viennent des tokens du design system (ds/wf/tokens.css). */
/* ÉCART CONNU, conservé pour ne rien changer visuellement : le canvas force l'ardoise claire
   aussi en thème sombre. À retirer lors de la passe visuelle (le design system définit l'ardoise sombre). */
:root { --slate: #20392d; --on-slate: #f3f6ee; --slate-muted: #b9c8bd; }
*{box-sizing:border-box}
button{font:inherit;color:inherit;cursor:pointer}
:focus-visible{outline:2px solid var(--focus);outline-offset:2px}
.phone{width:390px;height:844px;background:var(--canvas);color:var(--ink);font-family:var(--font-sans);font-size:15px;line-height:1.45;-webkit-font-smoothing:antialiased;overflow:hidden;position:relative;display:flex;flex-direction:column}
.scr{flex:1;overflow:auto;display:flex;flex-direction:column;min-height:0}
"""
open(out + '/proto.css', 'w', encoding='utf-8').write(head + app)
d = json.load(open(sj, encoding='utf-8'))
M = {'accueil@t-first': ('HF-Accueil-Premier', 'Accueil · premier lancement'), 'accueil@t-off': ('HF-Accueil-HorsLigne', 'Accueil · hors connexion'), 'accueil@t-slow': ('HF-Accueil-Chargement', 'Accueil · réseau lent'), 'accueil': ('HF-Accueil', 'Accueil'), 'recherche': ('HF-Resultats', 'Résultats'), 'fiche': ('HF-Fiche', 'Fiche produit'), 'panier': ('HF-Panier', 'Ma liste'), 'releve': ('HF-Releve', 'Relever un prix')}
LINK = {'accueil': 'HF-Accueil', 'recherche': 'HF-Resultats', 'panier': 'HF-Panier', 'profil': 'HF-Profil', 'notifications': 'HF-Notifications', 'releves': 'HF-MesContributions', 'optimisation': 'HF-Optimisation', 'commande': 'HF-Commande', 'historique': 'HF-Historique', 'creer-alerte': 'HF-CreerAlerte', 'assistant': 'HF-Assistant', 'bienvenue': 'HF-Bienvenue'}
KEEP = {' id="c-photo"', ' id="c-p"', ' id="c-price"', ' id="c-where"', ' id="c-hint"', ' id="c-warn"', ' id="c-err"', ' id="q"'}
for k, (f, t) in M.items():
    if k not in d: continue
    h = d[k]
    h = re.sub(r' id="[^"]*"', lambda m: m.group(0) if m.group(0) in KEEP else '', h)
    h = h.replace(' data-act="open"', ' data-href="HF-Fiche.dc.html"')
    h = re.sub(r' data-go="([a-z-]+)"', lambda m: (' data-href="' + LINK[m.group(1)] + '.dc.html"') if m.group(1) in LINK else '', h)
    h = re.sub(r' data-(act|pid|i|v|d|c|to|m|z)="[^"]*"', '', h)
    doc = f'''<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<title>Comparo — {t}</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="ds/wf/tokens.css">
<link rel="stylesheet" href="ds/wf/components/bundle.css">
<link rel="stylesheet" href="proto.css">
<script src="ds/wf/components/bundle.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600..800&amp;family=Manrope:wght@400..800&amp;display=swap">
<style>body{{margin:0}}a{{color:inherit;text-decoration:none}}</style>
</helmet>
<div class="phone">
{h}
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":390,"height":844}}}}'>
class Component extends DCLogic {{ renderVals() {{ return {{}}; }} }}
</script>
</body>
</html>
'''
    open(out + '/' + f + '.dc.html', 'w', encoding='utf-8').write(doc)
print('canvas: proto.css + 5 écrans générés')
