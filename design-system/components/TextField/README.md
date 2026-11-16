Champ de formulaire étiqueté, utilisé pour la publication d'un prix (PJ-016) et l'observation terrain (PJ-019).

Props : `label` (obligatoire), `placeholder`, `value`, `suffix` (unité ou devise : `FCFA`, `kg`), `hint`, `error`, `inputMode`.

- Le libellé est toujours visible au-dessus du champ, jamais seulement en placeholder.
- L'erreur s'affiche en texte avec le signe ⚠ et une bordure renforcée : pas de couleur seule.

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : actif. **Flutter** : TextField thématisé.

Champ de formulaire étiqueté.

**Props** : `label`, `placeholder`, `value`, `suffix`, `hint`, `error`, `inputMode`

| État | Comportement |
| --- | --- |
| Par défaut | Bordure `line`, 48px. |
| Chargement | — |
| Vide | — |
| Erreur | Bordure 2px `danger` + message précédé de « ⚠ ». |
| Hors connexion | — |
| Désactivé | Fond `fill-100`, texte `ink-muted`. *(à coder)* |
| Sélectionné / focus | Anneau `focus`. |

**Limites**

- Message d'erreur sur 2 lignes au plus.

**Accessibilité**

- Étiquette liée au champ ; `aria-invalid` en erreur.

**Tokens** : `paper`, `line`, `danger`, `focus`, `ink-muted`
<!-- contrat:end -->
