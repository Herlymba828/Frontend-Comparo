# Comparateur Prix — frontend Flutter

Application Flutter du parcours consommateur et des espaces marchand, livreur
et modération. Le projet Flutter se trouve dans ce dossier
(`comparateur-prix/comparo_frontend-v2.4/`) ; son habillage vient du design
system Comparo v2.4 (voir « Référence visuelle »).

Le nom affiché est « Comparateur Prix » sur les plateformes mobiles et Web.
L'identifiant Android défini pour le produit est
`com.nexorion_security.comparateurprix`. Les icônes utilisent le vert de marque
`#24834B`, le fond clair `#FAFBF5` et l'accent `#D7E96B`.

## Développement local

Depuis ce dossier :

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port 7357
```

Le frontend lit le catalogue via `GET /api/catalog/products/`, utilise
l’authentification par jetons JWT (`/api/auth/signup/`, `/api/auth/login/` et
`/api/auth/refresh/`) et gère les alertes avec `/api/alerts/`. Le backend doit
être démarré sur le port `8010` :

- Chrome, Windows et iOS simulateur : `http://127.0.0.1:8010`
- Émulateur Android : `http://10.0.2.2:8010`

L'API de développement (`backend/compose.dev.yaml`) n'autorise, pour le Web,
que les origines `http://127.0.0.1:7357` à `7359` (et `localhost`) : lancez
donc `flutter run` avec `--web-port 7357`. Une page servie sur un autre port
est bloquée par le navigateur (CORS).

Une URL différente peut être fournie au lancement :

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=https://api.example.com
```

En production, `API_BASE_URL` est obligatoire et doit être une URL HTTPS
publique. Les URL HTTP, loopback, réseau privé ou locales sont refusées en
release. Ne placez pas de secret dans cette valeur. Exemple de build release :

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com
```

Les montants sont formatés selon `fr-FR` et gardent la devise renvoyée par
l’API. Le franc CFA s’écrit « FCFA » et perd ses décimales nulles
(`1650.00` XAF devient `1 650 FCFA`) ; un montant qui a de vraies décimales
n’est jamais arrondi. Si la devise manque, l’application l’indique sans la
remplacer par une autre devise.

## Référence visuelle

L'habillage suit le design system **Comparo v2.4** (identité « Marché &
étiquettes », palette « Fraîcheur quotidienne ») :

