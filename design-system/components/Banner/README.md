Bandeau d'état : hors ligne (pointillé), information, avertissement, succès.

Props : `tone` (`offline`|`info`|`warning`|`success`), `title`, `children`, `action` + `onAction`.

- Hors ligne : rappelez l'âge des données et bloquez les opérations serveur (PJ-027, RC-006).
- Avertissement avant validation d'un panier dont un prix a changé (PJ-009).

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : actif. **Flutter** : MaterialBanner thématisé.

Bandeau d'état : hors ligne, information, avertissement, succès.

**Props** : `tone`, `title`, `children`, `action`, `onAction`

| État | Comportement |
| --- | --- |
| Par défaut | Glyphe, titre, texte, action facultative. |
| Chargement | — |
| Vide | — |
| Erreur | — |
| Hors connexion | Ton `offline` : pointillé, date des données en cache. |
| Désactivé | — |
| Sélectionné / focus | — |

**Limites**

- Un bandeau à la fois en tête d'écran.

**Accessibilité**

- `role=alert` pour l'avertissement, `status` sinon.

**Tokens** : `warning-bg`, `warning-fg`, `primary-soft`, `fill-100`, `line`
<!-- contrat:end -->
