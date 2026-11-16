Bouton d'action : `primary` pour l'action unique de l'écran (Comparer, Publier le prix), `secondary` pour les alternatives, `ghost` pour les liens d'action.

Props : `variant` (`primary`|`secondary`|`ghost`), `size` (`md`|`sm`), `block`, `disabled`, `onClick`, `children` (le libellé, verbe à l'infinitif).

- Un seul `primary` par écran.
- Libellé court et explicite : « Comparer les prix », pas « OK ».
- Cible tactile ≥ 48px (déjà garantie en `md`).

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : actif. **Flutter** : FilledButton / OutlinedButton / TextButton thématisés.

Action : `primary` pour l'action unique de l'écran, `secondary`, `ghost`.

**Props** : `variant`, `size`, `block`, `disabled`, `onClick`

| État | Comportement |
| --- | --- |
| Par défaut | 48px de haut (`target-primary`). |
| Chargement | Libellé conservé, indicateur à droite, non cliquable. *(à coder)* |
| Vide | — |
| Erreur | — |
| Hors connexion | — |
| Désactivé | `fill-100`, texte `ink-muted`, non focalisable par la souris. |
| Sélectionné / focus | Focus clavier : anneau `focus` 2px décalé de 2px. |

**Limites**

- Une action principale par écran.
- Libellé à l'infinitif, sans point ; 2 lignes interdites : raccourcir.

**Accessibilité**

- Cible ≥ 48px (`target-min`, règle Android), comme le bouton principal.

**Tokens** : `primary`, `on-primary`, `paper`, `line`, `teal-ink`, `focus`
<!-- contrat:end -->
