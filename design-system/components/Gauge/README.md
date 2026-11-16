Jauge à 3 niveaux pour la fraîcheur et la confiance d'un prix, avec sa phrase d'explication (écran Fiabilité, PJ-003).

Props : `kind` (`freshness`|`trust`), `level` (fraîcheur : `fresh`|`old`|`expired` ; confiance : `high`|`medium`|`low`), `label`, `children` (la phrase d'explication fournie par l'API).

- Niveau 3 en `primary`, 2 en `accent`, 1 en `ink-muted` ; le mot du niveau est toujours affiché.
- Sans explication de l'API, n'inventez pas de texte : laissez `children` vide.

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : actif. **Flutter** : à créer.

Jauge à 3 niveaux de fraîcheur ou de confiance, écran Fiabilité.

**Props** : `kind`, `level`, `label`, `children`

| État | Comportement |
| --- | --- |
| Par défaut | Niveau 3 `proof-high`, 2 `proof-medium`, 1 `ink-muted`. |
| Chargement | — |
| Vide | « Inconnue », 0 segment. |
| Erreur | — |
| Hors connexion | — |
| Désactivé | — |
| Sélectionné / focus | — |

**Limites**

- Explication fournie par l'API ; sinon rien.

**Accessibilité**

- `role=img` : « Moyenne, niveau 2 sur 3 ».

**Tokens** : `proof-high`, `proof-medium`, `fill-200`
<!-- contrat:end -->
