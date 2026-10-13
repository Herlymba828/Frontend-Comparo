# Plan de travail — Frontend mobile Flutter

**Périmètre retenu :** MVP consommateur — accueil, recherche et filtres,
fiche produit, comparaison des offres et lecture hors ligne du cache.

**Cible de livraison :** Android en premier. Le projet reste Flutter et peut
conserver la cible iOS, mais aucun artefact ni aucune recette iOS ne bloque
la livraison Android ; ceux-ci nécessitent une étape distincte sur macOS/Xcode.

**État du projet :** le projet Flutter est structuré dans ce dossier et son
code initial a été poussé sur `Herlymba828/Frontend-Comparo`. L’application
dispose d’un démarrage Riverpod, d’un thème, du routage accueil/recherche/fiche,
d’un client HTTP configurable et d’une recherche catalogue connectée au
contrat Django. La recherche et ses modèles sont le premier incrément métier ;
pagination UI, fiche vivante, comparaison et cache hors ligne restent à faire.
Flutter 3.47.7/Dart 3.13.5, Chrome et les outils Android sont disponibles.
Après installation des Android SDK Command-line Tools et du NDK 28.2.13676358,
`flutter analyze`, `flutter test` et `flutter build apk --debug` passent.
`flutter doctor` conserve un avertissement parce que le chemin du SDK contient
un espace ; le build debug confirme que ce chemin n’empêche pas la construction
actuelle.
Les cinq spécifications version 0.1 restent des documents de travail « à
valider » ; ce plan organise leur réalisation sans valider implicitement les
choix encore ouverts.

**Statut de traçabilité :** il s’agit d’un plan de travail préliminaire fondé
sur les documents disponibles, et non d’un plan d’implémentation formel dérivé
d’une spécification de fonctionnalités approuvée. Aucun catalogue formel
`REQ-XXX`, fichier de constitution ni lot d’artefacts de conception formels
n’était disponible ; les identifiants P0–P6 désignent donc les phases/items de
ce plan, pas des exigences inventées. La correspondance ci-dessous cite les
documents source et devra être remplacée ou complétée par une matrice
REQ → plan → tâches quand la spécification sera validée.

## Résultat attendu

Une application Flutter Android qui permet de découvrir et rechercher les
produits du catalogue Django, d’ouvrir une fiche produit et de comparer les
prix/offres avec leur vendeur, disponibilité et fraîcheur. Les données
précédemment mises en cache restent consultables hors ligne et sont clairement
signalées comme anciennes/non vérifiées après expiration. La consultation
hors ligne n’autorise aucune écriture différée.

Les commandes, paiements, livraison, alertes, recommandations, prévisions,
contribution de prix et interfaces marchand/admin sont hors périmètre de ce
MVP.

## Constats et contraintes vérifiés

- La cible documentée est une application mobile Flutter/Dart communiquant
  avec Django REST Framework via HTTPS.
- Le code backend expose le catalogue sous `/api/catalog/products/` (recherche
  par `q`, filtres `category`, `brand`, `available`, `verified`) et la
  pagination Django par `page` et `page_size`.
- Les fiches produit sont exposées sous
  `/api/catalog/products/<id>/`. Les catégories disposent de
  `/api/catalog/categories/tree/`.
- Les offres sont exposées sous `/api/pricing/offers/`, filtrables par
  `product` et `merchant`. Les observations sont exposées sous
  `/api/pricing/observations/`, filtrables par `product`, `merchant`, `status`
  et `freshness`. Les disponibilités sont exposées sous
  `/api/availability/`.
- La recherche et la lecture du produit, des offres et des observations sont
  publiques dans les vues backend inspectées. Le frontend ne doit pas inventer
  un écran de connexion obligatoire pour ces lectures.
- Le backend rend actuellement les réponses paginées avec les champs
  `count`, `next`, `previous`, `results`.
- Les collections produit, prix, offre et disponibilité utilisent une
  pagination de 20 éléments par défaut, configurable par `page_size` jusqu’à
  100. La recherche produit accepte `q` et le `search` du `SearchFilter`; les
  tris déclarés sont `name`, `price_snapshot`, `created_at`. Les filtres
  `available` et `verified` ne filtrent actuellement que lorsqu’ils sont
  vrais (`true`, `1`, `yes`), pas lorsqu’on demande explicitement faux.
