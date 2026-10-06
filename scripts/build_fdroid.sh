#!/bin/bash
set -e

# Se positionner à la racine du projet
cd "$(dirname "$0")/.."

# F-Droid must not include the proprietary OneSignal Android plugin. Flutter
# normally registers every plugin listed in pubspec.yaml, so use the dedicated
# manifest only for this build and restore the developer/Play configuration on
# exit (including after a failed build).
ORIGINAL_PUBSPEC=$(mktemp)
ORIGINAL_LOCK=$(mktemp)
cp pubspec.yaml "$ORIGINAL_PUBSPEC"
cp pubspec.lock "$ORIGINAL_LOCK"
restore_pubspec() {
    build_status=$?
    cp "$ORIGINAL_PUBSPEC" pubspec.yaml
    cp "$ORIGINAL_LOCK" pubspec.lock
    rm -f "$ORIGINAL_PUBSPEC" "$ORIGINAL_LOCK"
    flutter pub get >/dev/null 2>&1 || true
    exit "$build_status"
}
trap restore_pubspec EXIT
cp pubspec_fdroid.yaml pubspec.yaml

echo "=================================================="
echo "🚀 Compilation de la version F-Droid / Autonome"
echo "   - Provider par défaut : ntfy (Libre & Dégooglisé)"
echo "   - Format : APK Release direct"
echo "=================================================="

echo "📱 Génération de l'APK Release F-Droid..."
flutter pub get
flutter build apk --release --dart-define=DEFAULT_PUSH_PROVIDER=ntfy --dart-define=FDROID_BUILD=true

mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk dist/militant-fdroid.apk

echo ""
echo "✅ Compilation F-Droid terminée avec succès !"
echo "   - APK : dist/militant-fdroid.apk (à publier sur votre serveur ou F-Droid)"
