/* @ds-bundle: {"format":4,"namespace":"Wf","components":[{"name":"Button"},{"name":"SearchBar"},{"name":"TextField"},{"name":"Placeholder"},{"name":"PriceTag"},{"name":"FreshnessBadge"},{"name":"TrustBadge"},{"name":"AvailabilityChip"},{"name":"OfferRow"},{"name":"ProductCard"},{"name":"Banner"},{"name":"Tabs"},{"name":"AppBar"},{"name":"BottomNav"},{"name":"EmptyState"},{"name":"Annotation"},{"name":"Gauge"},{"name":"PriceLine"},{"name":"ProofLine"},{"name":"Picto"},{"name":"Slate"},{"name":"ListSummary"}]} */
(function () {
  var R = window.React, h = R.createElement;
  function cx() { return Array.prototype.filter.call(arguments, Boolean).join(" "); }
  function fmt(n) {
    if (n == null || n === "") return "—";
    return String(Math.round(Number(n))).replace(/\B(?=(\d{3})+(?!\d))/g, " ");
  }

  function Button(p) {
    var variant = p.variant || "primary", size = p.size || "md";
    return h("button", {
      type: p.type || "button", disabled: p.disabled, onClick: p.onClick,
      className: cx("wf-btn", "wf-btn-" + variant, "wf-btn-" + size, p.block && "wf-btn-block", p.className)
    }, p.children);
  }

  function SearchBar(p) {
    return h("label", { className: cx("wf-search", p.className) },
      h("span", { className: "wf-search-icon", "aria-hidden": "true" }),
      h("input", { type: "search", placeholder: p.placeholder || "Rechercher un produit", defaultValue: p.value, "aria-label": p.placeholder || "Rechercher un produit" }),
      p.voice ? h("span", { className: "wf-search-mic", "aria-label": "Recherche vocale", role: "img" }) : null);
  }

  function TextField(p) {
    var id = p.id || ("wf-f-" + String(p.label || "").replace(/\W+/g, "-").toLowerCase());
    return h("div", { className: cx("wf-field", p.error && "wf-field-error", p.className) },
      h("label", { htmlFor: id, className: "label" }, p.label),
      h("div", { className: "wf-field-box" },
        h("input", { id: id, placeholder: p.placeholder, defaultValue: p.value, inputMode: p.inputMode, "aria-invalid": !!p.error }),
        p.suffix ? h("span", { className: "wf-field-suffix caption" }, p.suffix) : null),
      p.error ? h("span", { className: "wf-field-msg caption" }, "⚠ " + p.error)
        : p.hint ? h("span", { className: "wf-field-msg caption" }, p.hint) : null);
  }

  function Placeholder(p) {
    return h("div", {
      className: cx("wf-ph", p.className), role: "img", "aria-label": p.label || "Image",
      style: { width: p.width || "100%", height: p.height || 120 }
    }, h("svg", { className: "wf-ph-x", viewBox: "0 0 100 100", preserveAspectRatio: "none", "aria-hidden": "true" },
      h("line", { x1: 0, y1: 0, x2: 100, y2: 100 }), h("line", { x1: 100, y1: 0, x2: 0, y2: 100 })),
      p.label ? h("span", { className: "wf-ph-label annotation" }, p.label) : null);
  }

  var PRICE_TYPES = { promo: "Promo", wholesale: "Gros", observed: "Relevé terrain" };
  function PriceTag(p) {
    var expired = p.freshness === "expired";
    return h("div", { className: cx("wf-price", "wf-price-" + (p.size || "md"), p.variant === "tag" && "wf-price-tag", expired && "wf-price-expired", p.className) },
      h("div", { className: "wf-price-main" },
        h("span", { className: p.size === "lg" ? "price-lg" : "price" }, fmt(p.amount), " ", p.currency || "FCFA"),
        p.priceType && PRICE_TYPES[p.priceType] ? h("span", { className: "wf-badge wf-badge-outline label" }, PRICE_TYPES[p.priceType]) : null),
      p.wasAmount ? h("span", { className: "caption wf-price-was" }, fmt(p.wasAmount) + " " + (p.currency || "FCFA")) : null,
      p.unitPrice ? h("span", { className: "unit-price wf-muted" }, fmt(p.unitPrice) + " " + (p.currency || "FCFA") + " / " + (p.unit || "unité")) : null,
      expired ? h("span", { className: "caption wf-muted" }, "Prix expiré — non actuel") : null);
  }

  var FRESH = { fresh: ["Récent", "good"], old: ["Ancien", "outline"], expired: ["Expiré", "dashed"], unknown: ["Date inconnue", "dashed"] };
  function FreshnessBadge(p) {
    var f = FRESH[p.level || "fresh"] || FRESH.unknown;
    return h("span", { className: cx("wf-badge", "wf-badge-" + f[1], "label", p.className) },
      h("span", { className: "wf-glyph wf-glyph-clock", "aria-hidden": "true" }),
      f[0], p.age ? h("span", { className: "wf-badge-extra" }, "· " + p.age) : null);
  }

  var TRUST = { high: ["Confiance élevée", "good", "✓"], medium: ["Confiance moyenne", "mid", "◐"], low: ["Confiance faible", "outline", "!"] };
  TRUST.verified = TRUST.high; TRUST.partial = TRUST.medium; TRUST.unverified = TRUST.low;
  function TrustBadge(p) {
    var t = TRUST[p.level || "high"] || TRUST.low;
    var inner = [h("span", { key: "g", className: "wf-glyph", "aria-hidden": "true" }, t[2]), t[0],
      p.source ? h("span", { key: "s", className: "wf-badge-extra" }, "· " + p.source) : null];
    return p.onClick
      ? h("button", { type: "button", onClick: p.onClick, className: cx("wf-badge", "wf-badge-" + t[1], "wf-badge-btn", "label", p.className) }, inner, h("span", { className: "wf-glyph", "aria-hidden": "true" }, "›"))
      : h("span", { className: cx("wf-badge", "wf-badge-" + t[1], "label", p.className) }, inner);
  }

  var AVAIL = { in: ["Disponible", "●"], low: ["Stock limité", "◒"], out: ["Épuisé", "○"], unknown: ["Dispo. inconnue", "?"] };
  function AvailabilityChip(p) {
    var a = AVAIL[p.status || "unknown"] || AVAIL.unknown;
    return h("span", { className: cx("wf-avail", "wf-avail-" + (p.status || "unknown"), "caption", p.className) },
      h("span", { className: "wf-glyph", "aria-hidden": "true" }, a[1]), a[0]);
  }

  function OfferRow(p) {
    return h("div", { className: cx("wf-offer", p.best && "wf-offer-best", p.freshness === "expired" && "wf-offer-expired", p.className) },
      h("div", { className: "wf-offer-head" },
        h("div", { className: "wf-offer-who" },
          p.best ? h("span", { className: "wf-tag label" }, "Meilleur prix") : null,
          h("span", { className: "subtitle" }, p.vendor),
          h("span", { className: "caption wf-muted" }, [p.zone, p.distance, p.date].filter(Boolean).join(" · "))),
        h(PriceTag, { amount: p.amount, unitPrice: p.unitPrice, unit: p.unit, priceType: p.priceType, freshness: p.freshness })),
      h("div", { className: "wf-offer-meta" },
        h(FreshnessBadge, { level: p.freshness || "fresh", age: p.age }),
        h(TrustBadge, { level: p.trust || "high" }),
        h(AvailabilityChip, { status: p.availability || "unknown" })),
      p.sponsored ? h("span", { className: "wf-sponsored label" }, "Sponsorisé") : null);
  }

  function ProductCard(p) {
    return h("article", { className: cx("wf-card", "wf-product", p.layout === "row" && "wf-product-row", p.className) },
      h(Placeholder, { height: p.layout === "row" ? 72 : 110, width: p.layout === "row" ? 72 : "100%", label: p.layout === "row" ? null : "Photo produit" }),
      h("div", { className: "wf-product-body" },
        h("span", { className: "subtitle" }, p.name),
        h("span", { className: "caption wf-muted" }, [p.brand, p.format].filter(Boolean).join(" · ")),
        h("div", { className: "wf-product-price" },
          h("span", { className: "caption wf-muted" }, "dès"),
          h("span", { className: "price" }, fmt(p.fromAmount), " FCFA")),
        h("span", { className: "caption wf-muted" }, (p.offers || 0) + " offre" + ((p.offers || 0) > 1 ? "s" : "") + " comparable" + ((p.offers || 0) > 1 ? "s" : ""))),
      p.sponsored ? h("span", { className: "wf-sponsored label" }, "Sponsorisé") : null);
  }

  var BANNER_GLYPH = { offline: "⊘", info: "i", warning: "!", success: "✓" };
  function Banner(p) {
    var tone = p.tone || "info";
    return h("div", { className: cx("wf-banner", "wf-banner-" + tone, p.className), role: tone === "warning" ? "alert" : "status" },
      h("span", { className: "wf-banner-glyph", "aria-hidden": "true" }, BANNER_GLYPH[tone] || "i"),
      h("div", { className: "wf-banner-text" },
        p.title ? h("span", { className: "subtitle" }, p.title) : null,
        p.children ? h("span", { className: "caption" }, p.children) : null),
      p.action ? h("button", { type: "button", className: "wf-btn wf-btn-ghost wf-btn-sm", onClick: p.onAction }, p.action) : null);
  }

  function Tabs(p) {
    var items = p.items || [], sel = p.value != null ? p.value : 0;
    return h("div", { className: cx("wf-tabs", p.className), role: "tablist" },
      items.map(function (it, i) {
        return h("button", { key: i, type: "button", role: "tab", "aria-selected": i === sel, className: cx("wf-tab", "label", i === sel && "wf-tab-on"), onClick: p.onChange ? function () { p.onChange(i); } : undefined }, it);
      }));
  }

  function AppBar(p) {
    return h("header", { className: cx("wf-appbar", p.className) },
      p.back ? h("button", { type: "button", className: "wf-icon-btn", "aria-label": "Retour" }, "‹") : h("span", { className: "wf-appbar-gap" }),
      h("span", { className: "title wf-appbar-title" }, p.title),
      h("div", { className: "wf-appbar-actions" }, (p.actions || []).map(function (a, i) {
        return h("button", { key: i, type: "button", className: "wf-icon-btn", "aria-label": a }, a.charAt(0));
      })));
  }

  var NAV = ["Accueil", "Recherche", "Alertes", "Panier", "Profil"];
  function BottomNav(p) {
    var items = p.items || NAV, sel = p.value || 0;
    return h("nav", { className: cx("wf-bnav", p.className), "aria-label": "Navigation principale" },
      items.map(function (it, i) {
        return h("a", { key: i, href: "#", className: cx("wf-bnav-item", i === sel && "wf-bnav-on"), "aria-current": i === sel ? "page" : undefined },
          h("span", { className: "wf-bnav-icon", "aria-hidden": "true" }), h("span", { className: "label" }, it));
      }));
  }

  function EmptyState(p) {
    return h("div", { className: cx("wf-empty", p.className) },
      h(Placeholder, { width: 72, height: 72 }),
      h("span", { className: "subtitle" }, p.title),
      p.children ? h("span", { className: "body wf-muted" }, p.children) : null,
      p.action ? h(Button, { variant: "secondary", onClick: p.onAction }, p.action) : null);
  }

  function Annotation(p) {
    return h("div", { className: cx("wf-note", "annotation", p.className) },
      p.n != null ? h("span", { className: "wf-note-n" }, p.n) : null, h("span", null, p.children));
  }

  var GAUGES = { freshness: { labels: ["Expiré", "Ancien", "Récent"], keys: { expired: 1, old: 2, fresh: 3 } },
    trust: { labels: ["Faible", "Moyenne", "Élevée"], keys: { low: 1, medium: 2, high: 3 } } };
  function Gauge(p) {
    var g = GAUGES[p.kind || "trust"], lvl = g.keys[p.level] || 0;
    return h("div", { className: cx("wf-gauge", "wf-gauge-" + lvl, p.className) },
      h("div", { className: "wf-gauge-head" },
        h("span", { className: "label wf-muted" }, p.label || (p.kind === "freshness" ? "FRAÎCHEUR" : "CONFIANCE")),
        h("span", { className: "subtitle" }, lvl ? g.labels[lvl - 1] : "Inconnue")),
      h("div", { className: "wf-gauge-track", role: "img", "aria-label": (lvl ? g.labels[lvl - 1] : "Inconnue") + ", niveau " + lvl + " sur 3" },
        [1, 2, 3].map(function (i) { return h("span", { key: i, className: i <= lvl ? "on" : "" }); })),
      p.children ? h("p", { className: "body wf-gauge-note" }, p.children) : null);
  }

  /* Corde à prix : les offres d'un produit accrochées à une ficelle, placées selon leur prix. */
  function shortName(n) { n = String(n || "").replace(/^(Épicerie|Supérette|Boutique|Dépôt) (du |de la |)/, ""); return n.length > 11 ? n.slice(0, 10) + "…" : n; }
  function PriceLineSkeleton(big) {
    var W = big ? 340 : 300, H = big ? 74 : 28, s = big ? 9 : 5, xs = big ? [40, 170, 300] : [12, 150, 288];
    return h("svg", { className: "wf-corde", viewBox: "0 0 " + W + " " + H, role: "img", "aria-busy": "true", "aria-label": "Chargement des prix" },
      h("path", { d: "M0 6 Q" + W / 2 + " " + (6 + 2 * s) + " " + W + " 6", fill: "none", stroke: "var(--corde-string)", strokeWidth: 1.6, strokeLinecap: "round" }),
      xs.map(function (x, i) { var w = big ? 66 : 14, ht = big ? 46 : 16; return h("rect", { key: i, className: "wf-skel-pulse", x: x - w / 2, y: big ? 22 : 12, width: w, height: ht, rx: big ? 5 : 2, fill: "var(--skeleton)" }); }));
  }

  var PRICELINE_MAX = 8;
  function PriceLine(p) {
    if (p.state === "loading") return PriceLineSkeleton(p.size === "lg");
    var all = (p.offers || []).slice().sort(function (a, b) { return a.price - b.price; });
    var c = all.slice(0, PRICELINE_MAX), extra = all.length - c.length;
    if (c.length < 2) return null;
    var big = p.size === "lg", mn = c[0].price, mx = c[c.length - 1].price, W = big ? 340 : 300, s = big ? 9 : 5, tw = big ? 66 : 14, pad = big ? tw / 2 + 2 : 10;
    function X(v) { return mx === mn ? W / 2 : pad + (v - mn) / (mx - mn) * (W - 2 * pad); }
    function Y(x) { var t = x / W; return 6 + 4 * s * t * (1 - t); }
    var last = [-999, -999, -999], placed = [[], [], []];
    var items = c.map(function (of) {
      var x = X(of.price), l = 0;
      if (big) {
        // 3 rangs ; si les trois sont pris à cet endroit, essai à droite puis à gauche, un pas d'étiquette à la fois.
        var d = tw + 4, cands = [x], found = false;
        for (var k = 1; k <= 12; k++) cands.push(x + k * d, x - k * d);
        for (var ci = 0; ci < cands.length && !found; ci++) {
          var cx = cands[ci];
          if (ci && (cx < tw / 2 || cx > W - tw / 2)) continue;
          for (var lv = 0; lv < 3 && !found; lv++) if (placed[lv].every(function (q) { return Math.abs(cx - q) >= d; })) { x = cx; l = lv; found = true; }
        }
        if (!found) l = 2; placed[l].push(x);
      } else { if (x - last[0] < 16) x = last[0] + 16; last[0] = x; }
      return { of: of, x: Math.min(x, W - 8), l: l };
    });
    var maxL = Math.max.apply(null, items.map(function (i) { return i.l; })), th = big ? 12 : 6, rowH = big ? 56 : 0, tagH = big ? 46 : 16;
    var H = Math.ceil(6 + 2 * s + th + maxL * rowH + tagH + (big ? 22 : 2));
    var kids = [h("path", { key: "f", d: "M0 6 Q" + W / 2 + " " + (6 + 2 * s) + " " + W + " 6", fill: "none", stroke: "var(--corde-string)", strokeWidth: 1.6, strokeLinecap: "round" })];
    items.slice().reverse().forEach(function (it, k) {
      var x = +it.x.toFixed(1), y = +Y(x).toFixed(1), best = it.of === c[0], ty = +(y + th + it.l * rowH).toFixed(1);
      var fill = best ? "var(--price-best-bg)" : "var(--paper)", ink = best ? "var(--price-best-fg)" : "var(--ink)", st = best ? "var(--price-best-fg)" : "var(--corde-string)", g = [h("path", { key: "t", d: "M" + x + " " + y + " V" + ty, stroke: "var(--corde-string)", strokeWidth: 1.2 })];
      if (big) {
        var hw = tw / 2;
        g.push(h("path", { key: "b", d: "M" + (x - hw) + " " + (ty + 10) + " L" + x + " " + ty + " L" + (x + hw) + " " + (ty + 10) + " V" + (ty + tagH - 5) + " a5 5 0 0 1 -5 5 H" + (x - hw + 5) + " a5 5 0 0 1 -5 -5 Z", fill: fill, stroke: best ? "var(--price-best-bg)" : "var(--corde-string)", strokeWidth: 1.2 }));
        g.push(h("circle", { key: "h", cx: x, cy: ty + 8, r: 2.4, fill: "var(--canvas)", stroke: st, strokeWidth: 1 }));
        g.push(h("text", { key: "p", x: x, y: ty + 28, textAnchor: "middle", fontFamily: "var(--font-display)", fontWeight: 800, fontSize: 14, fill: ink, textLength: fmt(it.of.price).length >= 7 ? tw - 10 : undefined, lengthAdjust: fmt(it.of.price).length >= 7 ? "spacingAndGlyphs" : undefined }, fmt(it.of.price)));
        g.push(h("text", { key: "v", x: x, y: ty + 40, textAnchor: "middle", fontFamily: "var(--font-sans)", fontWeight: 700, fontSize: 8.5, fill: ink, opacity: 0.8 }, shortName(it.of.vendor)));
      } else {
        g.push(h("path", { key: "b", d: "M" + (x - 7) + " " + (ty + 5) + " L" + x + " " + ty + " L" + (x + 7) + " " + (ty + 5) + " V" + (ty + 16) + " H" + (x - 7) + " Z", fill: fill, stroke: st, strokeWidth: 1.1, strokeLinejoin: "round" }));
        g.push(h("circle", { key: "h", cx: x, cy: ty + 5, r: 1.4, fill: "var(--canvas)" }));
      }
      var sel = p.onSelect ? function () { p.onSelect(it.of); } : undefined;
      kids.push(h("g", { key: "o" + k, onClick: sel,
        role: sel ? "button" : undefined, tabIndex: sel ? 0 : undefined,
        "aria-label": sel ? (it.of.vendor + ", " + fmt(it.of.price) + " FCFA" + (best ? ", le moins cher" : "")) : undefined,
        onKeyDown: sel ? function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); sel(); } } : undefined }, g));
    });
    if (big) {
      kids.push(h("text", { key: "l", x: 0, y: H - 3, fontFamily: "var(--font-sans)", fontWeight: 700, fontSize: 10, fill: "var(--ink-muted)" }, "moins cher"));
      kids.push(h("text", { key: "r", x: W, y: H - 3, textAnchor: "end", fontFamily: "var(--font-sans)", fontWeight: 700, fontSize: 10, fill: "var(--ink-muted)" }, "plus cher"));
    }
    var svg = h("svg", { className: cx("wf-corde", p.className), viewBox: "0 0 " + W + " " + H, role: "img",
      "aria-label": c.length + " offre" + (c.length > 1 ? "s" : "") + " de " + fmt(mn) + " à " + fmt(mx) + " FCFA ; la moins chère en citron"
        + (extra ? " ; " + extra + " autre" + (extra > 1 ? "s" : "") + " non affichée" + (extra > 1 ? "s" : "") : "") + (p.offline ? " ; hors connexion" : "") }, kids);
    if (!extra || !big) return svg;
    return h("div", { className: "wf-corde-wrap" }, svg,
      h("span", { className: "caption wf-muted" }, "+" + extra + " autre" + (extra > 1 ? "s" : "") + " offre" + (extra > 1 ? "s" : "") + " dans la liste"));
  }

  /* Ligne de preuve : un seul indicateur à la place des badges fraîcheur + confiance. */
  var PROOF = { high: ["Fiable", 3], medium: ["Plutôt fiable", 2], low: ["À vérifier", 1] };
  function ProofLine(p) {
    if (p.state === "loading") return h("span", { className: cx("wf-proof", p.className), "aria-busy": "true", "aria-label": "Chargement" },
      h("i", { className: "wf-skel-pulse", style: { background: "var(--skeleton)" } }), h("span", { className: "wf-skel", style: { width: 170, height: 12 } }));
    var v = PROOF[p.level] || PROOF.low, src = p.source === "vendor" ? " · vendeur vérifié" : p.source === "field" ? " · relevé terrain" : "";
    return h("span", { className: cx("wf-proof", "wf-proof-" + v[1], p.className) },
      h("i", { "aria-hidden": "true" }, v[1] === 3 ? "✓" : null),
      h("span", null, "Vu " + (p.age || "à une date inconnue") + src + " · ", h("b", null, v[0]), p.offline ? " · hors connexion" : null));
  }

  /* Pictogrammes produits : un picto plat par famille, avec le repère de marque. */
  var PICTOS = {
 riz:'<path d="M13 13 Q24 8 35 13 L38 40 Q24 45 10 40 Z" fill="var(--illu-lemon)" stroke="var(--illu-line)" stroke-width="2" stroke-linejoin="round"/><path d="M15 14 Q24 18 33 14" fill="none" stroke="var(--illu-line)" stroke-width="2"/><rect x="17" y="24" width="14" height="9" rx="2" fill="var(--illu-green)"/>',
 huile:'<rect x="12" y="15" width="24" height="27" rx="5" fill="var(--illu-teal)" stroke="var(--illu-line)" stroke-width="2"/><rect x="20" y="8" width="8" height="7" rx="1.5" fill="var(--illu-green)" stroke="var(--illu-line)" stroke-width="2"/><path d="M30 18 h4 a3 3 0 0 1 3 3 v6" fill="none" stroke="var(--illu-line)" stroke-width="2"/><rect x="16" y="26" width="16" height="8" rx="2" fill="var(--illu-lemon)"/>',
 sucre:'<path d="M12 16 L24 10 L36 16 V38 L24 44 L12 38 Z" fill="var(--illu-paper)" stroke="var(--illu-line)" stroke-width="2" stroke-linejoin="round"/><path d="M12 16 L24 22 L36 16 M24 22 V44" fill="none" stroke="var(--illu-line)" stroke-width="2"/><rect x="15" y="26" width="6" height="6" fill="var(--illu-green)"/>',
 lait:'<rect x="13" y="12" width="22" height="30" rx="4" fill="var(--illu-paper)" stroke="var(--illu-line)" stroke-width="2"/><rect x="13" y="20" width="22" height="12" fill="var(--illu-green)"/><ellipse cx="24" cy="12" rx="11" ry="3" fill="var(--illu-shade)" stroke="var(--illu-line)" stroke-width="2"/>',
 sardine:'<rect x="8" y="16" width="32" height="18" rx="9" fill="var(--illu-teal)" stroke="var(--illu-line)" stroke-width="2"/><path d="M15 25 q7 -6 14 0 q-7 6 -14 0 z M29 25 l5 -3 v6 z" fill="var(--illu-paper)"/>',
 eau:'<path d="M20 6 h8 v5 l3 5 v24 a4 4 0 0 1 -4 4 h-6 a4 4 0 0 1 -4 -4 V16 l3 -5 z" fill="var(--illu-soft)" stroke="var(--illu-line)" stroke-width="2" stroke-linejoin="round"/><rect x="19" y="5" width="10" height="5" rx="1.5" fill="var(--illu-green)"/><rect x="17" y="24" width="14" height="8" fill="var(--illu-teal)"/>',
 savon:'<rect x="9" y="18" width="30" height="18" rx="8" fill="var(--illu-lemon)" stroke="var(--illu-line)" stroke-width="2"/><circle cx="16" cy="12" r="3" fill="none" stroke="var(--illu-teal)" stroke-width="2"/><circle cx="24" cy="9" r="2" fill="none" stroke="var(--illu-teal)" stroke-width="2"/><path d="M15 27 h18" stroke="var(--illu-line)" stroke-width="2" stroke-linecap="round" opacity=".4"/>',
 conserve:'<rect x="12" y="13" width="24" height="28" rx="3" fill="var(--illu-paper)" stroke="var(--illu-line)" stroke-width="2"/><rect x="12" y="19" width="24" height="15" fill="var(--illu-lemon)"/><circle cx="24" cy="26.5" r="5" fill="var(--illu-green)"/><ellipse cx="24" cy="13" rx="12" ry="3" fill="var(--illu-shade)" stroke="var(--illu-line)" stroke-width="2"/>'
};
  function Picto(p) {
    if (p.state === "loading") return h("span", { className: cx("wf-thumb", "wf-skel-pulse", p.size === "lg" && "wf-thumb-lg", p.className), "aria-hidden": "true" });
    var k = PICTOS[p.kind] ? p.kind : "riz", b = p.brand ? String(p.brand).replace(/^Marque /, "") : "";
    return h("span", { className: cx("wf-thumb", p.size === "lg" && "wf-thumb-lg", p.className) },
      h("svg", { viewBox: "0 0 48 48", "aria-hidden": "true", dangerouslySetInnerHTML: { __html: PICTOS[k] } }),
      b ? h("span", { className: "wf-brand", title: p.brand, style: { background: "var(--brand-mark-" + (b.charCodeAt(0) % 5 + 1) + ")" } }, b.charAt(0)) : null);
  }

  /* Ardoise du marché : panneau sombre à lignes « produit ........ prix ». */
  var SLATE_MAX = 5;
  function Slate(p) {
    var rows = p.rows || [];
    if (rows.length > SLATE_MAX && window.console) console.warn("Slate : " + SLATE_MAX + " lignes au plus, " + (rows.length - SLATE_MAX) + " ignorée(s).");
    rows = rows.slice(0, SLATE_MAX);
    var body;
    if (p.state === "loading") body = [0, 1, 2].map(function (i) { return h("div", { key: i, className: "wf-sl-row", "aria-hidden": "true" }, h("span", { className: "wf-skel", style: { width: 130 - i * 18, height: 14 } }), h("span", { className: "wf-sl-dots" }), h("span", { className: "wf-skel", style: { width: 54, height: 20 } })); });
    else if (p.state === "error") body = [h("div", { key: "e", className: "wf-sl-msg", role: "alert" }, h("span", null, "Prix du jour indisponible."),
      p.onRetry ? h("button", { type: "button", className: "wf-sl-retry", onClick: p.onRetry }, "Réessayer") : null)];
    else if (!rows.length) body = [h("div", { key: "v", className: "wf-sl-msg" }, p.emptyText || "Pas encore de prix du jour dans votre zone.")];
    var footer = p.offline ? "Hors connexion · " + p.offline : p.footer;
    return h("div", { className: cx("wf-slate", p.className), "aria-busy": p.state === "loading" ? "true" : undefined },
      (p.title || p.meta) ? h("div", { className: "wf-sl-head" },
        p.title ? h("span", { className: "wf-sl-title" }, p.title) : null,
        p.meta ? h("span", { className: "wf-sl-m" }, p.meta) : null) : null,
      body || rows.map(function (r, i) {
        return h(r.onClick ? "button" : "div", { key: i, type: r.onClick ? "button" : undefined, onClick: r.onClick, className: cx("wf-sl-row", r.selected && "on") },
          h("span", null, r.label), h("span", { className: "wf-sl-dots", "aria-hidden": "true" }),
          r.missing ? h("span", { className: "wf-sl-miss" }, r.missing) : h("span", { className: "wf-sl-p" }, typeof r.value === "number" ? fmt(r.value) : r.value));
      }),
      footer && p.state !== "error" ? h("span", { className: "wf-sl-m", style: { marginTop: 4 } }, footer) : null);
  }

  /* Carte « Ma liste de la semaine » : total au mieux et économie possible. */
  function ListSummary(p) {
    if (p.state === "loading") return h("div", { className: cx("wf-list-summary", p.className), "aria-busy": "true", "aria-label": "Chargement de ma liste" },
      h("span", { className: "wf-skel", style: { width: 190, height: 16 } }), h("span", { className: "wf-skel", style: { width: 150, height: 26 } }));
    if (!p.count) return h("button", { type: "button", className: cx("wf-list-summary", p.className), onClick: p.onStart },
      h("span", { className: "subtitle" }, "Commencez votre liste de la semaine"),
      h("span", { className: "caption wf-muted" }, "Ajoutez vos produits : Comparo trouve la boutique la moins chère pour l'ensemble."));
    var save = p.save > 0 && !p.offline;
    return h("button", { type: "button", className: cx("wf-list-summary", p.className), onClick: p.onOpen,
        "aria-label": "Ma liste de la semaine, " + p.count + " articles, " + fmt(p.best) + " FCFA au mieux" + (save ? ", " + fmt(p.save) + " francs d'économie possible" : "") + (p.offline ? ", hors connexion" : "") },
      h("span", { className: "wf-ls-head" }, h("span", { className: "subtitle" }, "Ma liste de la semaine"), h("span", { className: "caption wf-muted" }, p.count + " articles")),
      h("span", { className: "wf-ls-total" }, h("span", { className: "wf-ls-big" }, fmt(p.best) + " FCFA"), h("span", { className: "caption wf-muted" }, "au mieux")),
      save ? h("span", { className: "wf-ls-save" }, h("span", { className: "wf-tag wf-tag-save label" }, "−" + fmt(p.save) + " F"), h("span", { className: "caption" }, "d'économie possible face à la boutique la plus chère"))
        : p.offline ? h("span", { className: "caption wf-muted" }, "Hors connexion · totaux du " + p.offline) : null);
  }

  window.Wf = Object.assign(window.Wf || {}, {
    Button: Button, SearchBar: SearchBar, TextField: TextField, Placeholder: Placeholder, PriceTag: PriceTag,
    FreshnessBadge: FreshnessBadge, TrustBadge: TrustBadge, AvailabilityChip: AvailabilityChip, OfferRow: OfferRow,
    ProductCard: ProductCard, Banner: Banner, Tabs: Tabs, AppBar: AppBar, BottomNav: BottomNav, EmptyState: EmptyState,
    Annotation: Annotation, Gauge: Gauge, PriceLine: PriceLine, ProofLine: ProofLine, Picto: Picto, Slate: Slate, ListSummary: ListSummary, formatXAF: fmt
  });
})();
