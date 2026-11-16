Bloc gris barré d'une croix qui réserve la place d'une image, d'un graphique ou d'une carte.

Props : `width`, `height`, `label` (ce que le bloc représentera).

- Nommez toujours le contenu attendu via `label` (« Photo produit », « Graphique 30 jours »).

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : maquette seulement. **Flutter** : —.

Bloc barré réservant la place d'une image en maquette.

**Props** : `width`, `height`, `label`

| État | Comportement |
| --- | --- |
| Par défaut | Bloc `fill-100` barré. |
| Chargement | — |
| Vide | — |
| Erreur | — |
| Hors connexion | — |
| Désactivé | — |
| Sélectionné / focus | — |

**Limites**

- N'apparaît pas dans l'app : remplacé par Picto ou un squelette.

**Accessibilité**

- Rôle image avec libellé.

**Tokens** : `fill-100`, `fill-200`, `note`
<!-- contrat:end -->
