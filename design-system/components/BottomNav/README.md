Navigation principale à 5 destinations du consommateur.

Props : `items` (défaut Accueil, Recherche, Alertes, Panier, Profil), `value` (index actif).

- Panier et Alertes sont P1 : retirez-les de la maquette MVP si besoin.

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : actif. **Flutter** : ComparoNavigationBar.

Navigation principale : Accueil, Recherche, Ma liste, Profil.

**Props** : `items`, `value`

| État | Comportement |
| --- | --- |
| Par défaut | Icône + libellé `ink-muted`. |
| Chargement | — |
| Vide | — |
| Erreur | — |
| Hors connexion | Inchangée. |
| Désactivé | — |
| Sélectionné / focus | Couleur `primary` + mini-étiquette `nav-indicator`. |

**Limites**

- 4 onglets ; le défaut à 5 onglets (« Alertes », « Panier ») est déprécié.
- Compteur : 99+ au-delà de 99.

**Accessibilité**

- `aria-current=page` ; compteur lu « 5 articles ».

**Tokens** : `paper`, `line-soft`, `primary`, `nav-indicator`, `badge-count-bg`, `badge-count-fg`

**À coder** : limite : 99+
<!-- contrat:end -->
