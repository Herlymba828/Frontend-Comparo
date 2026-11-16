Picto produit : un dessin plat par famille, sur une vignette `fill-100`, avec le repère de marque (initiale sur pastille `brand-mark-1…5`, choisie à partir de l'initiale).

Props : `kind` (`riz`, `huile`, `sucre`, `lait`, `sardine`, `eau`, `savon`, `conserve`), `brand` (« Marque A »), `size` (`md` 48px dans les listes, `lg` 56px dans les résultats).

- Jamais de photo grise ni de lettre à la place du picto ; une famille inconnue prend le sac générique.
- Le repère de marque distingue deux produits voisins ; il n'est pas un logo.
- Écart connu : initiale blanche peu contrastée sur `brand-mark-1` et `-2` en thème sombre.

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : actif. **Flutter** : ProductPicto.

Picto produit plat sur vignette, avec repère de marque (initiale sur pastille).

**Props** : `kind` (8 familles), `brand`, `size` (`md` 48 | `lg` 56)

| État | Comportement |
| --- | --- |
| Par défaut | Picto de la famille. |
| Chargement | Vignette `fill-100` seule. |
| Vide | Famille inconnue : sac générique. |
| Erreur | — |
| Hors connexion | — |
| Désactivé | — |
| Sélectionné / focus | — |

**Limites**

- Initiale de marque sur 1 caractère.
- Jamais de photo grise ni de lettre à la place du picto.

**Accessibilité**

- Picto décoratif (masqué) ; la marque est lue avec le nom du produit.

**Tokens** : `fill-100`, `illu-lemon`, `illu-teal`, `illu-green`, `illu-soft`, `illu-paper`, `illu-shade`, `illu-line`, `brand-mark-1…5`, `on-brand-mark`
<!-- contrat:end -->
