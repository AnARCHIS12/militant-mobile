#!/bin/bash
set -e

# Se positionner à la racine du projet
cd "$(dirname "$0")/.."

echo "=================================================="
echo "🚀 Compilation de la version Google Play Store"
echo "   - Provider par défaut : OneSignal (Google FCM)"
echo "   - Format : Android App Bundle (.aab) & APK"
echo "=================================================="

# 1. Compilation App Bundle (format requis pour Google Play Console)
echo "📦 Génération de l'App Bundle (.aab)..."
flutter build appbundle --release --dart-define=DEFAULT_PUSH_PROVIDER=onesignal --dart-define=FDROID_BUILD=false

mkdir -p dist
cp build/app/outputs/bundle/release/app-release.aab dist/militant-playstore.aab

# 2. Compilation APK Release (optionnel, pour tests internes)
echo "📱 Génération de l'APK Release Play Store..."
flutter build apk --release --dart-define=DEFAULT_PUSH_PROVIDER=onesignal --dart-define=FDROID_BUILD=false
cp build/app/outputs/flutter-apk/app-release.apk dist/militant-playstore.apk

echo ""
echo "✅ Compilation Play Store terminée avec succès !"
echo "   - App Bundle : dist/militant-playstore.aab (à téléverser sur la Google Play Console)"
echo "   - APK Test   : dist/militant-playstore.apk"
