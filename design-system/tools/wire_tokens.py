"""Branche les usages directs de --accent / --on-accent (et les couleurs d'identité) sur leurs tokens de composant.
Même valeur résolue : aucun changement visuel. Usage : python3 wire_tokens.py <prototype.html> <tokens-root.css> <bundle.css> <bundle.js>"""
import re, sys
proto, root, bcss, bjs = sys.argv[1:5]

# (motif présent juste avant l'occurrence, token pour accent, token pour on-accent)
RULES = [
 (".p-mid{", "proof-medium", "proof-medium-fg"),
 (".tag{", "price-best-bg", "price-best-fg"),
 ("left:calc(50% + 6px);min-width:18px", "badge-count-bg", "badge-count-fg"),
 (".g2 .on{", "proof-medium", None),
 (".ptag.best{", "price-best-bg", "price-best-fg"),
 ("button.on::after{", "nav-indicator", None),
 (".pf2 i{", "proof-medium", None),
 ("sl-row.on span:first-child::after", "slate-highlight", None),
 (".viewfinder .vf{", "camera-frame", None),
 (".vf-btn{", "camera-action-bg", "camera-action-fg"),
 (".tag-in input::placeholder{", None, "price-input-fg"),
 (".tag-in input{", None, "price-input-fg"),
 (".tag-in{", "price-input-bg", "price-input-fg"),
 (".warn{", "warning-bg", "warning-fg"),
 ("var PIC={", "illu-lemon", None),
 ("best=it.of===c[0]", "price-best-bg", "price-best-fg"),
 ("a5 5 0 0 1 -5 -5 Z\" fill=\"'+fill+'\" stroke=\"'+(best?", "price-best-bg", None),
 ("M9 1 H27 a2 2 0 0 1 2 2 V19", "logo-tag", None),
 ("tag(62,30,-5,92,\"5 350\"", "price-best-bg", "price-best-fg"),
 ("data-go=\"panier\" style=\"padding:16px;gap:10px;border:0;text-align:left;width:100%;box-shadow:inset 0 0 0 2px ", "highlight-ring", None),
 ("data-go=\"recherche\" style=\"padding:16px;gap:6px;border:0;text-align:left;width:100%;box-shadow:inset 0 0 0 2px ", "highlight-ring", None),
 ("top:6px;right:7px;width:9px;height:9px;border-radius:50%;background:", "notify-dot", None),
 ("\"Boissons\":[\"eau\",", "illu-lemon", None),
 ("vd[0]===\"Plutôt fiable\"?", "proof-medium", "proof-medium-fg"),
 ("linear-gradient(90deg,var(--primary) 0 33%,", "range-mid", None),
 ("width:60px;height:60px;border-radius:50%;background:", "avatar-bg", "avatar-fg"),
 ("var bg=n[0]===\"accent\"?", "highlight-bg", None),
 ("ic(n[1],18,n[0]===\"accent\"?", None, "highlight-fg"),
 ("o.st===\"ready\"?'<div class=\"col\" style=\"gap:6px;padding:18px;border-radius:20px;background:", "highlight-bg", "highlight-fg"),
 ("width:28px;height:28px;border-radius:50%;background:", "avatar-bg", None),
 ("border-radius:20px;background:'+(st>=2?", "highlight-bg", "highlight-fg"),
 ("color:'+(k===1&&c[0]?", "slate-highlight", None),
 ("x.fresh===\"old\"?\"box-shadow:inset 0 0 0 2px ", "warning-bg", None),
 ("M14 6 h44 a4 4 0 0 1 4 4 v28", "illu-lemon", None),
 ("data-act=\"online\" style=\"color:", "link-on-dark", None),
 ("w.innerHTML=Math.abs(d)>=30?'<div class=\"warn\">'+ic(\"info\",18,", None, "warning-fg"),
]

def wire(text, start, rules, window=420):
    out, last, unk = [], 0, []
    for m in re.finditer(r'var\(--(accent|on-accent)\)', text):
        if m.start() < start: continue
        before = text[max(start, m.start() - window):m.start()]
        best = None
        for key, ta, tf in rules:
            p = before.rfind(key)
            if p >= 0 and (best is None or p > best[0]):
                tok = ta if m.group(1) == 'accent' else tf
                if tok: best = (p, tok)
        if not best:
            unk.append(text[m.start() - 90:m.start() + 20].replace('\n', ' ')); continue
        out.append(text[last:m.start()] + 'var(--' + best[1] + ')'); last = m.end()
    out.append(text[last:])
    return ''.join(out), unk

