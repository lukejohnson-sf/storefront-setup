#!/usr/bin/env bash
set -e

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
step() { echo -e "\n${BOLD}${YELLOW}▶ $1${NC}"; }
err()  { echo -e "${RED}✗ $1${NC}"; exit 1; }

echo -e "\n${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Storefront Demo Setup                  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}\n"

# Must be run from inside the cloned montgomeryward repo
if [[ ! -f .env.default ]]; then
  err "Run this script from inside your cloned storefront repo (expected .env.default here)."
fi

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
step "Checking Homebrew"
if ! command -v brew &>/dev/null; then
  echo -e "${YELLOW}  Homebrew not found — installing (this takes ~2 minutes)...${NC}"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for Apple Silicon Macs
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi
ok "Homebrew $(brew --version | head -1)"

# ── 2. Node.js 24+ ───────────────────────────────────────────────────────────
step "Checking Node.js (required: 24+)"
NODE_OK=false
if command -v node &>/dev/null; then
  NODE_MAJOR=$(node --version | sed 's/v//' | cut -d. -f1)
  if [[ "$NODE_MAJOR" -ge 24 ]]; then
    NODE_OK=true
    ok "Node.js $(node --version)"
  fi
fi
if [[ "$NODE_OK" == false ]]; then
  echo -e "${YELLOW}  Installing Node.js 24 via Homebrew...${NC}"
  brew install node@24
  brew link node@24 --force --overwrite 2>/dev/null || true
  ok "Node.js $(node --version)"
fi

# ── 3. pnpm ──────────────────────────────────────────────────────────────────
step "Checking pnpm"
if ! command -v pnpm &>/dev/null; then
  echo -e "${YELLOW}  Installing pnpm via Homebrew...${NC}"
  brew install pnpm
fi
ok "pnpm $(pnpm --version)"

# ── 4. GitHub CLI ────────────────────────────────────────────────────────────
step "Checking GitHub CLI (gh)"
if ! command -v gh &>/dev/null; then
  echo -e "${YELLOW}  Installing gh via Homebrew...${NC}"
  brew install gh
fi
ok "gh $(gh --version | head -1)"

step "Checking GitHub authentication"
if ! gh auth status &>/dev/null; then
  echo -e "${YELLOW}  You need to log in to GitHub. A browser window will open.${NC}"
  gh auth login
fi
ok "GitHub authenticated ($(gh auth status 2>&1 | grep 'Logged in' | xargs))"

# ── 5. .env setup ────────────────────────────────────────────────────────────
step "Configuring environment (.env)"

SKIP_ENV=false
if [[ -f .env ]]; then
  echo -e "${YELLOW}  .env already exists.${NC}"
  read -rp "  Overwrite it with fresh values? [y/N] " OVERWRITE
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    ok ".env kept as-is"
    SKIP_ENV=true
  fi
fi

if [[ "$SKIP_ENV" == false ]]; then
  cp .env.default .env

  echo ""
  echo -e "  Enter your Commerce Cloud credentials."
  echo -e "  (Ask your admin if you don't have these.)\n"

  read -rp "  Commerce API Client ID:    " CLIENT_ID
  read -rp "  Organization ID:           " ORG_ID
  read -rp "  Short Code:                " SHORT_CODE
  read -rsp "  SLAS Secret (hidden):      " SLAS_SECRET
  echo ""

  # Write values into .env
  sed -i.bak \
    -e "s|^PUBLIC__app__commerce__api__clientId=.*|PUBLIC__app__commerce__api__clientId=${CLIENT_ID}|" \
    -e "s|^PUBLIC__app__commerce__api__organizationId=.*|PUBLIC__app__commerce__api__organizationId=${ORG_ID}|" \
    -e "s|^PUBLIC__app__commerce__api__shortCode=.*|PUBLIC__app__commerce__api__shortCode=${SHORT_CODE}|" \
    .env
  rm -f .env.bak

  # COMMERCE_API_SLAS_SECRET may be commented out in .env.default — handle all cases
  if grep -q "^#\s*COMMERCE_API_SLAS_SECRET" .env; then
    sed -i.bak "s|^#\s*COMMERCE_API_SLAS_SECRET.*|COMMERCE_API_SLAS_SECRET=${SLAS_SECRET}|" .env
    rm -f .env.bak
  elif grep -q "^COMMERCE_API_SLAS_SECRET" .env; then
    sed -i.bak "s|^COMMERCE_API_SLAS_SECRET=.*|COMMERCE_API_SLAS_SECRET=${SLAS_SECRET}|" .env
    rm -f .env.bak
  else
    echo "" >> .env
    echo "COMMERCE_API_SLAS_SECRET=${SLAS_SECRET}" >> .env
  fi

  ok ".env configured"
fi

# ── 6. Install dependencies ───────────────────────────────────────────────────
step "Installing dependencies (pnpm install)"
pnpm install

# ── 7. Done ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   Setup complete!                        ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Start the dev server with:\n"
echo -e "    ${BOLD}pnpm dev${NC}\n"
echo -e "  Then open: ${BOLD}http://localhost:5173${NC}\n"
