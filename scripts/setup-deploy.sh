#!/bin/bash
# ============================================================
# Twitter Clone — Setup initial des secrets de deploy
# A lancer une seule fois sur le Mac de build.
# ============================================================

set -e

CONF_DIR="$HOME/.twitter-clone-ci"
CONF_FILE="$CONF_DIR/.env"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Twitter Clone — Setup deploy${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

mkdir -p "$CONF_DIR"
chmod 700 "$CONF_DIR"

# ── Valeurs par defaut ──
DEFAULT_KEY_ID="WEMZTTQYT437"
DEFAULT_ISSUER_ID="94e1e15b-0ba8-4988-93d4-fc7859bfcf50"
DEFAULT_KEY_PATH="$HOME/private_keys/AuthKey_WEMZTTQYT437.p8"

read -rp "ASC_KEY_ID [$DEFAULT_KEY_ID]: " KEY_ID
KEY_ID="${KEY_ID:-$DEFAULT_KEY_ID}"

read -rp "ASC_ISSUER_ID [$DEFAULT_ISSUER_ID]: " ISSUER_ID
ISSUER_ID="${ISSUER_ID:-$DEFAULT_ISSUER_ID}"

read -rp "ASC_KEY_PATH [$DEFAULT_KEY_PATH]: " KEY_PATH
KEY_PATH="${KEY_PATH:-$DEFAULT_KEY_PATH}"

echo ""
echo -e "${YELLOW}(Optionnel) Certificat P12 pour CI — laisse vide pour utiliser le keychain local${NC}"
read -rp "IOS_DIST_P12_BASE64 (laisser vide): " P12_B64
read -rp "IOS_DIST_P12_PASSWORD (laisser vide): " P12_PASS

# ── Ecrire la config ──
cat > "$CONF_FILE" << EOF
# Twitter Clone — secrets de deploy
# Genere le $(date)

ASC_KEY_ID=$KEY_ID
ASC_ISSUER_ID=$ISSUER_ID
ASC_KEY_PATH=$KEY_PATH

IOS_DIST_P12_BASE64=$P12_B64
IOS_DIST_P12_PASSWORD=$P12_PASS
EOF

chmod 600 "$CONF_FILE"

echo ""
echo -e "${GREEN}Config sauvegardee dans $CONF_FILE${NC}"

# ── Verifier le certificat dans le keychain ──
echo ""
echo -e "${BLUE}Verification du certificat de signature...${NC}"
if security find-identity -v -p codesigning | grep -q "Apple Distribution.*J9KLFLQ7FL"; then
    echo -e "${GREEN}  Apple Distribution: J9KLFLQ7FL — OK${NC}"
else
    echo -e "${YELLOW}  Attention: certificat Apple Distribution introuvable.${NC}"
    echo "  Lance Xcode → Settings → Accounts pour le telecharger."
fi

# ── Installer les gems ──
echo ""
echo -e "${BLUE}Installation des gems Fastlane...${NC}"
cd "$(dirname "$0")/../ios"
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"
bundle install
echo -e "${GREEN}  Gems OK${NC}"

echo ""
echo -e "${GREEN}Setup termine !${NC}"
echo ""
echo "Pour deployer :"
echo "  ./scripts/deploy.sh 1.0.1"
echo "  ./scripts/deploy.sh 1.1.0 \"feat: dark mode\" --production"
echo ""
