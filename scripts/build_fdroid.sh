#!/bin/bash
set -e

# Se positionner à la racine du projet
cd "$(dirname "$0")/.."

echo "=================================================="
echo "🚀 Compilation de la version F-Droid / Autonome"
echo "   - Provider par défaut : ntfy (Libre & Dégooglisé)"
echo "   - Format : APK Release direct"
echo "=================================================="

echo "📱 Génération de l'APK Release F-Droid..."
flutter build apk --release --dart-define=DEFAULT_PUSH_PROVIDER=ntfy --dart-define=FDROID_BUILD=true

mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk dist/militant-fdroid.apk

echo ""
echo "✅ Compilation F-Droid terminée avec succès !"
echo "   - APK : dist/militant-fdroid.apk (à publier sur votre serveur ou F-Droid)"
