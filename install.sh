#!/usr/bin/env bash
# devkit installer
# Usage: curl -fsSL https://raw.githubusercontent.com/djadmin/devkit/main/install.sh | bash

set -euo pipefail

DEVKIT_DIR="$HOME/devkit"
DEVKIT_REPO="https://github.com/djadmin/devkit.git"

# ── colours ──────────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
DIM='\033[2m'
NC='\033[0m'

step()    { echo -e "\n${BOLD}$*${NC}"; }
ok()      { echo -e "  ${GREEN}✓${NC}  $*"; }
warn()    { echo -e "  ${YELLOW}!${NC}  $*"; }
dim()     { echo -e "  ${DIM}$*${NC}"; }

# ── header ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  devkit installer${NC}"
echo -e "${DIM}  github.com/djadmin/devkit${NC}"
echo ""

# ── macOS check ──────────────────────────────────────────────────────────────
[[ "$(uname)" == "Darwin" ]] || { echo "devkit requires macOS."; exit 1; }

# ── Homebrew ─────────────────────────────────────────────────────────────────
step "Checking Homebrew..."
if command -v brew >/dev/null 2>&1; then
  ok "Homebrew already installed"
else
  warn "Homebrew not found — installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ok "Homebrew installed"
fi

# ── Clone or update devkit ───────────────────────────────────────────────────
step "Installing devkit..."
if [[ -d "$DEVKIT_DIR/.git" ]]; then
  git -C "$DEVKIT_DIR" pull --quiet
  ok "devkit updated at $DEVKIT_DIR"
else
  git clone --quiet "$DEVKIT_REPO" "$DEVKIT_DIR"
  ok "devkit installed at $DEVKIT_DIR"
fi

# ── PATH ─────────────────────────────────────────────────────────────────────
step "Setting up PATH..."
EXPORT_LINE='export PATH="$HOME/devkit/bin:$PATH"'
added=0
for rc in "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc"; do
  [[ -f "$rc" ]] || continue
  if ! grep -q 'devkit/bin' "$rc" 2>/dev/null; then
    echo "" >> "$rc"
    echo "# devkit" >> "$rc"
    echo "$EXPORT_LINE" >> "$rc"
    ok "Added to $rc"
    added=1
  fi
done
[[ $added -eq 0 ]] && ok "PATH already configured"
export PATH="$HOME/devkit/bin:$PATH"

# ── jq ───────────────────────────────────────────────────────────────────────
step "Checking dependencies..."
if command -v jq >/dev/null 2>&1; then
  ok "jq already installed"
else
  brew install jq --quiet
  ok "jq installed"
fi

# ── Caddy ────────────────────────────────────────────────────────────────────
if command -v caddy >/dev/null 2>&1; then
  ok "Caddy already installed"
else
  brew install caddy --quiet
  ok "Caddy installed"
fi

# ── pm2 ──────────────────────────────────────────────────────────────────────
if command -v pm2 >/dev/null 2>&1; then
  ok "pm2 already installed"
elif command -v npm >/dev/null 2>&1; then
  npm install -g pm2 --silent
  ok "pm2 installed"
else
  warn "Node/npm not found — install Node.js then run: npm install -g pm2"
fi

# ── bootstrap ────────────────────────────────────────────────────────────────
step "Bootstrapping devkit..."
"$DEVKIT_DIR/bin/devkit" bootstrap
ok "devkit bootstrapped"

# ── Caddy service ────────────────────────────────────────────────────────────
step "Starting Caddy..."
if brew services list | grep -q "caddy.*started"; then
  ok "Caddy already running"
else
  brew services start caddy
  ok "Caddy started"
fi

# ── pm2 startup ──────────────────────────────────────────────────────────────
step "Setting up pm2 startup..."
if command -v pm2 >/dev/null 2>&1; then
  warn "Run these two commands to make pm2 survive reboots:"
  echo ""
  dim "    pm2 startup"
  dim "    # copy/paste the command it prints, then:"
  dim "    pm2 save"
  echo ""
fi

# ── done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}${BOLD}devkit is ready.${NC}"
echo ""
echo -e "  Open your dashboard: ${BOLD}http://dash.localhost:8080${NC}"
echo ""
echo -e "  Register an app:"
dim "    devkit register --name myapp --path ~/code/myapp --port 3000 --cmd \"npm start\""
dim "    devkit start myapp"
echo ""

# ── Claude integration ───────────────────────────────────────────────────────
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
SNIPPET='## Local Web Apps — devkit
When building any local web app, register it with devkit:

  devkit register --name <slug> --path <abs-path> --port <port> --cmd "<start-cmd>"
  devkit start <slug>

Apps are then reachable at http://<slug>.localhost:8080'

echo -e "  ${BOLD}Wire into Claude Code (recommended):${NC}"
echo ""

if [[ -f "$CLAUDE_MD" ]] && grep -q 'devkit' "$CLAUDE_MD"; then
  ok "devkit already in $CLAUDE_MD — nothing to do"
  echo ""
else
  echo -e "  Add this to ${BOLD}~/.claude/CLAUDE.md${NC} so Claude registers apps automatically:"
  echo ""
  echo "  ┌─────────────────────────────────────────────────────────┐"
  while IFS= read -r line; do
    printf "  │  %-55s│\n" "$line"
  done <<< "$SNIPPET"
  echo "  └─────────────────────────────────────────────────────────┘"
  echo ""

  if [[ -f "$CLAUDE_MD" ]]; then
    printf "  Auto-append to %s? [y/N] " "$CLAUDE_MD"
    read -r answer </dev/tty
    if [[ "${answer,,}" == "y" ]]; then
      echo "" >> "$CLAUDE_MD"
      echo "$SNIPPET" >> "$CLAUDE_MD"
      ok "Added to $CLAUDE_MD"
    else
      dim "Skipped. Copy the block above and paste it into ~/.claude/CLAUDE.md"
    fi
  else
    printf "  Create %s with this snippet? [y/N] " "$CLAUDE_MD"
    read -r answer </dev/tty
    if [[ "${answer,,}" == "y" ]]; then
      mkdir -p "$HOME/.claude"
      echo "$SNIPPET" > "$CLAUDE_MD"
      ok "Created $CLAUDE_MD"
    else
      dim "Skipped. Copy the block above and paste it into ~/.claude/CLAUDE.md"
    fi
  fi
fi

echo ""
echo -e "  ${DIM}Docs: https://github.com/djadmin/devkit${NC}"
echo ""
