# Comparateur Prix — frontend Flutter

Application Flutter du parcours consommateur. Le projet Flutter se trouve dans
ce dossier (`comparateur-prix/frontend/` dans le dépôt principal).

## Développement local

Depuis ce dossier :

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Le frontend lit le catalogue via `GET /api/catalog/products/`. Le backend doit
être démarré sur le port `8010` :

- Chrome, Windows et iOS simulateur : `http://127.0.0.1:8010`
- Émulateur Android : `http://10.0.2.2:8010`

Une URL différente peut être fournie au lancement :

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=https://api.example.com
```

En production, `API_BASE_URL` doit utiliser HTTPS. Ne placez pas de secret dans
cette valeur.

## Modèles JSON

Les modèles utilisent `json_serializable`. Après les avoir modifiés, régénérez
les fichiers Dart :

```powershell
dart run build_runner build
```

## Builds

```powershell
flutter build web
flutter build apk --debug
flutter build appbundle --release
```

Le build Android nécessite les Android SDK Command-line Tools et le NDK
documentés dans [PLAN-TRAVAIL.md](PLAN-TRAVAIL.md).
