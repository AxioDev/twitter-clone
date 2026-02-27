#!/bin/bash
# ============================================================
# Twitter Clone — Deploy vers TestFlight / App Store
#
# Usage :
#   ./scripts/deploy.sh 1.0.1
#   ./scripts/deploy.sh 1.0.1 "feat: dark mode"
#   ./scripts/deploy.sh 1.1.0 "release: v1.1.0" --production
#
# Ce script :
#   1. Verifie les secrets
#   2. Bumpe la version dans pubspec.yaml
#   3. Commit + tag + push sur GitHub
#   4. flutter build ipa --release
#   5. Upload TestFlight/App Store via Fastlane
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONF_FILE="$HOME/.twitter-clone-ci/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Charger les secrets ──
if [ ! -f "$CONF_FILE" ]; then
    echo -e "${RED}Config introuvable : $CONF_FILE${NC}"
    echo "Lance d'abord : ./scripts/setup-deploy.sh"
    exit 1
fi
set -a && source "$CONF_FILE" && set +a

# ── Verifier les secrets requis ──
preflight() {
    echo -e "${BLUE}Verification des secrets...${NC}"
    missing=()
    for v in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do
        [ -z "${!v:-}" ] && missing+=("$v")
    done
    if [ "${#missing[@]}" -ne 0 ]; then
        echo -e "${RED}Secrets manquants : ${missing[*]}${NC}"
        exit 1
    fi
    if [ ! -f "$ASC_KEY_PATH" ]; then
        echo -e "${RED}Cle API introuvable : $ASC_KEY_PATH${NC}"
        exit 1
    fi
    if ! security find-identity -v -p codesigning | grep -q "Apple Distribution.*J9KLFLQ7FL"; then
        echo -e "${RED}Certificat 'Apple Distribution: J9KLFLQ7FL' introuvable dans le keychain.${NC}"
        exit 1
    fi
    echo -e "${GREEN}  OK${NC}"
}

# ── Arguments ──
if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 <version> [message] [--production]${NC}"
    echo "  Ex: $0 1.0.1"
    echo "  Ex: $0 1.1.0 \"feat: dark mode\" --production"
    exit 1
fi

VERSION="$1"
COMMIT_MSG="${2:-release: v$VERSION}"
TAG="v$VERSION"

PRODUCTION_MODE=0
for arg in "$@"; do [ "$arg" = "--production" ] && PRODUCTION_MODE=1; done

if [ "$PRODUCTION_MODE" -eq 1 ]; then
    echo -e "\n${RED}========================================"
    echo -e "  PRODUCTION DEPLOY - App Store"
    echo -e "========================================${NC}"
    read -rp "Confirmer PRODUCTION ? (oui/non) : " CONFIRM
    [ "$CONFIRM" != "oui" ] && echo -e "${YELLOW}Annule.${NC}" && exit 0
fi

cd "$PROJECT_DIR"

# ── Branch check ──
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "main" ]; then
    echo -e "${YELLOW}Branche '$BRANCH' (pas main).${NC}"
    read -rp "Continuer ? (o/n) : " CONT
    [[ ! "$CONT" =~ ^[oOyY]$ ]] && exit 0
fi

# ── Tag check ──
if git tag -l "$TAG" | grep -q "$TAG"; then
    echo -e "${RED}Tag $TAG existe deja !${NC}"; exit 1
fi

preflight

# ── Calculer le build number ──
CURRENT_BUILD=$(grep '^version:' pubspec.yaml | sed 's/.*+//')
NEW_BUILD=$((CURRENT_BUILD + 1))

echo -e "\n${GREEN}========================================"
echo -e "  Twitter Clone v$VERSION (build $NEW_BUILD)"
echo -e "========================================${NC}\n"

# ── 1. Bump version ──
sed -i '' "s|^version:.*|version: $VERSION+$NEW_BUILD|" pubspec.yaml
echo -e "${GREEN}[1/4] pubspec.yaml → version: $VERSION+$NEW_BUILD${NC}"

# ── 2. Commit + Tag + Push ──
git add pubspec.yaml
git commit -m "$COMMIT_MSG"
git tag "$TAG"
git push origin "$BRANCH"
git push origin "$TAG"
echo -e "${GREEN}[2/4] Push $TAG sur GitHub${NC}"

# ── 3. Flutter build IPA ──
echo -e "${BLUE}[3/4] flutter build ipa --release...${NC}"

# Deverrouiller les keychains pour codesign (evite errSecInternalComponent)
# La cle privee Apple Distribution est dans ci_signing_test (mot de passe: ci_temp_password)
CI_KEYCHAIN="$HOME/Library/Keychains/ci_signing_test.keychain-db"
LOGIN_KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# S'assurer que ci_signing_test est dans la liste de recherche
security list-keychains -s "$CI_KEYCHAIN" "$LOGIN_KEYCHAIN" /Library/Keychains/System.keychain 2>/dev/null || true
security unlock-keychain -p "ci_temp_password" "$CI_KEYCHAIN" 2>/dev/null || true

if [ -n "${LOGIN_KEYCHAIN_PASSWORD:-}" ]; then
    security unlock-keychain -p "$LOGIN_KEYCHAIN_PASSWORD" "$LOGIN_KEYCHAIN" 2>/dev/null || true
fi
echo -e "${GREEN}  Keychains deverrouilles${NC}"

flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build ipa --release --build-number="$NEW_BUILD"
echo -e "${GREEN}[3/4] Build IPA OK${NC}"

# ── 4. Upload via Fastlane ──
IOS_LANE="beta"
IOS_TARGET="TestFlight"
[ "$PRODUCTION_MODE" -eq 1 ] && IOS_LANE="release" && IOS_TARGET="App Store"

echo -e "${BLUE}[4/4] Upload $IOS_TARGET via Fastlane...${NC}"
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"
export FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT=60

cd ios
set -o pipefail
bundle exec fastlane "$IOS_LANE" 2>&1 | tee /tmp/fastlane_twitter.log
cd ..

if grep -Eq "(Successfully uploaded|envoye sur|finished successfully)" /tmp/fastlane_twitter.log; then
    echo -e "${GREEN}[4/4] Upload $IOS_TARGET OK${NC}"
else
    echo -e "${RED}[4/4] Upload FAILED — voir /tmp/fastlane_twitter.log${NC}"
    exit 1
fi

# ── Done ──
echo -e "\n${GREEN}========================================"
echo -e "  Twitter Clone v$VERSION deploye !"
echo -e "========================================${NC}"
[ "$PRODUCTION_MODE" -eq 1 ] && echo "  iOS → App Store (soumis pour review)" || echo "  iOS → TestFlight (dispo dans ~5 min)"
echo ""
