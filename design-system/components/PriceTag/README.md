Affichage d'un prix en FCFA (XAF) avec son type et son prix à l'unité ; un prix expiré est barré et annoncé comme non actuel (RC-001).

Props : `amount`, `currency` (défaut `FCFA`), `unitPrice` + `unit`, `priceType` (`promo`|`wholesale`|`observed`), `wasAmount` (ancien prix promo), `freshness` (`expired` barre le prix), `size` (`md`|`lg`), `variant` (`tag` : l'étiquette citron, réservée au meilleur prix).

- Ne jamais afficher un prix seul : posez-le dans une `OfferRow` ou une `ProductCard` avec vendeur, zone et date (PJ-PR-001).
- Séparateur de milliers : espace fine, jamais de point.

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : actif. **Flutter** : PriceTag.

Prix en FCFA. `variant="tag"` : l'étiquette du meilleur prix, une seule par produit.

**Props** : `amount`, `currency`, `unitPrice`, `unit`, `priceType`, `wasAmount`, `freshness`, `size` (`md` | `lg`), `variant` (`tag`)

| État | Comportement |
| --- | --- |
| Par défaut | Montant, devise, prix à l'unité. |
| Chargement | — |
| Vide | Montant absent : « — », jamais 0. |
| Erreur | — |
| Hors connexion | Montant du cache ; la date est portée par la ligne de preuve. |
| Désactivé | — |
| Sélectionné / focus | — |

**Limites**

- Montant sans décimales, milliers séparés par une espace fine insécable.
- Prix expiré : barré + « Prix expiré — non actuel », jamais en étiquette citron.

**Accessibilité**

- Étiquette citron annoncée « Meilleur prix : 4 950 FCFA ».

**Tokens** : `price-best-bg`, `price-best-fg`, `ink`, `ink-muted`
<!-- contrat:end -->
