#!/usr/bin/env bash
# devkit installer
# Usage: curl -fsSL https://raw.githubusercontent.com/djadmin/devkit/main/install.sh | bash

set -euo pipefail

DEVKIT_DIR="${DEVKIT_DIR:-$HOME/devkit}"
DEVKIT_REPO="${DEVKIT_REPO:-https://github.com/djadmin/devkit.git}"
DEVKIT_NONINTERACTIVE="${DEVKIT_NONINTERACTIVE:-0}"
DEVKIT_SKIP_BREW_SERVICES="${DEVKIT_SKIP_BREW_SERVICES:-0}"
DEVKIT_SKIP_CLAUDE_SETUP="${DEVKIT_SKIP_CLAUDE_SETUP:-0}"
DEVKIT_LOCAL_WORKTREE="${DEVKIT_LOCAL_WORKTREE:-0}"

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
if [[ "$DEVKIT_LOCAL_WORKTREE" == "1" && -d "$DEVKIT_REPO" ]]; then
  rm -rf "$DEVKIT_DIR"
  mkdir -p "$(dirname "$DEVKIT_DIR")"
  cp -R "$DEVKIT_REPO" "$DEVKIT_DIR"
  ok "devkit copied from local worktree to $DEVKIT_DIR"
elif [[ -d "$DEVKIT_DIR/.git" ]]; then
  git -C "$DEVKIT_DIR" pull --quiet
  ok "devkit updated at $DEVKIT_DIR"
else
  git clone --quiet "$DEVKIT_REPO" "$DEVKIT_DIR"
  ok "devkit installed at $DEVKIT_DIR"
fi

# ── PATH ─────────────────────────────────────────────────────────────────────
step "Setting up PATH..."
EXPORT_LINE="export PATH=\"$DEVKIT_DIR/bin:\$PATH\""
added=0
rc_candidates=("$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc")
has_existing_rc=0
for rc in "${rc_candidates[@]}"; do
  [[ -f "$rc" ]] || continue
  has_existing_rc=1
  if ! grep -q 'devkit/bin' "$rc" 2>/dev/null; then
    echo "" >> "$rc"
    echo "# devkit" >> "$rc"
    echo "$EXPORT_LINE" >> "$rc"
    ok "Added to $rc"
    added=1
  fi
done
if [[ $has_existing_rc -eq 0 ]]; then
  rc="$HOME/.zshrc"
  echo "# devkit" > "$rc"
  echo "$EXPORT_LINE" >> "$rc"
  ok "Created $rc"
  added=1
fi
[[ $added -eq 0 ]] && ok "PATH already configured"
export PATH="$DEVKIT_DIR/bin:$PATH"

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

# ── bootstrap ────────────────────────────────────────────────────────────────
step "Bootstrapping devkit..."
"$DEVKIT_DIR/bin/devkit" bootstrap
ok "devkit bootstrapped"

# ── Caddy service ────────────────────────────────────────────────────────────
step "Starting Caddy..."
if [[ "$DEVKIT_SKIP_BREW_SERVICES" == "1" ]]; then
  warn "Skipping brew services start (DEVKIT_SKIP_BREW_SERVICES=1)"
elif curl -sf http://localhost:2019/config/ >/dev/null 2>&1; then
  ok "Caddy already running"
elif brew services list | grep -q "caddy.*started"; then
  ok "Caddy already running (brew services)"
else
  brew services start caddy
  ok "Caddy started"
fi

# ── done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}${BOLD}devkit is ready.${NC}"
echo ""
echo -e "  Open your dashboard: ${BOLD}http://dash.localhost${NC}"
echo ""
echo -e "  Register an app (from inside your project directory):"
dim "    devkit register myapp --port 3000 --cmd \"npm start\""
dim "    devkit start myapp"
echo ""
echo -e "  Already have something running elsewhere?"
dim "    devkit register existing-app --port 3000 --managed-by external"
echo ""

# ── Claude integration ───────────────────────────────────────────────────────
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
SNIPPET='## Local Web Apps — devkit
When building any local web app, register it with devkit:

  devkit register <slug> --port <port> --cmd "<start-cmd>"
  devkit start <slug>

Apps are then reachable at http://<slug>.localhost'

echo -e "  ${BOLD}Wire into Claude Code (recommended):${NC}"
echo ""

if [[ "$DEVKIT_SKIP_CLAUDE_SETUP" == "1" || "$DEVKIT_NONINTERACTIVE" == "1" ]]; then
  dim "Skipping Claude Code wiring in non-interactive mode"
  echo ""
elif [[ -f "$CLAUDE_MD" ]] && grep -q 'devkit' "$CLAUDE_MD"; then
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
