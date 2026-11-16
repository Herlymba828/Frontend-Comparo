"""Contrôle des valeurs en dur. Sort en erreur (code 1) si :
- une couleur littérale (#hex, rgb(), rgba(), hsl()) apparaît hors des blocs de tokens ;
- --accent / --on-accent sont utilisés directement (l'identité passe par les tokens de composant) ;
- un var(--x) référence un token qui n'existe pas.
Avertit (sans échouer) sur les mesures d'espacement et de rayon sans token.
Usage : python3 lint_tokens.py <tokens.json> <fichier> [<fichier> …]"""
import json, re, sys
tok = json.load(open(sys.argv[1], encoding="utf-8"))
known = {t["name"] for fam in tok.values() if isinstance(fam, dict) and "tokens" in fam for t in fam["tokens"]}
known |= {"font-" + k for k in tok["type"]["families"]}
LOCAL = {"desk"}  # cadre du prototype, hors application
errors, warns = [], 0
for f in sys.argv[2:]:
    s = open(f, encoding="utf-8").read()
    if "/* tokens:end */" in s: s = s[s.index("/* tokens:end */"):]
    s = re.sub(r"/\* Cadre du prototype.*?\n(?:.*\n){3}", "", s)
    s = re.sub(r"@import url\([^)]*\);", "", s)
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
    if f.endswith("proto.css"): s = re.sub(r":root \{ --slate:[^}]*\}", "", s)  # écart connu documenté
    lines = s.split("\n")
    for n, line in enumerate(lines, 1):
        for m in re.finditer(r"#[0-9a-fA-F]{3,8}\b(?![\w-])|\brgba?\(|\bhsla?\(", line):
            ctx = line[max(0, m.start() - 30):m.end() + 20]
            if re.search(r"&#|href=\"#|data-go|#scr|#results|location\.hash", ctx): continue
            errors.append(f"{f}:{n}: couleur en dur « {ctx.strip()} »")
        for m in re.finditer(r"var\(--(accent|on-accent)\)", line):
            errors.append(f"{f}:{n}: --{m.group(1)} utilisé directement : passez par un token de composant")
        for m in re.finditer(r"var\(--([a-z0-9-]+)", line):
            name = m.group(1)
            if name.endswith("-") and any(k.startswith(name) for k in known): continue  # préfixe construit dynamiquement (brand-mark-N)
            if name not in known and name not in LOCAL:
                errors.append(f"{f}:{n}: token inconnu --{m.group(1)}")
    warns += len(re.findall(r"(?:padding|margin|gap|border-radius)[a-z-]*\s*:\s*[^;{}]*\b(?:3|7|9|10|14|18|19|22|26)px", s))
for e in errors: print("ERREUR", e)
print(f"{len(errors)} erreur(s) ; {warns} déclaration(s) avec une mesure sans token (voir le rapport des mesures)")
sys.exit(1 if errors else 0)
