Carte « Ma liste de la semaine » de l'accueil : total au mieux de la liste et économie possible face à la boutique la plus chère.

Props : `count`, `best`, `save`, `onOpen`, `onStart`, `state` (`loading`), `offline` (date du cache).

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : actif. **Flutter** : ListSummary.

Carte « Ma liste de la semaine » de l'accueil : total au mieux et économie possible.

**Props** : `count`, `best`, `save`, `onOpen`, `state` (`loading`), `onStart`

| État | Comportement |
| --- | --- |
| Par défaut | Total au mieux + étiquette d'économie. |
| Chargement | Squelette du total. |
| Vide | « Commencez votre liste de la semaine » + phrase d'aide. |
| Erreur | — |
| Hors connexion | Totaux du cache, sans étiquette d'économie (non garantie). |
| Désactivé | — |
| Sélectionné / focus | — |

**Limites**

- Aucune boutique n'a toute la liste : le total au mieux est celui du découpage en arrêts.
- Économie nulle : pas d'étiquette.

**Accessibilité**

- Carte entière cliquable, annoncée « Ma liste de la semaine, 5 articles, 13 950 FCFA au mieux ».

**Tokens** : `highlight-ring`, `save-bg`, `save-fg`, `paper`, `ink`, `ink-muted`
<!-- contrat:end -->
