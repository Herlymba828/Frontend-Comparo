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

The release build requires `API_BASE_URL` (public HTTPS URL) and reads the
signing credentials from the host environment, never from the image:

```powershell
$env:API_BASE_URL = "https://api.example.com"
$env:ANDROID_KEYSTORE_PATH = "/workspace/android/release.keystore"  # ignored by git
$env:ANDROID_KEYSTORE_PASSWORD = "…"
$env:ANDROID_KEY_ALIAS = "…"
$env:ANDROID_KEY_PASSWORD = "…"
docker compose -f compose.android.yaml run --rm android-builder
```

Without `ANDROID_KEYSTORE_PATH` the artifacts are signed with the debug key and
must not be published.

iOS builds are not supported by this Linux image. Flutter iOS release builds
require macOS and Xcode; run those on a Mac or a macOS CI runner.
