La corde à prix : signature de Comparo. Les offres actuelles d'un produit sont des étiquettes accrochées à une ficelle, placées selon leur prix ; la moins chère est citron, à gauche. On lit d'un regard l'écart et le nombre d'offres.

Props : `offers` (`{ price, vendor }[]`, offres actuelles uniquement), `size` (`sm` dans un résultat de recherche, `lg` sur la fiche produit), `onSelect` (ouvre la fiabilité de l'offre touchée).

- N'y mettez jamais un prix expiré ou épuisé : ils restent dans la section repliée.
- `sm` à partir de 2 offres ; avec une seule offre, n'affichez pas de corde.
- En `lg`, les étiquettes trop proches descendent d'un cran pour rester lisibles (3 rangs au plus).
- Toujours accompagnée du prix le plus bas en texte et de l'écart (« écart jusqu'à 650 F ») : la corde ne porte pas seule l'information.
- Accessibilité : avec `onSelect`, chaque étiquette est un bouton atteignable au clavier (Entrée ou Espace), avec un libellé « vendeur, prix, le moins cher ». L'anneau `focus` n'apparaît qu'à la navigation clavier.
- Écart connu : le nom du vendeur en `lg` fait 8,5px, sous le minimum de 11px (passe visuelle à venir).

<!-- contrat:begin — généré depuis contracts.json par tools/contracts.py, ne pas modifier à la main -->
## Contrat

**Statut** : actif. **Flutter** : PriceLine.

Corde à prix : les offres actuelles d'un produit pendent à une ficelle selon leur prix ; la moins chère en citron, à gauche.

**Props** : `offers` ({ price, vendor }[], offres actuelles), `size` (`sm` | `lg`), `onSelect` (offre touchée), `state` (`loading`), `offline` (bool)

| État | Comportement |
| --- | --- |
| Par défaut | Étiquettes placées selon le prix ; la moins chère en `price-best-bg`. |
| Chargement | Ficelle seule et trois étiquettes en squelette (`fill-100`), `aria-busy`. |
| Vide | 0 ou 1 offre : pas de corde ; l'écran affiche le prix seul ou l'état vide. |
| Erreur | — |
| Hors connexion | Même rendu, données du cache ; le libellé vocal ajoute « hors connexion ». |
| Désactivé | — |
| Sélectionné / focus | Étiquette ciblée au clavier : contour `focus` 3px. |

**Limites**

- 8 offres au plus : les 8 moins chères ; au-delà, mention « +N autres offres » sous la grande corde.
- Prix égaux ou proches : en grand, l'étiquette descend d'un rang (3 rangs) puis se décale vers la droite ; en petit, 16 unités d'écart minimum.
- Prix long (7 caractères et plus, ex. 125 000) : le chiffre est resserré pour tenir dans l'étiquette.
- Nom de vendeur : raccourci à 10 caractères + « … » ; le nom complet reste dans le libellé vocal.

**Accessibilité**

- Résumé vocal : « 4 offres de 4 950 à 5 600 FCFA ; la moins chère en citron ».
- Avec `onSelect`, chaque étiquette est un bouton (Tab, Entrée, Espace) annoncé « vendeur, prix, le moins cher ».
- La liste des offres sous la corde reste l'accès principal ; la corde ne porte jamais seule l'information.

**Tokens** : `corde-string`, `price-best-bg`, `price-best-fg`, `paper`, `ink`, `ink-muted`, `focus`, `fill-100`
<!-- contrat:end -->
