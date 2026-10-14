# Releasing

## Version

The version is in `pubspec.yaml` (`<version name>+<build number>`). Also update
`AppConfig.appVersion` in `lib/config/app_config.dart`. For every release,
raise both the version name and the build number, because Android refuses to install
an update whose build number isn't higher. Add an entry to `CHANGELOG.md`.

## Signing key

Every update must be signed with **the same key**, or installed phones can't
update and would have to uninstall, which erases the app's data.

The key lives outside the repository:

```text
C:\Users\cedri\dev\keys\gym-quest-release.jks
C:\Users\cedri\dev\keys\gym-quest-key.properties.backup   (passwords)
```

`android/key.properties` (ignored by git) points to it. Back up both files
offline. Never commit them.

## Build

```bash
flutter clean
flutter build apk --release --split-per-abi   # arm64-v8a, armeabi-v7a, x86_64
flutter build apk --release                   # universal APK
```

Copy and rename into `dist/` (ignored by git):

| Built file | Release file |
|---|---|
| `app-arm64-v8a-release.apk` | `gym-quest-vX.Y.Z-arm64-v8a.apk` (64-bit phones) |
| `app-armeabi-v7a-release.apk` | `gym-quest-vX.Y.Z-armeabi-v7a.apk` (32-bit phones) |
| `app-release.apk` | `gym-quest-vX.Y.Z-universal.apk` (any phone) |

Then write `SHA256SUMS.txt` (`sha256sum *.apk > SHA256SUMS.txt`) and check the signature:

```bash
apksigner verify --print-certs dist/gym-quest-vX.Y.Z-universal.apk   # must not say "Android Debug"
```

## Publish

```bash
git tag vX.Y.Z && git push origin main --tags
gh release create vX.Y.Z dist/*.apk dist/SHA256SUMS.txt \
  --title "Gym Quest vX.Y.Z" --notes-file dist/RELEASE_NOTES.md
```

Split APKs get build numbers 1000×ABI + build, so a phone that started on a
split APK should keep using split APKs (switching to the universal one is
refused as a "downgrade").