- Les routes backend actuelles sont `/api/catalog/products/`,
  `/api/catalog/categories/tree/`, `/api/pricing/offers/`,
  `/api/pricing/observations/` et `/api/availability/`. Les chemins
  `/api/v1/...` des documents ne correspondent pas aux URLs déclarées.
- Les lectures produit, offre, observation et disponibilité sont publiques.
  Les observations publiques sont limitées aux prix publiés ; les listes
  publiques d’offres aux offres actives.
- Le backend expose désormais
  `/api/comparison/products/{product_id}/offers/` comme contrat public enrichi
  de comparaison. Le frontend doit utiliser ce endpoint plutôt que les listes
  d’observations/offres seules ou les sessions de comparaison authentifiées.
- Le backend limite la comparabilité au produit demandé et à ses équivalences
  strictes directes ; le frontend ne doit jamais déduire l’équivalence d’une
  catégorie ou d’un nom identique.
- La liste publique de disponibilité est filtrable par `product`, `merchant`,
  `status`, `location`; elle inclut statut, `is_available`, quantité et date
  d’observation, mais pas les événements d’audit.
- Les choix Riverpod, go_router et Dio sont confirmés en P0.5 ; les
  dépendances sont installées. `json_annotation`, `json_serializable` et
  `build_runner` sont également en place pour les modèles JSON.
- Le jeu de données de recette et certaines formes d’erreur restent à
  formaliser.
- `compose.android.yaml` peut préparer l’outillage Android ; le projet Flutter
  et son `pubspec.yaml` sont déjà présents. La génération d’artefacts Android
  dépend encore de la disponibilité de l’outillage Android. Pour une recette
  Android, l’API Docker locale sur le port
  8010 doit être configurée comme `http://10.0.2.2:8010` depuis l’émulateur :
  `127.0.0.1` désigne l’émulateur lui-même. Cette URL HTTP est réservée au
  développement ; la production doit utiliser HTTPS.

## Décisions à prendre avant les tâches dépendantes

| Sujet | Proposition / constat | Action de clôture |
|---|---|---|
| Contrat API | Routes Django actuelles, pas les exemples `/api/v1/`; lecture publique et forme testées sur les ressources MVP | P0.2 documenter le contrat courant ; toute nouvelle version d’API reste une décision backend |
| Comparaison publique | Endpoint dédié choisi ; réponse paginée publique pour les offres admissibles du produit et de ses équivalences strictes directes | P0.3/P0.4 implémentés et couverts ; pas de rang entre devises différentes ni de promotion déclarée applicable sans validation de ses conditions |
| Équivalence | Liens explicites `ProductEquivalence.is_strict=true`, jamais `substitute`; conversion par équivalence exacte vers l’unité de base ; filtre de lieu textuel | Toute nouvelle forme d’équivalence ou de conversion requiert une règle dédiée et des tests |
| Architecture Flutter | Riverpod, go_router, Dio, json_serializable + build_runner ; Drift/SQLite pour le cache structuré ; flutter_secure_storage pour secrets/tokens et shared_preferences pour préférences non sensibles | Choix confirmés en P0.5 ; Riverpod/go_router/Dio/json_serializable configurés, cache et stockage sécurisé restent à implémenter |
| Cache | Dernières recherches/résultats, fiches et offres ; expiration à 7 jours, données expirées visibles hors ligne comme anciennes/non vérifiées, actualisation au retour réseau | Politique confirmée en P0.6 ; `cachedAtUtc` et `lastAccessedAtUtc` distincts des dates métier |
| Plafond cache | 100 Mio ; éviction LRU, puis plus ancien en cas d’égalité ; effacement manuel des données hors ligne | Politique confirmée en P0.6 ; les préférences et secrets/tokens sont exclus de cet effacement |
| Design et formats | Material 3 accessible, couleur semence bleue ; format régional `fr-FR`, devise fournie par chaque offre, sans conversion | Choix confirmés en P0.7 ; conserver le regroupement séparé par devise |
| Recette/performance | Émulateur Pixel 6a ; démarrage à froid ≤ 3 s, UI locale p95 ≤ 100 ms, recherche backend local p95 ≤ 2 s ; 100 % des parcours critiques passent | Seuils et appareil de référence confirmés en P0.7 ; mesurer au moins 10 runs et consigner p50/p95 |
| Backend local | Docker local sur le port 8010 ; profil local HTTP | `10.0.2.2:8010` pour émulateur Android, URL configurable |
| Santé API | `GET /api/` renvoie HTTP 200 avec `status: "ok"` ; la racine `/` est aussi la cible du healthcheck du Compose production | Réutiliser `/api/` comme vérification de joignabilité API ; cela ne garantit pas la disponibilité de la base |
| Plateformes | Android prioritaire ; Flutter reste portable | Gate Android pour le MVP ; builds/recette iOS dans un incrément macOS séparé |
| Livraison Android | Flutter stable 3.47.7, Dart `^3.13.5`, minSdk 24 ; SDK API 37, Command-line Tools et NDK 28.2.13676358 ; GitHub Actions ; keystore externe injecté via GitHub Secrets | Choix confirmés en P0.8 ; build APK debug vérifié ; avertissement `flutter doctor` lié à l’espace dans le chemin SDK, à traiter si le build NDK échoue dans un incrément ultérieur |

