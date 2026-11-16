Badge du niveau de confiance d'une offre en 3 niveaux (élevée, moyenne, faible) ; cliquable, il ouvre l'écran Fiabilité (PJ-003).

Props : `level` (`high`|`medium`|`low` ; anciens noms `verified`/`partial`/`unverified` acceptés), `source` (« Marchand », « Relevé terrain »), `onClick` (le rend bouton avec chevron).

- Élevée = fond `primary-soft` ✓, moyenne = fond `accent` ◐, faible = contour !. Le niveau se lit au mot, jamais à la couleur seule.
- Le niveau vient de l'API (mapping et seuils à créer côté serveur) ; jamais calculé dans l'app.

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : déprécié dans les listes → ProofLine ; conservé sur l'écran Fiabilité. **Flutter** : —.

Badge de confiance en 3 niveaux ; cliquable vers Fiabilité.

**Props** : `level`, `source`, `onClick`

| État | Comportement |
| --- | --- |
| Par défaut | Élevée (plein), moyenne (citron), faible (contour). |
| Chargement | — |
| Vide | — |
| Erreur | — |
| Hors connexion | — |
| Désactivé | Non cliquable sans `onClick`. |
| Sélectionné / focus | — |

**Limites**

- —

**Accessibilité**

- Glyphe + mot.

**Tokens** : `primary-soft`, `proof-medium`, `line`
<!-- contrat:end -->
