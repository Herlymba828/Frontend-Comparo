# Contrat API frontend — brouillon vérifié dans le code

**État :** contrat frontend dérivé des routes, vues et serializers Django
présents, avec couverture API ciblée ajoutée pour le catalogue, les
observations, les offres, les disponibilités et l’enveloppe 404. Il décrit le
comportement observé du backend courant ; toute évolution doit maintenir ces
tests ou mettre à jour explicitement le contrat.

**Base locale observée :** `http://127.0.0.1:8010` depuis l’hôte. Depuis
l’émulateur Android, utiliser `http://10.0.2.2:8010`. La production doit
utiliser HTTPS. Les URLs doivent être configurables, pas codées dans les
widgets.

## Règles communes

- Les routes sont actuellement sous `/api/`; aucun préfixe `/api/v1/` n’est
  déclaré dans `backend/config/urls.py`.
- DRF renvoie les collections paginées sous la forme
  `{"count": int, "next": string|null, "previous": string|null, "results": []}`.
  `page_size` vaut 20 par défaut et peut aller jusqu’à 100; `page` sélectionne
  la page.
- Les montants `Decimal` doivent être désérialisés sans perte de précision.
  Les champs date/heure sont des chaînes ISO 8601 avec fuseau selon la
  configuration Django.
- Le gestionnaire d’exception DRF renvoie normalement
  `{"error":{"code":string,"detail":string,"fields":object|null},"request_id":string}`.
  Une erreur de validation place les détails par champ dans `error.fields`;
  une erreur serveur non gérée renvoie `internal_error` et un message générique.
- Les lectures publiques ci-dessous déclarent explicitement `AllowAny`.
  L’authentification globale utilise JWT, mais aucune authentification n’est
  requise pour ces routes de lecture. Les écritures sont hors du périmètre
  consommateur décrit ici.

## Routes retenues pour étude frontend

### Catalogue de produits

| Méthode et chemin | Accès | Requête et comportement |
|---|---|---|
| `GET /api/catalog/products/` | Public | Pagination. Filtres `category` et `brand` par slug, `q` (nom, SKU, code-barres ou description), `search` (filtre DRF, qui inclut aussi marque et catégorie), `available=true|1|yes`, `verified=true|1|yes`, `ordering=name|price_snapshot|created_at` avec préfixe `-` pour décroissant. Les produits inactifs sont exclus. |
| `GET /api/catalog/products/{id}/` | Public | Détail d’un produit actif. Le queryset applique aussi les filtres reçus dans la query string. |

Les filtres `available` et `verified` ne filtrent que si une valeur vraie est
envoyée. Une valeur false n’active pas un filtre sur les produits indisponibles
ou non vérifiés.

**Champs de liste** (`ProductListSerializer`) : `id`, `name`, `slug`, `sku`,
`barcode`, `category` (`id`, `name`, `slug`), `brand` (`id`, `name`, `slug`,
`logo_url`), `default_unit` (`id`, `code`, `symbol`, `unit_type`), `image_url`,
`price_snapshot`, `price_snapshot_currency`, `price_snapshot_updated_at`,
`availability`, `is_active`, `is_verified`.

**Champs de détail** (`ProductDetailSerializer`) : identité et champs de
recherche ci-dessus, objets détaillés `category`, `brand`, `default_unit`,
`default_format`, `description`, image et instantané de prix, disponibilité,
statuts, `created_by`, `created_at`, `updated_at`. Les champs d’écriture
`category_id`, `brand_id`, `default_unit_id`, `default_format_id` ne font pas
partie de la réponse de lecture.

### Catégories

| Méthode et chemin | Accès | Requête et comportement |
|---|---|---|
| `GET /api/catalog/categories/tree/` | Public | Arbre récursif des catégories actives racines; réponse JSON tableau non paginé. |
| `GET /api/catalog/categories/` | Public | Liste paginée; filtres `active=true|1|yes`, `parent=null|{id}`, recherche DRF `search`, tri `ordering=name|sort_order`. |

