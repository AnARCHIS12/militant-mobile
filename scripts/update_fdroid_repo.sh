#!/bin/bash
set -e

# Se positionner à la racine du projet militant-flutter
cd "$(dirname "$0")/.."

echo "=================================================="
echo "📦 Mise à jour du Dépôt F-Droid Privé (joinmilitant)"
echo "=================================================="

# 1. Compilation de la version F-Droid
./scripts/build_fdroid.sh

# 2. Récupérer le code de version depuis pubspec.yaml
VERSION_CODE=$(grep 'version:' pubspec.yaml | sed -E 's/.*\+([0-9]+)/\1/')
echo "📌 Version code détecté : $VERSION_CODE"

FDROID_DIR="/home/anar/Bureau/joinmilitant/fdroid"
REPO_DIR="$FDROID_DIR/repo"

mkdir -p "$REPO_DIR"

# 3. Copier l'APK vers le dépôt F-Droid
APK_TARGET="$REPO_DIR/com.militant.militant_flutter_${VERSION_CODE}.apk"
echo "📂 Copie de l'APK vers $APK_TARGET..."
cp dist/militant-fdroid.apk "$APK_TARGET"

# 4. Copier les métadonnées et l'icône si nécessaire
mkdir -p "$REPO_DIR/icons"
cp assets/icon-512.png "$REPO_DIR/icons/com.militant.militant_flutter.${VERSION_CODE}.png" 2>/dev/null || true
cp assets/icon-512.png "$REPO_DIR/icons/icon.png" 2>/dev/null || true
# fdroidserver cherche repo_icon (icon.png) à la racine du dépôt, sinon il génère un placeholder
cp assets/icon-512.png "$FDROID_DIR/icon.png" 2>/dev/null || true

# 5. Mettre à jour l'index F-Droid signé via Docker
echo "🔄 Mise à jour et signature de l'index F-Droid..."
docker run --rm \
    -u $(id -u):$(id -g) \
    -e "GIT_CONFIG_COUNT=1" \
    -e "GIT_CONFIG_KEY_0=safe.directory" \
    -e "GIT_CONFIG_VALUE_0=*" \
    -v "$FDROID_DIR:/repo" \
    -w /repo \
    local-fdroidserver update

echo ""
echo "✅ Dépôt F-Droid mis à jour avec succès !"
echo "🌐 URL du Dépôt : https://joinmilitant.revlibertaire.com/fdroid/repo"
echo "🔑 Empreinte SHA-256 : 713E069D45D4883EE3F6A8A3EA7DEB4B7CFBDC2A71D0AB4E1201EB5B9CD4DEFC"
echo "📱 Lien 1-Clic : fdroidrepo://joinmilitant.revlibertaire.com/fdroid/repo?fingerprint=713E069D45D4883EE3F6A8A3EA7DEB4B7CFBDC2A71D0AB4E1201EB5B9CD4DEFC"
echo "💻 Page Web d'installation : https://joinmilitant.revlibertaire.com/fdroid/"
