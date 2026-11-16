"""Remplace les mesures égales à un token (espacements, rayons, cibles) par ce token, dans le CSS.
Ne touche ni aux valeurs négatives ni à calc(). Liste les valeurs sans token.
Usage : python3 tokenize_dims.py <prototype.html> <bundle.css> <rapport.md>"""
import re, sys, collections
proto, bcss, report = sys.argv[1:4]
SPACE = {"4px": "space-1", "8px": "space-2", "12px": "space-3", "16px": "space-4", "20px": "space-5", "24px": "space-6", "32px": "space-8"}
RADIUS = {"6px": "radius-sm", "12px": "radius-md", "16px": "radius-card", "20px": "radius-lg", "999px": "radius-pill"}
TARGET = {"44px": "target-min", "48px": "target-primary"}
PROPS = {}
for p in ("padding", "padding-top", "padding-right", "padding-bottom", "padding-left", "padding-inline", "padding-block",
          "margin", "margin-top", "margin-right", "margin-bottom", "margin-left", "gap", "row-gap", "column-gap"): PROPS[p] = SPACE
PROPS["border-radius"] = RADIUS
PROPS["min-height"] = TARGET
miss = collections.Counter(); done = collections.Counter()

def fix_value(prop, val):
    table = PROPS[prop]
    if "calc(" in val or "var(" in val and not re.search(r"\d+px", val): return val
    def rep(m):
        if m.group(1) == "-": return m.group(0)
        v = m.group(2)
        if v in table: done[prop if prop in ("border-radius", "min-height") else prop.split("-")[0]] += 1; return m.group(1) + "var(--" + table[v] + ")"
        if v != "0px": miss[(prop if prop in ("border-radius", "min-height") else prop.split("-")[0], v)] += 1
        return m.group(0)
    return re.sub(r"(^|[\s,(-])(\d+(?:\.\d+)?px)", rep, val)

def fix_css(css):
    def decl(m):
        prop, val = m.group(1), m.group(2)
        if prop not in PROPS or "calc(" in val: return m.group(0)
        return prop + m.group(3) + fix_value(prop, val)
    return re.sub(r"(?<![\w-])([a-z-]+)(\s*:\s*)([^;{}]+)", lambda m: decl_wrap(m), css)

def decl_wrap(m):
    prop, sep, val = m.group(1), m.group(2), m.group(3)
    if prop not in PROPS or "calc(" in val: return m.group(0)
    return prop + sep + fix_value(prop, val)

s = open(proto, encoding="utf-8").read()
a, b = s.index("/* App */"), s.index("</style>")
s = s[:a] + fix_css(s[a:b]) + s[b:]
open(proto, "w", encoding="utf-8").write(s)
c = open(bcss, encoding="utf-8").read()
k = c.index("body {")
c = c[:k] + fix_css(c[k:])
open(bcss, "w", encoding="utf-8").write(c)

inline = len(re.findall(r"style=\"[^\"]*\d+px", s[b:]))
L = ["# Mesures en dur restantes", "", f"Remplacées par un token : {sum(done.values())} ({', '.join(f'{k} {v}' for k, v in done.items())}).", "",
     f"Styles en ligne dans les vues du prototype contenant encore des pixels : {inline} (traités à la reconstruction des écrans avec les composants).", "",
     "Valeurs sans token (décision pour la passe visuelle : créer un token ou arrondir) :", "", "| Propriété | Valeur | Occurrences |", "| --- | --- | --- |"]
L += [f"| {p} | {v} | {n} |" for (p, v), n in sorted(miss.items(), key=lambda x: (-x[1], x[0]))]
open(report, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("remplacées", sum(done.values()), dict(done), "| sans token", sum(miss.values()), "valeurs distinctes", len(miss), "| styles en ligne", inline)
