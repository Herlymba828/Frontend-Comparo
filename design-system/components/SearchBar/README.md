Champ de recherche produit en tête de l'accueil et de l'écran Recherche (PJ-001).

Props : `placeholder`, `value`, `voice` (affiche le micro pour la saisie vocale, P2).

- Toujours en haut de l'écran, sous la barre d'app.
- Une recherche imprécise mène à une liste de correspondances, jamais à un résultat unique forcé.

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : actif. **Flutter** : SearchBar thématisée.

Recherche produit en tête de l'accueil et de Recherche.

**Props** : `placeholder`, `value`, `voice`

| État | Comportement |
| --- | --- |
| Par défaut | Pilule `fill-100`. |
| Chargement | Suggestions en squelette sous le champ. *(à coder)* |
| Vide | Aucun résultat → écran « Aucun résultat » avec une issue. |
| Erreur | — |
| Hors connexion | Recherche dans le cache seulement ; mention sous le champ. *(à coder)* |
| Désactivé | — |
| Sélectionné / focus | Focus : fond `paper`, anneau `focus`. |

**Limites**

- Texte saisi sur une ligne, défilement horizontal.

**Accessibilité**

- Libellé vocal = placeholder ; micro annoncé « Recherche vocale ».

**Tokens** : `fill-100`, `paper`, `ink`, `ink-muted`, `focus`
<!-- contrat:end -->