Les décisions cochées et consignées sont validées. Les décisions encore
ouvertes doivent l’être avant leurs tâches dépendantes. Les secrets de
signature ne doivent jamais être ajoutés au dépôt ni intégrés à l’image Docker.

## Phases et tâches

Les phases sont ordonnées par dépendance, sans estimation calendaire tant que
la taille de l’équipe et les décisions bloquantes ne sont pas connues.

### Phase 0 — Contrats et périmètre

- [x] **P0.1** Enregistrer le périmètre MVP déjà retenu (accueil, recherche et
  filtres, fiche produit, comparaison, cache hors ligne) et ses exclusions dans
  ce plan de travail ; ne pas rouvrir ce choix sans demande. Le plan est le
  seul support de périmètre frontend identifié à ce stade.
- [x] **P0.2** Publier `frontend/contracts/api-contract.md` avec méthode,
  route, filtres réellement applicables, permission, champs de réponse,
  pagination, erreurs et exemples JSON dérivés des tests backend ; noter les
  écarts aux documents `/api/v1/...`. Les tests API ciblés du catalogue,
  observations, offres et disponibilités ainsi que l’enveloppe 404 passent.
  La documentation décrit les surfaces vérifiées ; les autres erreurs et
  routes restent explicitement source-derived.
- [x] **P0.3** Définir un contrat de comparaison public à la demande avec un
  endpoint dédié, choix confirmé par l’utilisateur : `GET
  /api/comparison/products/{product_id}/offers/`. La réponse paginée inclut
  vendeur, montant/devise, quantité/unité, format, lieu, disponibilité,
  fraîcheur et date d’observation. Seules les offres valides liées à un prix
  publié et exposé du même produit actif sont retournées. Tests couvrent
  l’accès anonyme, la pagination, la forme de réponse et l’exclusion des
  offres/prix non admissibles.
- [x] **P0.4** Définir et implémenter les critères de comparabilité : le même
  produit ou un lien direct explicite `ProductEquivalence.is_strict=true`
  autorise le regroupement ; les substituts, équivalences non strictes,
  produits inactifs et liens transitifs sont exclus. Le backend normalise
  seulement via une conversion exacte directe vers l’unité de base et renvoie
  une raison lorsque le prix unitaire ne peut pas être normalisé. Les
  devises sont des groupes distincts sans taux de change ; le lieu reste
  visible et filtrable ; les promotions exposent leurs conditions sans être
  déclarées applicables ni classées comme meilleure offre. Exemples acceptés
  et refusés documentés dans `contracts/api-contract.md`; tests couvrent
  équivalence stricte, substitut, conversion exacte/approximative, devise,
  lieu et conditions promotionnelles.
