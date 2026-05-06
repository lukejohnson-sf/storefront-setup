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

IN_REPO=false
[[ -f .env.default ]] && IN_REPO=true

# ── 1. Node.js 24+ ───────────────────────────────────────────────────────────
step "Checking Node.js (required: 24+)"
NEED_NODE=false
if ! command -v node &>/dev/null; then
  NEED_NODE=true
else
  NODE_MAJOR=$(node --version | sed 's/v//' | cut -d. -f1)
  [[ "$NODE_MAJOR" -lt 24 ]] && NEED_NODE=true
fi

if [[ "$NEED_NODE" == true ]]; then
  echo -e "${YELLOW}  Node.js 24+ is required but not installed.${NC}"
  read -rp "  Install it now via nvm? [Y/n] " CONFIRM
  if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    err "Node.js 24+ is required. Re-run once it's installed."
  fi
  echo -e "${YELLOW}  Installing nvm...${NC}"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  # shellcheck source=/dev/null
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
  echo -e "${YELLOW}  Installing Node.js 24...${NC}"
  nvm install 24
  nvm use 24
fi
ok "Node.js $(node --version)"

# ── 2. pnpm ──────────────────────────────────────────────────────────────────
step "Checking pnpm"
if ! command -v pnpm &>/dev/null; then
  echo -e "${YELLOW}  pnpm is required but not installed.${NC}"
  read -rp "  Install it now via npm? [Y/n] " CONFIRM
  if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    err "pnpm is required. Re-run once it's installed."
  fi
  npm install -g pnpm
fi
ok "pnpm $(pnpm --version)"

# ── 3. GitHub CLI ────────────────────────────────────────────────────────────
step "Checking GitHub CLI (gh)"
if ! command -v gh &>/dev/null; then
  echo -e "${YELLOW}  GitHub CLI (gh) is required but not installed.${NC}"
  read -rp "  Install it now? [Y/n] " CONFIRM
  if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    err "GitHub CLI is required. Re-run once it's installed."
  fi
  GH_VERSION="2.70.0"
  ARCH=$(uname -m)
  [[ "$ARCH" == "arm64" ]] && GH_ARCH="arm64" || GH_ARCH="amd64"
  GH_PKG="gh_${GH_VERSION}_macOS_${GH_ARCH}.zip"
  echo -e "${YELLOW}  Downloading gh ${GH_VERSION}...${NC}"
  curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${GH_PKG}" -o /tmp/gh.zip
  unzip -q /tmp/gh.zip -d /tmp/gh-install
  sudo mv "/tmp/gh-install/gh_${GH_VERSION}_macOS_${GH_ARCH}/bin/gh" /usr/local/bin/gh
  rm -rf /tmp/gh.zip /tmp/gh-install
fi
ok "gh $(gh --version | head -1)"

step "Checking GitHub authentication"
if ! gh auth status &>/dev/null; then
  echo -e "${YELLOW}  You need to log in to GitHub. A browser window will open.${NC}"
  gh auth login
fi
ok "GitHub authenticated ($(gh auth status 2>&1 | grep 'Logged in' | xargs))"

if [[ "$IN_REPO" == true ]]; then
  # ── 5. .env setup ──────────────────────────────────────────────────────────
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

    sed -i.bak \
      -e "s|^PUBLIC__app__commerce__api__clientId=.*|PUBLIC__app__commerce__api__clientId=${CLIENT_ID}|" \
      -e "s|^PUBLIC__app__commerce__api__organizationId=.*|PUBLIC__app__commerce__api__organizationId=${ORG_ID}|" \
      -e "s|^PUBLIC__app__commerce__api__shortCode=.*|PUBLIC__app__commerce__api__shortCode=${SHORT_CODE}|" \
      .env
    rm -f .env.bak

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

  # ── 6. Install dependencies ────────────────────────────────────────────────
  step "Installing dependencies (pnpm install)"
  pnpm install
fi

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   Setup complete!                        ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

if [[ "$IN_REPO" == true ]]; then
  echo -e "  Start the dev server with:\n"
  echo -e "    ${BOLD}pnpm dev${NC}\n"
  echo -e "  Then open: ${BOLD}http://localhost:5173${NC}\n"
else
  echo -e "  All tools are ready. Now clone your storefront repo and re-run this"
  echo -e "  script from inside it to configure your .env and install dependencies.\n"
fi