Le nœud de l’arbre contient `id`, `name`, `slug`, `icon_url`, `sort_order`,
`is_active`, `children`. Ne pas supposer que la route `tree/` utilise
l’enveloppe paginée.

### Offres

| Méthode et chemin | Accès | Requête et comportement |
|---|---|---|
| `GET /api/pricing/offers/` | Public | Offres actives, pagination; filtres `product={id}`, `merchant={id}`; tri `ordering=valid_from|valid_to|published_at` et préfixe `-`. |
| `GET /api/pricing/offers/{id}/` | Public | Détail d’offre active. |

La liste (`PriceOfferListSerializer`) expose `id`, `product`, `merchant`
(identifiants), `amount`, `currency`, `freshness`, `valid_from`, `valid_to`,
`is_active`, `promotion_label`, `min_quantity`, `published_at`,
`is_currently_valid`. Elle ne donne pas le nom du marchand, le lieu, la
quantité/unité du prix, ni la date d’observation. Le détail imbrique `price`
et fournit plus de contexte, mais n’est pas un endpoint de comparaison
collective.

### Observations de prix

| Méthode et chemin | Accès | Requête et comportement |
|---|---|---|
| `GET /api/pricing/observations/` | Public | Observations publiées, pagination; filtres `product={id}`, `merchant={id}`, `status={status}`, `freshness={freshness}`; tri `ordering=amount|observed_at|published_at|freshness` et préfixe `-`. |
| `GET /api/pricing/observations/{id}/` | Public | Détail public d’une observation publiée. |

La liste (`PriceListSerializer`) expose `id`, `product`, `product_name`,
`amount`, `currency`, `quantity`, `unit_symbol`, `unit_code`, `location`,
`freshness`, `verification_score`, `confidence`, `availability`, `price_type`,
`status`, `is_promotion`, `observed_at`, `published_at`. `merchant` n’est
présent que comme identifiant, sans nom. Le champ `format` et son détail ne
sont pas inclus dans la liste.

### Disponibilité

| Méthode et chemin | Accès | Requête et comportement |
|---|---|---|
| `GET /api/availability/` | Public | Liste paginée; filtres `product={id}`, `merchant={id}`, `status={status}`, `location={id}`; tri `ordering=updated_at|observed_at|status`, défaut `-updated_at`. |
| `GET /api/availability/{id}/` | Public | Détail, y compris les événements imbriqués selon le serializer. |

La liste (`AvailabilityListSerializer`) expose `id`, `product`, `product_name`,
`merchant`, `merchant_name`, `location`, `status`, `is_available`,
`quantity_available`, `observed_at`, `updated_at`. Elle ne comprend ni le nom
de localisation, ni l’unité de quantité.

### Sessions de comparaison existantes

`GET /api/comparison/sessions/?product={id}` est **authentifié** et renvoie les
sessions appartenant à l’utilisateur courant (ou toutes pour un administrateur).
Le serializer inclut `id`, `session_id`, `product`, `user`, `query_location`,
`query_filters`, `result_count`, `created_at` et `results`. Ce endpoint liste
des sessions déjà créées; il ne fournit pas une comparaison publique à la
demande et ne convient pas au parcours consommateur anonyme.

### Offres publiques d’un produit pour comparaison

| Méthode et chemin | Accès | Requête et comportement |
|---|---|---|
| `GET /api/comparison/products/{product_id}/offers/` | Public | Offres actuellement valides du produit actif et de ses équivalences strictes directes ; pagination commune (`page`, `page_size`), tri stable par date d’observation décroissante. Le filtre optionnel `location` effectue une recherche partielle insensible à la casse. |

Chaque résultat expose `id`, `product`, `product_name`, `merchant`,
`merchant_name`, `amount`, `currency`, `quantity`, `unit_symbol`, `unit_code`,
`format` (détail ou `null`), `location`, `availability`, `freshness`,
`verification_score`, `verification_level`, `observed_at`,
`price_published_at`, `source_label`, `valid_from`, `valid_to`, `is_active`,
`is_promotion`, `discount_amount`, `discount_percent`, `conditions`,
`promotion_label`, `promotion_details`, `min_quantity`, `published_at`,
`is_currently_valid`, `product_equivalence`, `normalized_unit_price`,
`normalized_unit`, `comparison_group` et `comparison_reasons`. Les montants,
quantités et prix unitaires normalisés sont sérialisés en chaînes décimales.
Les prix liés doivent correspondre au produit de l’offre, être publiés et
exposés ; le marchand du prix et celui de l’offre doivent correspondre. Une
offre doit être active et dans sa période de validité.