- [x] **P0.5** Choisir et consigner Riverpod (`flutter_riverpod`) pour l’état,
  `go_router` pour la navigation, Dio pour HTTP, `json_serializable` avec
  `build_runner` pour la sérialisation, Drift/SQLite pour le cache structuré,
  `flutter_secure_storage` pour les secrets/tokens et `shared_preferences`
  pour les préférences non sensibles. L’URL d’API reste configurable. Choix
  confirmés ; les dépendances ne sont pas encore installées.
- [x] **P0.6** Conserver recherches/résultats, fiches produit et offres dans
  Drift/SQLite avec `cachedAtUtc`, `lastAccessedAtUtc` et contexte de requête.
  Une entrée expire à l’âge `>= 7 jours`, mais reste consultable hors ligne
  avec le statut « expiré/non vérifié » ; au retour du réseau, tenter son
  actualisation sans masquer les données si elle échoue. Limiter ce cache à
  100 Mio et évincer les éléments les moins récemment consultés (LRU), puis
  les plus anciens en cas d’égalité. Prévoir une action pour effacer toutes
  les données hors ligne, sans toucher aux préférences ni aux secrets/tokens.
  L’expiration locale ne prolonge jamais la fraîcheur métier ni la validité
  serveur d’une offre.
- [x] **P0.7** Valider Material 3 accessible avec couleur semence bleue, format
  `fr-FR` et devise issue de chaque offre sans conversion, émulateur Pixel 6a
  comme référence, ainsi que les seuils de recette : démarrage à froid ≤ 3 s,
  UI locale p95 ≤ 100 ms, recherche vers backend local p95 ≤ 2 s et succès de
  100 % des parcours critiques. Mesurer au moins 10 runs et consigner p50/p95.
- [x] **P0.8** Conserver Flutter stable 3.47.7 et la contrainte Dart
  `^3.13.5` ; prendre en charge Android API 24+ (minimum par défaut de
  Flutter 3.47.7). Installer/configurer les Command-line Tools, le SDK Android
  API 37 et le NDK 28.2.13676358 ; builds et tests Android via GitHub Actions ;
  keystore de publication hors dépôt, injecté via GitHub Secrets. Les outils
  sont installés, `flutter analyze`, `flutter test` et `flutter build apk
  --debug` passent. `flutter doctor` conserve un avertissement sur l’espace
  dans le chemin SDK, mais le build debug fonctionne. Maintenir build et
  recette iOS dans un incrément séparé sur macOS.
- [ ] **P0.9** Documenter l’intégration Docker : port local `APP_PORT=8010`,
  URL `http://10.0.2.2:8010` depuis l’émulateur, `GET /api/` comme contrôle
  de joignabilité (sans garantie de santé base de données), fixtures
  déterministes de recette et configuration HTTP locale distincte de la
  production HTTPS. Aucun jeu de fixtures manuel réutilisable n’a été trouvé ;
  sa stratégie reste à confirmer.

**Dépendances et gates :**

- P1.1 (audit du squelette) peut commencer immédiatement, en parallèle de P0.
- P1 et les fondations P2 démarrent après validation du périmètre (P0.1), des
  contrats nécessaires (P0.2), des choix techniques (P0.5) et du design system
  nécessaire aux écrans (P0.7). Les builds Android attendent aussi P0.8.
- La recherche et la fiche produit peuvent avancer à partir des contrats
  catalogue confirmés ; elles ne sont pas bloquées par le contrat de
  comparaison.
- P0.3 et P0.4 sont clôturés pour la lecture des offres d’un produit. Aucun
  classement inter-devises, traitement automatique des substitutions ni
  promotion « meilleure offre applicable » ne doit être ajouté sans règle
  métier validée.
- P5 peut démarrer sur la politique confirmée en P0.6. La recette connectée
  au backend attend la configuration locale P0.9.

### Phase 1 — Initialisation Flutter

