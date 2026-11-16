Indication de disponibilité du produit chez un vendeur : Disponible, Stock limité, Épuisé, Inconnue (API : `available`, `limited`, `unavailable`, `unknown`).

Props : `status` (`in`|`low`|`out`|`unknown`).

- Un prix connu n'implique pas la disponibilité : sans donnée, affichez `unknown`, n'inventez rien (RC-003).

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : actif. **Flutter** : à créer (texte + glyphe).

Disponibilité chez un vendeur.

**Props** : `status` (`in` | `low` | `out` | `unknown`)

| État | Comportement |
| --- | --- |
| Par défaut | Disponible / Stock limité / Épuisé / Dispo. inconnue. |
| Chargement | — |
| Vide | « Dispo. inconnue ». |
| Erreur | — |
| Hors connexion | — |
| Désactivé | — |
| Sélectionné / focus | — |

**Limites**

- Épuisé : l'offre part dans la section repliée.

**Accessibilité**

- Glyphe + mot.

**Tokens** : `primary`, `ink`, `ink-muted`
<!-- contrat:end -->