Seul le produit demandé et ses liens directs `ProductEquivalence` avec
`is_strict=true` sont inclus ; les liens `substitute` sont exclus même si leur
indicateur strict est incohérent. Les liens ne sont pas suivis en chaîne. Un
produit lié doit lui aussi être actif. Le champ `product_equivalence` vaut
`null` pour le produit demandé et contient `{id, match_kind, is_strict}` pour
un produit lié.

Le backend normalise `amount / (quantity × factor)` vers l’unité `is_base` de
même type, en utilisant uniquement une conversion directe `Equivalence`
marquée `is_exact=true`. Une unité déjà de base utilise le facteur 1. Aucun
facteur inverse ou chemin composé n’est inféré. Le résultat est arrondi à six
décimales. Si la conversion manque, est ambiguë ou si la quantité n’est pas
positive, `normalized_unit_price`, `normalized_unit` et `comparison_group`
valent `null`; `comparison_reasons` indique respectivement
`no_exact_conversion_to_base_unit`, `ambiguous_base_unit_for_unit_type`,
`no_base_unit_for_unit_type`, `invalid_conversion_factor` ou
`non_positive_quantity`.

`comparison_group` identifie la devise et l’unité normalisée. Les offres de
devises différentes ne doivent pas être classées ensemble : aucun taux de
change n’est disponible. Les promotions restent visibles avec leurs conditions
et leur quantité minimale ; cet endpoint ne renvoie ni rang ni « meilleure
offre ». L’interface ne doit pas prétendre qu’une promotion est applicable
tant que ses conditions ne sont pas établies.

La localisation reste un champ texte libre du prix ; `?location=` filtre par
sous-chaîne, et ne représente pas encore une zone géographique structurée.

Exemple de résultat de liste (identifiants et dates illustratifs) :

```json
{
  "count": 1,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 12,
      "product": 7,
      "product_name": "Riz local",
      "merchant": 3,
      "merchant_name": "Marché central",
      "amount": "6250.00",
      "currency": "XAF",
      "quantity": "5.0000",
      "unit_symbol": "kg",
      "unit_code": "kg",
      "format": {
        "id": 2,
        "name": "Sac 5 kg",
        "quantity": "5.0000",
        "unit": {"id": 1, "code": "kg", "symbol": "kg", "unit_type": "mass"},
        "display_quantity": "5 kg",
        "description": "",
        "created_at": "2025-01-01T09:00:00Z",
        "updated_at": "2025-01-01T09:00:00Z"
      },
      "location": "Libreville",
      "availability": "available",
      "freshness": "recent",
      "verification_score": "0.8500",
      "verification_level": "manual",
      "observed_at": "2025-01-01T09:00:00Z",
      "price_published_at": "2025-01-01T10:00:00Z",
      "source_label": "Observation terrain",
      "is_promotion": false,
      "discount_amount": null,
      "discount_percent": null,
      "conditions": "",
      "valid_from": "2024-12-31T09:00:00Z",
      "valid_to": "2025-01-02T09:00:00Z",
      "is_active": true,
      "promotion_label": "",
      "promotion_details": "",
      "min_quantity": null,
      "published_at": "2025-01-01T10:00:00Z",
      "is_currently_valid": true,
      "product_equivalence": null,
      "normalized_unit_price": "1250.000000",
      "normalized_unit": {
        "id": 1,
        "code": "kg",
        "symbol": "kg",
        "unit_type": "mass"
      },
      "comparison_group": {"currency": "XAF", "unit_code": "kg"},
      "comparison_reasons": []
    }
  ]
}
```