- [x] **P1.1** Auditer le squelette Flutter déjà présent (`pubspec.yaml`,
  `analysis_options.yaml`, `lib/`, `test/` et plateformes) ; ne pas recréer le
  projet. Ajouter `integration_test/` et compléter la configuration uniquement
  lorsque les tâches de recette en auront besoin. Constat : Flutter 3.47.7,
  contrainte Dart `^3.13.5`, shell applicatif comparateur et tests Flutter.
  Les dépendances applicatives de navigation, d’état, HTTP et JSON sont
  installées. Les Android SDK
  Command-line Tools et le NDK sont maintenant installés ; `flutter analyze`,
  `flutter test` et un build APK debug passent depuis le dossier frontend.
- [x] **P1.2** Remplacer le démarrage de démonstration (`lib/main.dart`) par
  l’entrée de l’application comparateur ; créer `lib/app/bootstrap.dart`,
  `lib/app/app.dart`, la configuration par environnement et la composition
  centralisée des dépendances, sans surarchitecture.
- [ ] **P1.3** Ajouter et configurer `go_router` et `flutter_riverpod` ;
  définir les routes accueil, recherche, fiche produit et comparaison, ainsi
  que les points d’injection d’état.
- [ ] **P1.4** Créer les fondations du thème et les composants accessibles
  communs à partir du système visuel validé.
- [ ] **P1.5** Exécuter l’analyse statique et les tests depuis
  `comparateur-prix/frontend/`, puis vérifier le lancement web et le build
  Android. Après disponibilité d’un émulateur/appareil de recette, valider le
  lancement et le parcours initial sur Android.

**Gate de sortie :** application lançable sur émulateur Android, navigation
initiale fonctionnelle et contrôles statiques sans erreur.

### Phase 2 — Fondations données et API

- [x] **P2.1** Implémenter `lib/core/config/` et
  `lib/core/network/api_client.dart` avec Dio, une URL d’API configurable,
  HTTPS en production, délais définis, annulation si disponible et
  journalisation sans données sensibles.
- [x] **P2.2** Implémenter `lib/core/errors/` pour normaliser connectivité,
  timeout, erreurs HTTP, validation et réponses invalides en conservant la
  sémantique réellement renvoyée par Django.
- [ ] **P2.3** Ajouter dans les domaines catalogue/prix les modèles Dart typés
  sérialisés avec `json_serializable` correspondant aux schémas confirmés ;
  valider champs facultatifs, dates, devises et montants sans conversions
  silencieuses ni calculs monétaires imprécis.
- [ ] **P2.4** Créer les sources distantes et repositories pour produits,
  catégories, comparaison publique et disponibilité à partir du contrat
  validé. Respecter `page`, `page_size`, `count`, `next`, `previous`,
  `results` sur les collections paginées et traiter séparément l’arbre des
  catégories non paginé. La partie comparaison utilise le contrat et les
  critères P0.3/P0.4 ; les sources catalogue s’appuient sur les routes
  confirmées en P0.2.
- [ ] **P2.5** Représenter disponibilité inconnue, prix périmé/non vérifié et
  champs absents sans les convertir en faux ou zéro ; conserver séparément
  date d’observation et date de synchronisation locale.
- [ ] **P2.6** Ajouter les tests unitaires de désérialisation, pagination,
  normalisation d’erreurs, précision monétaire et valeurs inconnues.

**Gate de sortie :** repositories testables avec réponses simulées ; absence de
dépendance HTTP directe depuis les widgets.

### Phase 3 — Parcours US1 : découverte et recherche

- [ ] **P3.1** Construire l’accueil et la navigation vers la recherche et les
  catégories ; n’afficher que des données disponibles dans le contrat.
- [ ] **P3.2** Construire `features/search/` : saisie, conservation de requête,
  appel catalogue avec `q`, filtres retenus et tri réellement pris en charge.
- [ ] **P3.3** Ajouter la pagination sans doublons et empêcher les réponses
  d’une ancienne requête d’écraser les résultats courants.
- [ ] **P3.4** Implémenter les états initial, chargement, résultats, aucun
  résultat, erreur, pagination complémentaire et actualisation sans effacer
  inutilement les données visibles.