s = open(proto, encoding='utf-8').read()
# 1. bloc tokens resynchronisé
a, b = s.index('/* tokens:begin'), s.index('/* tokens:end */') + len('/* tokens:end */')
s = s[:a] + open(root, encoding='utf-8').read().strip() + s[b:]
start = s.index('/* tokens:end */')
# PIC : toutes les couleurs des pictos passent aux tokens d'illustration
i, j = s.index('var PIC={'), None
j = s.index('};', i)
pic = s[i:j]
for sem, illu in (('accent', 'illu-lemon'), ('teal', 'illu-teal'), ('primary', 'illu-green'), ('primary-soft', 'illu-soft'), ('paper', 'illu-paper'), ('fill-200', 'illu-shade'), ('ink', 'illu-line')):
    pic = pic.replace('var(--' + sem + ')', 'var(--' + illu + ')')
s = s[:i] + pic + s[j:]
s, unk = wire(s, start, RULES)
# 2. étiquettes : modificateurs pour économie, Bêta, Promo (même rendu)
for old, new in (('class="tag">Bêta', 'class="tag tag-beta">Bêta'), ('class="tag" style="font-size:11px">Promo', 'class="tag tag-promo" style="font-size:11px">Promo'),
                 ('class="tag">−\'+fmt(L.worst-L.cur)', 'class="tag tag-save">−\'+fmt(L.worst-L.cur)'), ('class="tag">−\'+fmt(Math.max(0,L.wor', 'class="tag tag-save">−\'+fmt(Math.max(0,L.wor')):
    assert s.count(old) == 1, old; s = s.replace(old, new)
css_add = ('.tag-save{background:var(--save-bg);color:var(--save-fg)}.tag-beta{background:var(--badge-beta-bg);color:var(--badge-beta-fg)}'
           '.tag-promo{background:var(--badge-promo-bg);color:var(--badge-promo-fg)}')
k = s.index('.ptag.best{'); s = s[:k] + css_add + '\n' + s[k:]
# 3. preuve, jauge, corde, ficelle : vert et filets d'identité
for old, new in (('.pf3 i{background:var(--primary)}', '.pf3 i{background:var(--proof-high)}'),
                 ('.g3 .on{background:var(--primary)}', '.g3 .on{background:var(--proof-high)}'),
                 ('linear-gradient(90deg,var(--primary) 0 33%,var(--range-mid) 33% 66%,var(--fill-200) 66%)', 'linear-gradient(90deg,var(--range-low) 0 33%,var(--range-mid) 33% 66%,var(--range-high) 66%)')):
    assert s.count(old) == 1, old; s = s.replace(old, new)
m = re.search(r'\.pf1 i\{box-shadow:inset 0 0 0 1\.5px var\(--line\)\}', s); assert m
s = s.replace(m.group(0), '.pf1 i{box-shadow:inset 0 0 0 1.5px var(--proof-low)}')
s = s.replace('.pf2 i{background:linear-gradient(90deg,var(--proof-medium) 50%,var(--paper) 50%);box-shadow:inset 0 0 0 1.5px var(--line)}',
              '.pf2 i{background:linear-gradient(90deg,var(--proof-medium) 50%,var(--paper) 50%);box-shadow:inset 0 0 0 1.5px var(--proof-low)}')
# corde : ficelle et fils
cs, ce = s.index('function corde(p,big)'), s.index('function listStats()')
cor = s[cs:ce].replace('stroke="var(--line)"', 'stroke="var(--corde-string)"').replace('"var(--line)";', '"var(--corde-string)";')
s = s[:cs] + cor + s[ce:]
open(proto, 'w', encoding='utf-8').write(s)
print('prototype : occurrences non classées', len(unk)); [print('  ?', u) for u in unk]