**Exemples de décision :** deux offres du même produit ou reliées par une
équivalence stricte explicite et non substitutive peuvent être regroupées.
Une offre en grammes ne reçoit un prix/kg normalisé que si une conversion
exacte directe vers l’unité de base existe. Un produit sans lien strict, un
substitut, une conversion approximative, une unité sans base ou une devise
différente ne reçoit pas de classement commun. Les offres de lieux distincts
restent visibles avec leur lieu ; une promotion reste affichée avec ses
conditions sans être présentée comme le prix le plus avantageux applicable.

## Formes de réponse vérifiées

La suite de contrats confirme l’enveloppe paginée et les champs suivants.
Les identifiants et horodatages ci-dessous sont illustratifs :

```json
{
  "count": 1,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 12,
      "name": "Riz local",
      "slug": "riz-local",
      "sku": "",
      "barcode": "",
      "category": {"id": 3, "name": "Épicerie", "slug": "epicerie"},
      "brand": null,
      "default_unit": null,
      "image_url": "",
      "price_snapshot": "1250.00",
      "price_snapshot_currency": "XAF",
      "price_snapshot_updated_at": null,
      "availability": "unknown",
      "is_active": true,
      "is_verified": true
    }
  ]
}
```

L’accès anonyme et l’inclusion des seules observations publiées, offres
actives et champs listés sont testés dans `backend/apps/catalog/tests.py`,
`backend/apps/pricing/tests.py`, `backend/apps/availability/tests.py` et
`backend/apps/comparison/tests.py`. Les règles d’équivalence stricte, de
normalisation exacte, de séparation des devises, de filtre par lieu et
d’affichage des promotions sont couvertes dans le test de comparaison. Le
gestionnaire d’erreurs est vérifié sur un 404 :

```json
{
  "error": {
    "code": "error",
    "detail": "<message renvoyé par l’exception>",
    "fields": null
  },
  "request_id": "<identifiant de corrélation>"
}
```

Les messages d’erreur sont localisés/propres à l’exception ; les clients
doivent se baser sur `error.code` et `error.fields`, et non sur le texte
`detail`.

## Écarts, limites et conditions d’usage

- Les routes `/api/v1/products/`, `/api/v1/stores/` et `/api/v1/auth/...`
  mentionnées comme exemples dans l’ancien document d’intégration ne sont pas
  les routes déclarées dans le backend courant.
- La couverture actuelle verrouille les parcours de lecture publique et les
  formes de réponse listées ci-dessus ; les autres routes et les erreurs de
  validation restent décrites à partir des vues/serializers et ne sont pas
  encore garanties par des tests de contrat dédiés.
- Le test 404 observe actuellement `error.code = "error"` (et non un code
  spécifique `not_found`) ; le frontend ne doit pas supposer une taxonomie
  d’erreurs plus précise tant que le backend ne l’a pas définie.
- Une comparaison complète requiert une réponse publique qui associe chaque
  prix à son marchand, son format/quantité/unité, sa localisation, sa
  disponibilité et ses dates/fraîcheur, et des règles serveur d’équivalence.
  Les listes courantes d’offres et d’observations n’apportent pas seules tout
  ce contexte. Le contrat P0.3/P0.4 est implémenté pour le même produit et ses
  équivalences strictes directes ; il ne calcule pas de classement organique et
  ne convertit pas les devises.
- Ne pas interpréter `price_snapshot` comme une observation contextualisée ni
  comme preuve d’équivalence; ce champ est un instantané de catalogue. Le
  backend le recalcule comme le prix admissible le plus bas (publié, exposé,
  non expiré) dans `price_snapshot_currency` : il peut monter ou devenir `null`.
- Alertes (`/api/alerts/`) : `threshold_amount` ≥ 0,01 avec au plus 2 décimales
  (12 chiffres), `threshold_currency` en 3 lettres, `notify_channels` parmi
  `in_app`, `push`, `sms`, `email`. Une alerte identique déjà active ou en
  pause renvoie 400 avec `detail`. Les alertes de prix ne considèrent que les
  prix admissibles dans la devise du seuil.