- [ ] **P3.5** Ajouter les tests unitaires, widgets et intégration API simulée
  de la recherche, des filtres, de la pagination, des erreurs et des réponses
  concurrentes.

**Gate de sortie :** un utilisateur peut chercher et filtrer le catalogue ;
une liste vide et une erreur réseau sont clairement distinctes.

**Avancement du premier incrément API/recherche :** le modèle sérialisé de
liste produit, le client Dio configurable, le repository du catalogue et la
recherche par `q` avec les états initial, chargement, résultats, aucun résultat
et erreur sont implémentés. Le client utilise actuellement la première page
(20 résultats) ; filtres, tri, pagination interactive, catégories, détail,
comparaison et cache restent dans leurs tâches respectives.

### Phase 4 — Parcours US2 : fiche produit et comparaison

- [ ] **P4.1** Construire `features/catalog/` et l’écran de fiche à partir du
  détail produit confirmé ; permettre l’affichage même si une image ou des
  champs facultatifs manquent.
- [ ] **P4.2** Construire `features/pricing/` pour présenter les offres du
  contrat public `/api/comparison/products/{id}/offers/` et la disponibilité
  de `/api/availability/`. Ne pas considérer les sessions authentifiées
  comme une source consommateur.
- [ ] **P4.3** Construire `features/comparison/` avec prix/devise, vendeur,
  localisation/format, disponibilité, date d’observation, validation et
  fraîcheur lorsque fournis ; regrouper par devise et `comparison_group`, et
  exposer les raisons d’absence de prix unitaire normalisé.
- [ ] **P4.4** Ne calculer un coût total que lorsque tous ses éléments sont
  connus ; distinguer produits équivalents des substituts et ne pas confondre
  prix absent, disponibilité inconnue ou donnée périmée avec une information
  confirmée. Ne pas marquer une promotion comme prix applicable sans valider
  les conditions d’éligibilité.
- [ ] **P4.5** Implémenter les états partiels : une fiche produit doit rester
  consultable si le chargement des offres échoue ; permettre une nouvelle
  tentative sans masquer inutilement le contenu déjà exploitable.
- [ ] **P4.6** Ajouter tests unitaires, widgets, intégration et parcours bout en
  bout produit → offres → comparaison, y compris variantes, données
  partielles, prix périmés et disponibilité inconnue.

**Gate de sortie :** les prix sont contextualisés et la comparaison ne présente
pas comme équivalentes des offres de format, lieu, fraîcheur ou disponibilité
différents.

### Phase 5 — Résilience et lecture hors ligne

- [ ] **P5.1** Implémenter la détection de connectivité et distinguer réseau
  indisponible, serveur inaccessible et timeout.
- [ ] **P5.2** Implémenter dans Drift/SQLite le cache de lecture défini en
  P0.6 pour les dernières recherches, fiches produit et offres consultées.
  Persister `cachedAtUtc`, `lastAccessedAtUtc`, le contexte de requête et la
  limite de 100 Mio ; évincer par LRU, puis par ancienneté. Une entrée expire
  lorsque son âge atteint ou dépasse 7 jours. Exposer une action d’effacement
  des données hors ligne. Distinguer la synchronisation locale de la date
  d’observation et de la validité métier de l’offre.
- [ ] **P5.3** En cas de panne réseau, restaurer les données mises en cache,
  y compris celles expirées, et afficher distinctement leur état « expiré/non
  vérifié » et leur ancienneté. Au retour du réseau, tenter une actualisation
  sans perdre les données affichées si elle échoue. L’expiration locale ne
  prolonge jamais la fraîcheur métier ni la validité d’une offre déjà expirée
  côté serveur.
- [ ] **P5.4** Limiter les requêtes lors du retour réseau et empêcher les
  réponses tardives de remplacer un état plus récent.
- [ ] **P5.5** Garder les écritures hors ligne désactivées ; ne créer aucune
  file d’attente ou synchronisation différée dans ce MVP.
- [ ] **P5.6** Tester cache vide/récent, frontière d’expiration (`>= 7 jours`),
  affichage hors ligne des données expirées, cache corrompu, stockage
  indisponible, reconnexion, rafraîchissement échoué, plafond/LRU, effacement
  manuel et réponse réseau plus ancienne qu’un résultat déjà affiché.

