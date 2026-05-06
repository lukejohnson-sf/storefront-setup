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
if ! command -v node &>/dev/null; then
  err "Node.js not found. Install it from https://nodejs.org and re-run this script."
fi
NODE_MAJOR=$(node --version | sed 's/v//' | cut -d. -f1)
if [[ "$NODE_MAJOR" -lt 24 ]]; then
  err "Node.js $(node --version) is too old (need 24+). Update at https://nodejs.org and re-run."
fi
ok "Node.js $(node --version)"

# ── 2. pnpm ──────────────────────────────────────────────────────────────────
step "Checking pnpm"
if ! command -v pnpm &>/dev/null; then
  err "pnpm not found. Install it with: npm install -g pnpm"
fi
ok "pnpm $(pnpm --version)"

# ── 3. GitHub CLI ────────────────────────────────────────────────────────────
step "Checking GitHub CLI (gh)"
if ! command -v gh &>/dev/null; then
  err "GitHub CLI not found. Install it from https://cli.github.com and re-run."
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
