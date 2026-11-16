Onglets segmentés de la fiche produit : Comparer, Historique, Tendance.

Props : `items` (libellés), `value` (index actif), `onChange(i)`.

- 2 à 4 onglets, libellés d'un mot.

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : actif. **Flutter** : SegmentedButton thématisé.

Onglets segmentés de la fiche : Moins chères, Historique, Alerte.

**Props** : `items`, `value`, `onChange`

| État | Comportement |
| --- | --- |
| Par défaut | Pilule `fill-100`. |
| Chargement | — |
| Vide | — |
| Erreur | — |
| Hors connexion | — |
| Désactivé | Onglet P1 grisé. *(à coder)* |
| Sélectionné / focus | Onglet `paper` + ombre `shadow-1`. |

**Limites**

- 3 onglets au plus ; libellés d'un ou deux mots.

**Accessibilité**

- `role=tablist`, `aria-selected`.

**Tokens** : `fill-100`, `paper`, `ink`, `ink-muted`
<!-- contrat:end -->
