Ardoise du marché : panneau `slate` à lignes « produit ........ prix ». Prix du jour sur l'accueil, Ma liste boutique par boutique, tableau du marchand.

Props : `title`, `meta` (zone, source), `rows` (`{ label, value, missing?, selected?, onClick? }`), `footer` (unité, date de mise à jour).

- 5 lignes au plus ; une ligne cliquable devient un bouton.
- `selected` ajoute une coche citron ; `missing` remplace le prix (« manque 1 »).
- Toujours la date de mise à jour en pied.

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : actif. **Flutter** : MarketSlate.

Ardoise du marché : lignes « produit ........ prix ». Prix du jour, Ma liste par boutique, tableau du marchand.

**Props** : `title`, `meta`, `rows` ({ label, value, missing, selected, onClick }[]), `footer`, `state` (`loading` | `error`), `onRetry`, `emptyText`, `offline` (date du cache)

| État | Comportement |
| --- | --- |
| Par défaut | Jusqu'à 5 lignes, date de mise à jour en pied. |
| Chargement | 3 lignes en squelette sur l'ardoise. |
| Vide | « Pas encore de prix du jour dans votre zone. » |
| Erreur | « Prix du jour indisponible. » + bouton « Réessayer » (`link-on-dark`). |
| Hors connexion | Dernière ardoise du cache ; pied « Hors connexion · prix du 3 nov., 18:40 ». |
| Désactivé | — |
| Sélectionné / focus | Ligne choisie : coche `slate-highlight`. |

**Limites**

- 5 lignes au plus : les suivantes ne sont pas affichées (avertissement en développement).
- Libellé long : coupé avec « … » ; le prix n'est jamais coupé.

**Accessibilité**

- Chaque ligne est lue « produit, prix » ; une ligne cliquable est un bouton de 48 px au moins.

**Tokens** : `slate`, `on-slate`, `slate-muted`, `slate-highlight`, `link-on-dark`
<!-- contrat:end -->