**Gate de sortie :** les données locales sont visiblement identifiées comme
cache ; les données expirées restent disponibles hors ligne mais sont
explicitement marquées « expiré/non vérifié » ; l’absence de réseau n’est pas
présentée comme une absence de résultat.

### Phase 6 — Recette et livraison Android

- [ ] **P6.1** Compléter les tests Flutter unitaires, widgets, intégration API
  simulée et les tests bout en bout des parcours critiques.
- [ ] **P6.2** Vérifier l’accessibilité, les petites/grandes tailles d’écran,
  l’absence de débordement et la lisibilité des statuts sans dépendre
  uniquement de la couleur.
- [ ] **P6.3** Exécuter la recette Android sur émulateur/appareil connecté au
  backend Docker local (`http://10.0.2.2:8010` depuis l’émulateur) : démarrage,
  recherche, filtres, pagination, fiche, comparaison anonyme, panne réseau et
  cache à la frontière d’expiration approuvée.
- [ ] **P6.4** Configurer GitHub Actions et vérifier les builds APK/AAB avec
  `compose.android.yaml` sur le projet Flutter existant. Injecter le keystore
  et ses secrets via les secrets GitHub, sans les écrire dans le dépôt ou
  l’image Docker.
- [ ] **P6.5** Documenter les commandes de développement/test/build, les
  paramètres d’environnement et la procédure de livraison.

**Gate de sortie :** les commandes d’analyse et de test passent, les parcours
critiques sont démontrés sur Android et les artefacts de livraison sont
générés sans clé privée dans le dépôt.

## Stratégie de validation

- **Type d’application :** client mobile Flutter d’une API REST.
- **Parcours critiques :** démarrage Android ; recherche, filtres et pagination ;
  zéro résultat distinct d’une panne ; fiche produit avec image/champs absents ;
  comparaison publique de produits équivalents ; consultation hors ligne et
  expiration du cache.
- **Tests automatisés :** tests unitaires des modèles, repositories,
  équivalence et expiration ; tests widgets des états chargement/vide/erreur/
  hors ligne ; tests d’intégration contre backend Docker de test ; tests
  bout-en-bout sur émulateur pour les parcours critiques.
- **Contrat API :** réponse anonyme, présence des champs de comparaison et
  pagination vérifiées côté backend ; fixtures provenant des vrais serializers
  et revues avec leurs formes JSON attendues.
- **Environnement local :** `127.0.0.1:8010` depuis l’hôte,
  `10.0.2.2:8010` depuis l’émulateur Android, HTTP uniquement via le profil
  Docker local. Préproduction/production utilisent HTTPS et doivent échouer
  explicitement en cas de configuration d’URL invalide.
- **Données de test déterministes :** au moins deux marchands, unités et
  quantités différentes, offre active et expirée, disponibilité inconnue,
  variantes équivalentes/non équivalentes et produit sans image. Ne pas
  dépendre de données de production ou d’un service tiers.
- **Acceptation fonctionnelle :** 100 % des parcours critiques passent ;
  résultats de recherche sans doublons lors de la pagination ; aucune réponse
  d’une ancienne requête ne remplace la recherche courante ; comparaison sans
  vendeur/devise/contexte requis refusée ou explicitement incomplète ; donnée
  en cache marquée avec heure de synchronisation et statut explicite après
  l’expiration à 7 jours approuvée en P0.6. La date de synchronisation locale
  ne rajeunit ni `observed_at` ni la validité de l’offre.
- **Accessibilité :** recette avec agrandissement du texte, navigation
  sémantique et statuts compréhensibles sans dépendre uniquement de la couleur.
- **Performance (seuils approuvés en P0.7) :** sur émulateur Pixel 6a,
  démarrage à froid jusqu’à l’accueil utilisable ≤ 3 s ; transition UI locale
  p95 ≤ 100 ms ; recherche via backend local p95 ≤ 2 s, mesurée séparément du
  temps de rendu. Mesurer au moins 10 runs et conserver p50/p95 ; ne pas
  attribuer la latence réseau au rendu Flutter.