- `flutter/comparo_ui/` est le paquet de composants (corde à prix, ligne de
  preuve, étiquette citron, ardoise « Prix du jour », carte « Ma liste de la
  semaine », barre d'onglets, thème). L'app l'utilise comme dépendance
  (`comparo_ui: path: flutter/comparo_ui`).
- Ses polices (Bricolage Grotesque, Manrope, SIL OFL) sont enregistrées sous le
  nom `packages/comparo_ui/…` : ne jamais écrire `'Manrope'` seul dans un style,
  il retomberait sur la police du système. Passer par `AppFonts` ou `ComparoText`.
- Les couleurs de l'app (`AppColors`) sont des alias de la palette du design
  system : rien n'y est écrit en dur. Le thème (`AppTheme.light`) part de
  `ComparoTheme.light()`.
- Les jetons viennent de `design-system/tokens.json`, produit par
  `tools/tokens.py` ; ne pas modifier `tokens.dart` à la main. Sous Windows,
  lancer les scripts avec `PYTHONUTF8=1` (sinon ils échouent sur les accents
  et peuvent laisser un fichier tronqué).
- Cibles tactiles de 48 px au moins (règle Android).
- Les polices étant variables, un style qui fixe `fontVariations` ne suit plus
  `copyWith(fontWeight: …)` : utiliser `AppTextStyles.weighted`.
- Le prix est un simple chiffre ; l'étiquette citron est réservée au meilleur
  prix (`PriceTag(best: true)`, `BestPriceSeal`), une seule par produit.

Les tests du paquet : `cd flutter/comparo_ui && flutter test` (les captures de
référence tolèrent 4 % de pixels différents : le lissage des lettres change
d'un système à l'autre ; régénérer avec `--update-goldens`).

Écrans (barre du bas : Accueil, Recherche, Ma liste, Profil) :

- **Client** : accueil, recherche, fiche produit et comparaison (ajout d’une
  offre au panier), panier (`/cart`), commande en livraison ou retrait
  (`/checkout`, adresses), mes commandes (`/orders`) avec paiement, relance,
  annulation, suivi de livraison et code de retrait, notifications, alertes de
  prix, profil et sécurité (mot de passe, appareils connectés), aide et
  réclamations (`/support`).
- **Communauté** : relevés de prix (`/contributions`) — confirmer ou
  contester ceux des autres ; relever un prix en magasin
  (`/contributions/new`) : magasin trouvé par la position (après accord) ou
  par recherche, produit suggéré, prix contrôlé, photo et erreur d’affichage
  facultatives.
- **Marchand** (`/merchant`) : ouverture de boutique, commandes reçues
  (préparer le retrait, vérifier le code client, confier à un coursier,
  rembourser), offres (soumission puis publication), stock, points de retrait.
- **Coursier** (`/courier`, rôle `courier`) : mes courses, courses ouvertes de
  mes zones, prise en charge, statut, position, preuve de livraison,
  disponibilité.

Les appels réseau passent par `lib/core/network/json_api.dart` (erreurs
converties en `ApiException`). La disponibilité
des images, prix, catégories, offres et alertes dépend des réponses réelles de
l’API ; aucune donnée de catalogue n’est fabriquée par l’interface.

Les jetons d’accès et de rafraîchissement sont conservés avec
`flutter_secure_storage`. L’accès aux alertes nécessite une session
authentifiée ; une session existante est restaurée au démarrage de ces écrans.
Le rafraîchissement peut faire tourner le jeton : le backend rattache alors la
session existante au nouveau jeton, et la déconnexion révoque cette session.
Lors de la création d’une alerte, `threshold_amount` n’est envoyé que si un
seuil a été renseigné.
Pour le Web, utilisez une origine sécurisée (HTTPS en production) ; le
stockage Web du plugin repose sur WebCrypto.
Pour Android, la version actuelle de `flutter_secure_storage` impose un minimum
API 24 dans le manifeste de la dépendance, donc le projet cible désormais API
24 minimum pour rester compatible avec le plugin web modernisé.

## Modèles JSON

Les modèles utilisent `json_serializable`. Après les avoir modifiés, régénérez
les fichiers Dart :

```powershell
dart run build_runner build
```

Le cache hors ligne est une base SQLite (Drift, `offline_cache_database.dart`) ;
après une modification de son schéma, la même commande régénère son code.

## Tests

```powershell
flutter analyze
flutter test                                   # unitaires, widgets, accessibilité
flutter test integration_test/critical_journeys_test.dart -d emulator-5554
```

`critical_journeys_test.dart` rejoue les parcours critiques avec un backend
simulé déterministe (recherche → fiche → comparaison → disponibilité, hors
ligne avec cache expiré, échec partiel des offres). `test/accessibility_test.dart`
vérifie petits écrans avec texte à 200 %, tablette, cibles tactiles, libellés
et contraste.

## Recette contre le backend Docker local

1. Démarrer le backend de développement (`DJANGO_DEBUG=true`, port
   `APP_PORT`, 8010 par défaut) depuis `../backend`, en reconstruisant l’image
   pour qu’elle contienne la commande de données, puis charger les données
   déterministes de recette :

   ```powershell
   docker compose -f compose.dev.yaml up --build -d
   docker compose -f compose.dev.yaml exec api python manage.py seed_frontend_demo_data
   ```

   Pour une pile de recette isolée, changez le projet et le port :
   `$env:APP_PORT=8011; docker compose -p comparateur-prix-qa -f compose.dev.yaml up --build -d`
   (puis `10.0.2.2:8011` depuis l’émulateur).

   La commande refuse de s’exécuter hors `DEBUG` ; elle crée 3 produits,
   2 marchands, 3 offres actives, 1 offre expirée et leurs disponibilités.
2. Vérifier la joignabilité : `GET http://127.0.0.1:8010/api/` doit répondre
   `"status": "ok"` (cela ne garantit pas la santé de la base).
3. Lancer la recette sur l’émulateur (`10.0.2.2` désigne l’hôte) :

   ```powershell
   flutter test integration_test/backend_acceptance_test.dart -d emulator-5554 `
     --dart-define=API_BASE_URL=http://10.0.2.2:8010
   ```

   Le test mesure aussi la latence de recherche (10 exécutions, p50/p95,
   seuil p95 ≤ 2 s). Le temps de démarrage à froid se mesure avec
   `adb shell am start -W -S com.nexorion_security.comparateurprix/.MainActivity`.

L’URL HTTP n’est acceptée qu’en debug/profil local ; une release exige HTTPS.

## Builds et livraison Android

```powershell
flutter build web
flutter build apk --debug
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com
```

Le build Android nécessite les Android SDK Command-line Tools et le NDK
documentés dans [PLAN-TRAVAIL.md](PLAN-TRAVAIL.md).

**Signature release.** La clé n’est jamais versionnée. En local, créez
`android/key.properties` (ignoré par git) :

```properties
storeFile=../release.keystore
storePassword=…
keyAlias=…
keyPassword=…
```

ou exportez `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS` et `ANDROID_KEY_PASSWORD`. Sans clé, une build release
**échoue** volontairement. Pour un test local seulement, signez avec la clé
debug de façon explicite (artefact non publiable) :

```powershell
flutter run --release -P allowDebugSigning=true
flutter build apk --release -P allowDebugSigning=true --dart-define=API_BASE_URL=https://api.example.com
```

**CI.** Le job `android-release` du workflow GitHub Actions construit l’AAB et
l’APK signés sur `master` et les publie comme artefact `android-release`.
Créez l’environnement GitHub `android-release` avec la variable `API_BASE_URL`
et les secrets `ANDROID_KEYSTORE_BASE64` (keystore encodé en base64),
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Le
keystore est décodé dans le dossier temporaire du runner puis supprimé ; sans
ces secrets, le job est ignoré avec un avertissement.

## Déploiement Web HTTPS

Le site est configuré pour Azure Static Web Apps. Le fichier
`web/staticwebapp.config.json` active le fallback des routes Flutter, les
en-têtes de sécurité et le type MIME WebAssembly. Azure fournit HTTPS sur
l’URL `*.azurestaticapps.net` et sur les domaines personnalisés après leur
validation.

Le workflow GitHub Actions valide le frontend sur les pull requests vers
`master` et ne déploie que les pushs sur `master` (ou un lancement manuel sur
`master`). Pour le déploiement, créez l’environnement GitHub `production` et
configurez :

- la variable `API_BASE_URL` avec l’URL HTTPS publique de l’API ;
- le secret `AZURE_STATIC_WEB_APPS_API_TOKEN` avec le jeton de déploiement de
  la ressource Azure Static Web Apps.

Le backend doit autoriser l’origine exacte du site dans `CORS_ALLOWED_ORIGINS`
(par exemple `https://<nom>.azurestaticapps.net`). Ne configurez pas une
origine générique `*`. La procédure détaillée figure dans
[`../../.azure/pipeline-setup.md`](../../.azure/pipeline-setup.md).
