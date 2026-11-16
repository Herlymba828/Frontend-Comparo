Badge de fraîcheur d'un prix : Récent (plein), Ancien (contour), Expiré ou Date inconnue (pointillé).

Props : `level` (`fresh`|`old`|`expired`|`unknown`), `age` (« 2 j », « 3 sem. »).

- Présent sur chaque offre et sur toute donnée hors ligne (PJ-027).
- Le niveau se lit au mot et au style de bordure, pas à la teinte.

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : déprécié dans les listes → ProofLine ; conservé sur l'écran Fiabilité. **Flutter** : —.

Badge de fraîcheur : Récent, Ancien, Expiré, Date inconnue.

**Props** : `level`, `age`

| État | Comportement |
| --- | --- |
| Par défaut | Plein, contour ou pointillé selon le niveau. |
| Chargement | — |
| Vide | « Date inconnue », pointillé. |
| Erreur | — |
| Hors connexion | — |
| Désactivé | — |
| Sélectionné / focus | — |

**Limites**

- Un mot toujours écrit.

**Accessibilité**

- Le sens ne repose pas sur la couleur.

**Tokens** : `primary-soft`, `line`, `ink-muted`
<!-- contrat:end -->
