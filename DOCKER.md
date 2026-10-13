# Flutter mobile builds with Docker

The architecture target is a Flutter mobile application. The Docker setup
provides a Linux Flutter/Android build environment and writes release artifacts
to the mounted frontend directory:

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Android App Bundle: `build/app/outputs/bundle/release/app-release.aab`

Build the toolchain image from this directory:

```powershell
docker compose -f compose.android.yaml build
```

Once the Flutter project (including `pubspec.yaml`) is present here, build both
Android release artifacts with:

```powershell
docker compose -f compose.android.yaml run --rm android-builder
```

The Flutter version can be pinned when the project establishes its supported
SDK version, for example by setting `FLUTTER_VERSION` before building. The
current default uses Flutter's stable channel because the architecture
documents do not specify an SDK version.

iOS builds are not supported by this Linux image. Flutter iOS release builds
require macOS and Xcode; run those on a Mac or a macOS CI runner. Android
release signing credentials must be supplied securely at build time and must
not be committed to the repository.
