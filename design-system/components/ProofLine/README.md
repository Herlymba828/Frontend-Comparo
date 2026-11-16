Ligne de preuve : remplace la paire de badges fraîcheur + confiance dans les listes d'offres. Une pastille, l'âge du prix, la source et un verdict en un mot.

Props : `age` (« il y a 2 j », fourni par l'API), `source` (`vendor` | `field`), `level` (`high` → Fiable, `medium` → Plutôt fiable, `low` → À vérifier).

- Pastille pleine verte, demi-citron ou vide : le sens ne repose pas sur la couleur seule, le mot est toujours affiché.
- Le détail (jauges, source, disponibilité) reste sur l'écran Fiabilité, ouvert au toucher.

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : actif. **Flutter** : ProofLine.

Ligne de preuve : pastille, âge du prix, source et verdict en un mot. Remplace les badges fraîcheur + confiance dans les listes.

**Props** : `level` (`high` | `medium` | `low`, calculé par l'API), `age`, `source` (`vendor` | `field`), `offline` (bool), `state` (`loading`)

| État | Comportement |
| --- | --- |
| Par défaut | « Vu il y a 2 j · vendeur vérifié · Fiable ». |
| Chargement | Pastille et texte en squelette. |
| Vide | Âge absent : « Vu à une date inconnue ». |
| Erreur | — |
| Hors connexion | Âge calculé sur la date du cache, suivi de « · hors connexion ». |
| Désactivé | — |
| Sélectionné / focus | — |

**Limites**

- Texte sur 2 lignes au plus ; la pastille reste alignée sur la première.

**Accessibilité**

- Le mot du verdict est toujours écrit : pastille pleine, demi ou vide n'est jamais seule.

**Tokens** : `proof-high`, `proof-medium`, `proof-low`, `ink`, `ink-muted`, `on-primary`
<!-- contrat:end -->