- **Gate de validation :** analyse statique et tests verts ; les tests
  d’intégration et E2E sont reproductibles ; aucune anomalie bloquante de
  contrat, fraîcheur, équivalence ou exposition d’URL locale.

## Structure cible indicative

```text
comparateur-prix/frontend/
├── android/
├── ios/
├── assets/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── bootstrap.dart
│   │   ├── app.dart
│   │   ├── router.dart
│   │   └── theme/
│   ├── core/
│   │   ├── config/
│   │   ├── errors/
│   │   ├── network/
│   │   ├── storage/
│   │   ├── connectivity/
│   │   └── widgets/
│   ├── features/
│   │   ├── catalog/
│   │   ├── search/
│   │   ├── pricing/
│   │   └── comparison/
│   └── shared/
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
├── integration_test/
├── pubspec.yaml
└── analysis_options.yaml
```

Les sous-couches `presentation/`, `application/`, `domain/` et `data/` seront
créées là où elles clarifient effectivement les responsabilités, en particulier
pour recherche, comparaison et accès aux données ; elles ne sont pas
reproduites mécaniquement dans chaque petite fonctionnalité.

## Parcours et critères de recette

1. **Démarrage** — l’application s’ouvre et présente l’accueil sans exception
   bloquante.
2. **Recherche** — une requête, les filtres et la pagination retournent les
   éléments attendus ; aucun résultat est distinct d’une erreur.
3. **Produit** — la fiche correspond à la variante choisie, sans exiger image
   ou champ facultatif.
4. **Comparaison** — chaque prix reste associé à sa devise, quantité/unité,
   vendeur, fraîcheur et disponibilité ; aucune valeur inconnue n’est inventée.
5. **Hors ligne** — le cache peut être consulté avec un indicateur d’ancienneté,
   les actions dépendant du serveur sont limitées et aucune observation n’est
   envoyée en différé.

## Correspondance documents → plan

| Source | Exigences exploitées | Phases |
|---|---|---|
| `Comparateur-Prix_DOC-FE-ARCH-001_Architecture_Flutter_v0.1.docx` | Architecture fonctionnelle en couches, état/navigation à valider, dépendances centralisées, testabilité, simplicité proportionnée | P0–P2, P6 |
| `Comparateur-Prix_DOC-FE-API-001_Donnees_et_integration_API_v0.1.docx` | Client HTTP configuré, modèles typés, auth centralisée si nécessaire, erreurs, pagination, concurrence, montants/dates et tests | P0–P4 |
| `Comparateur-Prix_DOC-FE-UX-001_Specifications_UX_UI_v0.1.docx` | Accueil, recherche, filtres, fiche produit, comparaison, états asynchrones, fraîcheur, accessibilité, neutralité | P1, P3–P4, P6 |
| `Comparateur-Prix_DOC-FE-SEC-001_Resilience_et_securite_v0.1.docx` | Lecture du cache hors ligne, pas d’écriture différée, fraîcheur, reconnexion, erreurs de stockage, isolation éventuelle | P0, P5–P6 |
| `Comparateur-Prix_DOC-FE-TEST-001_Strategie_de_tests_v0.1.docx` | Tests unitaires, widgets, intégration, bout en bout et cas de recette | P1–P6 |
| Code backend `apps/catalog`, `apps/pricing`, `apps/availability`, `apps/comparison` | Routes, permissions, filtres, pagination et schémas actuellement exposés ; sessions de comparaison existantes authentifiées | P0, P2–P4 |

## Hors périmètre / incréments futurs

- Connexion, inscription, gestion de session et favoris personnalisés : à
  planifier quand ils sont retenus comme exigences du produit.
- Contribution/soumission de prix : nécessite auth, règles de validation,
  autorisation et parcours en ligne dédiés.
- Commande, paiement, livraison, notification, alerte, IA et administration :
  incréments postérieurs à ce MVP.
- Publication iOS : nécessite une machine macOS/Xcode et une procédure
  distincte du conteneur Android Linux.
