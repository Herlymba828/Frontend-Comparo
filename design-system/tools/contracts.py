"""Génère les sections « Contrat » des README de composants et la matrice du README principal
depuis contracts.json, et vérifie que chaque composant a un contrat complet.
Usage : python3 contracts.py <dossier project du design system>   (code 1 si un contrat manque)"""
import json, os, re, sys

D = sys.argv[1]
C = json.load(open(os.path.join(D, "contracts.json"), encoding="utf-8"))
LABELS = [("defaut", "Par défaut"), ("chargement", "Chargement"), ("vide", "Vide"), ("erreur", "Erreur"),
          ("horsConnexion", "Hors connexion"), ("desactive", "Désactivé"), ("selectionne", "Sélectionné / focus")]
NA = "—"
problems = []

comp_dir = os.path.join(D, "components")
dirs = sorted(d for d in os.listdir(comp_dir) if os.path.isdir(os.path.join(comp_dir, d)) and d != "Cover")
for d in dirs:
    if d not in C: problems.append(f"{d} : pas de contrat dans contracts.json")
for n in C:
    if n not in dirs: problems.append(f"{n} : contrat sans dossier de composant")

def section(n, c):
    pend = set(c.get("pending", []))
    L = ["<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->", "## Contrat", "",
         f"**Statut** : {c['status']}. **Flutter** : {c['flutter']}.", "", c["role"], "", f"**Props** : {c['props']}", "", "| État | Comportement |", "| --- | --- |"]
    for k, lab in LABELS:
        v = c["states"].get(k) or NA
        if k in pend: v += " *(à coder)*"
        L.append(f"| {lab} | {v} |")
    L += ["", "**Limites**", ""] + [f"- {x}" for x in c["limits"]]
    L += ["", "**Accessibilité**", ""] + [f"- {x}" for x in c["a11y"]]
    L += ["", "**Tokens** : " + ", ".join(f"`{t}`" for t in c["tokens"])]
    other = [p for p in pend if p not in dict(LABELS)]
    if other: L += ["", "**À coder** : " + ", ".join(other)]
    L.append("<!-- contrat:end -->")
    return "\n".join(L)

for n, c in C.items():
    p = os.path.join(comp_dir, n, "README.md")
    if not os.path.isdir(os.path.dirname(p)): continue
    s = open(p, encoding="utf-8").read() if os.path.exists(p) else ""
    s = re.sub(r"\n*<!-- contrat:begin.*?<!-- contrat:end -->\n?", "", s, flags=re.S).rstrip()
    open(p, "w", encoding="utf-8").write(s + "\n\n" + section(n, c) + "\n")

# Matrice du README principal
def cell(c, k):
    v = c["states"].get(k)
    if not v or v == NA: return NA
    return "à coder" if k in c.get("pending", []) else "✓"
rows = ["| Composant | Statut | " + " | ".join(l for k, l in LABELS[1:]) + " | Limites | Flutter |",
        "| --- | --- | " + " | ".join("---" for _ in LABELS[1:]) + " | --- | --- |"]
order = sorted(C, key=lambda n: (not C[n]["status"].startswith("actif"), n))
for n in order:
    c = C[n]
    st = "actif" if c["status"].startswith("actif") else ("maquette" if c["status"].startswith("maquette") else "déprécié")
    rows.append(f"| `{n}` | {st} | " + " | ".join(cell(c, k) for k, _ in LABELS[1:]) + f" | {len(c['limits'])} | {c['flutter'] if len(c['flutter']) < 28 else c['flutter'][:26] + '…'} |")
matrix = "\n".join(rows)
R = os.path.join(D, "README.md")
s = open(R, encoding="utf-8").read()
a = s.index("## Contrats des composants"); b = s.index("\n## ", a + 5)
intro = ("## Contrats des composants\n\nChaque composant a un contrat : rôle, props, comportement dans chaque état, limites, accessibilité, tokens. "
         "La source est `contracts.json` ; `tools/contracts.py` écrit la section « Contrat » de chaque fiche de composant et ce tableau, et échoue si un composant n'a pas de contrat complet. "
         "✓ = décrit et codé · « à coder » = décrit, pas encore codé · — = sans objet.\n\n")
s = s[:a] + intro + matrix + "\n\nAccessibilité : la grande corde est utilisable au clavier (chaque étiquette est un bouton avec son libellé) ; la liste des offres sous la corde reste l'accès principal pour les lecteurs d'écran.\n" + s[b:]
open(R, "w", encoding="utf-8").write(s)

pending = sum(len(c.get("pending", [])) for c in C.values())
for p in problems: print("ERREUR", p)
print(f"{len(C)} contrats écrits ; {pending} point(s) « à coder » ; {len(problems)} problème(s)")
sys.exit(1 if problems else 0)
