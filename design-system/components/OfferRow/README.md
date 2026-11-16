Ligne d'offre de l'écran Comparer : vendeur, zone, distance, date, prix, fraîcheur, confiance et disponibilité (PJ-002).

Props : `vendor`, `zone`, `distance`, `date`, `amount`, `unitPrice`, `unit`, `priceType`, `freshness`, `age`, `trust` (`high`|`medium`|`low`), `availability`, `best` (bordure verte + étiquette citron « Meilleur prix »), `sponsored`.

- Seules les offres strictement comparables vont dans la liste ; les substituts vont dans une section séparée.
- `best` revient à l'offre la moins chère non expirée ; jamais à une offre sponsorisée par défaut (PJ-PR-002).
- Une offre sponsorisée porte toujours l'étiquette « Sponsorisé ».

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : déprécié → ligne d'offre avec ProofLine (Flutter : OfferTile). **Flutter** : OfferTile.

Ligne d'offre : vendeur, prix, preuve, disponibilité.

**Props** : `vendor`, `zone`, `amount`, `unitPrice`, `freshness`, `trust`, `availability`, `best`, `sponsored`

| État | Comportement |
| --- | --- |
| Par défaut | Vendeur et preuve à gauche, prix et écart à droite. |
| Chargement | Ligne en squelette. *(à coder)* |
| Vide | — |
| Erreur | — |
| Hors connexion | Données du cache. |
| Désactivé | Offre épuisée : déplacée dans la section repliée, jamais désactivée sur place. |
| Sélectionné / focus | — |

**Limites**

- Nom de vendeur sur 2 lignes au plus.
- Expirées et épuisées : section repliée en bas, jamais « meilleur prix ».

**Accessibilité**

- Bouton « Ajouter » de 48 px annoncé « Ajouter <vendeur> à ma liste ».

**Tokens** : `paper`, `line-soft`, `ink`, `ink-muted`, `price-best-bg`
<!-- contrat:end -->