# ---------- design system ----------
c = open(bcss, encoding='utf-8').read()
for old, new in (
 ('.wf-price-tag .wf-price-main { position: relative; background: var(--accent); color: var(--on-accent);', '.wf-price-tag .wf-price-main { position: relative; background: var(--price-best-bg); color: var(--price-best-fg);'),
 ('.wf-badge-mid { background: var(--accent); border-color: transparent; color: var(--on-accent); }', '.wf-badge-mid { background: var(--proof-medium); border-color: transparent; color: var(--proof-medium-fg); }'),
 ('.wf-banner-warning { background: var(--accent); color: var(--on-accent);', '.wf-banner-warning { background: var(--warning-bg); color: var(--warning-fg);'),
 ('.wf-tag { position: relative; display: inline-flex; align-items: center; background: var(--accent); color: var(--on-accent);', '.wf-tag { position: relative; display: inline-flex; align-items: center; background: var(--price-best-bg); color: var(--price-best-fg);'),
 ('.wf-gauge-3 .wf-gauge-track .on { background: var(--primary); }', '.wf-gauge-3 .wf-gauge-track .on { background: var(--proof-high); }'),
 ('.wf-gauge-2 .wf-gauge-track .on { background: var(--accent);', '.wf-gauge-2 .wf-gauge-track .on { background: var(--proof-medium);'),
 ('.ptag.best, .wf-ptag.best { background: var(--accent); color: var(--on-accent); }', '.ptag.best, .wf-ptag.best { background: var(--price-best-bg); color: var(--price-best-fg); }'),
 ('.wf-proof-3 i { background: var(--primary); }', '.wf-proof-3 i { background: var(--proof-high); }'),
 ('.wf-proof-2 i { background: linear-gradient(90deg, var(--accent) 50%, var(--paper) 50%); box-shadow: inset 0 0 0 1.5px var(--line); }', '.wf-proof-2 i { background: linear-gradient(90deg, var(--proof-medium) 50%, var(--paper) 50%); box-shadow: inset 0 0 0 1.5px var(--proof-low); }'),
 ('.wf-proof-1 i { box-shadow: inset 0 0 0 1.5px var(--line); }', '.wf-proof-1 i { box-shadow: inset 0 0 0 1.5px var(--proof-low); }'),
 ('.sec::before, .wf-sec::before { content: ""; width: 9px; height: 9px; border-radius: 50%; box-shadow: inset 0 0 0 2.5px var(--primary);', '.sec::before, .wf-sec::before { content: ""; width: 9px; height: 9px; border-radius: 50%; box-shadow: inset 0 0 0 2.5px var(--section-knot);'),
 ('repeating-linear-gradient(90deg, var(--line) 0 7px, transparent 7px 11px)', 'repeating-linear-gradient(90deg, var(--corde-string) 0 7px, transparent 7px 11px)'),
):
    assert c.count(old) == 1, old[:60]; c = c.replace(old, new)
c = re.sub(r'(sl-row\.on span:first-child::after \{ content: "[^"]*"; color: )var\(--accent\)', r'\1var(--slate-highlight)', c)
c = re.sub(r'(\.tag-in, \.wf-tag-in \{[^}]*?)background: var\(--accent\); color: var\(--on-accent\);', r'\1background: var(--price-input-bg); color: var(--price-input-fg);', c)
c = c.replace('font: 800 36px/46px var(--font-display); color: var(--on-accent);', 'font: 800 36px/46px var(--font-display); color: var(--price-input-fg);')
c = c.replace('input::placeholder { color: var(--on-accent);', 'input::placeholder { color: var(--price-input-fg);')
open(bcss, 'w', encoding='utf-8').write(c)
left = re.findall(r'.{50}var\(--(?:accent|on-accent)\)', c)
print('bundle.css : accent direct restant', len(left)); [print('  ?', x) for x in left]

js = open(bjs, encoding='utf-8').read()
i, j = js.index('var PICTOS = {'), js.index('};', js.index('var PICTOS = {'))
pic = js[i:j]
for sem, illu in (('accent', 'illu-lemon'), ('teal', 'illu-teal'), ('primary', 'illu-green'), ('primary-soft', 'illu-soft'), ('paper', 'illu-paper'), ('fill-200', 'illu-shade'), ('ink', 'illu-line')):
    pic = pic.replace('var(--' + sem + ')', 'var(--' + illu + ')')
js = js[:i] + pic + js[j:]
for old, new in (('fill = best ? "var(--accent)" : "var(--paper)", ink = best ? "var(--on-accent)" : "var(--ink)", st = best ? "var(--on-accent)" : "var(--line)"',
                  'fill = best ? "var(--price-best-bg)" : "var(--paper)", ink = best ? "var(--price-best-fg)" : "var(--ink)", st = best ? "var(--price-best-fg)" : "var(--corde-string)"'),
                 ('stroke: best ? "var(--accent)" : "var(--line)"', 'stroke: best ? "var(--price-best-bg)" : "var(--corde-string)"'),
                 ('stroke: "var(--line)", strokeWidth: 1.6', 'stroke: "var(--corde-string)", strokeWidth: 1.6'),
                 ('stroke: "var(--line)", strokeWidth: 1.2 })]', 'stroke: "var(--corde-string)", strokeWidth: 1.2 })]')):
    assert js.count(old) == 1, old[:50]; js = js.replace(old, new)
open(bjs, 'w', encoding='utf-8').write(js)
print('bundle.js : accent direct restant', len(re.findall(r'var\(--(?:accent|on-accent)\)', js)))
