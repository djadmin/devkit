#!/usr/bin/env bash
# test_install.sh — fresh-install smoke test for devkit installer on macOS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
HOME_DIR="$TMP_ROOT/home"
BREW_CADDYFILE="$TMP_ROOT/homebrew/etc/Caddyfile"
# New layout: binary lives on PATH (~/.local/bin), data lives in ~/.devkit — separate.
DEVKIT_BIN="$HOME_DIR/.local/bin/devkit"
DATA_DIR="$HOME_DIR/.devkit"

PASS=0
FAIL=0

cleanup() {
  if [[ -x "$DEVKIT_BIN" ]]; then
    DEVKIT_HOME="$DATA_DIR" "$DEVKIT_BIN" stop-all >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label"
    echo "        expected: $expected"
    echo "        actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label"
    echo "        expected to contain: $needle"
    echo "        got: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_file() {
  local label="$1" path="$2"
  if [[ -e "$path" ]]; then
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label"
    echo "        missing: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_no_file() {
  local label="$1" path="$2"
  if [[ ! -e "$path" ]]; then
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label"
    echo "        unexpected path: $path"
    FAIL=$((FAIL + 1))
  fi
}

wait_for_port_state() {
  local port="$1" desired="$2" attempts="${3:-60}"
  local i=0
  while (( i < attempts )); do
    local listening=""
    listening=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
    if [[ "$desired" == "listening" && -n "$listening" ]]; then
      printf '%s\n' "$listening"
      return 0
    fi
    if [[ "$desired" == "free" && -z "$listening" ]]; then
      return 0
    fi
    sleep 0.1
    (( i++ ))
  done
  return 1
}

mkdir -p "$HOME_DIR" "$(dirname "$BREW_CADDYFILE")"

echo "=== devkit installer smoke test ==="
echo "HOME=$HOME_DIR"
echo

echo "--- install ---"
install_out=$(
  HOME="$HOME_DIR" \
  DEVKIT_HOME="$DATA_DIR" \
  DEVKIT_REPO="$REPO_ROOT" \
  DEVKIT_LOCAL_WORKTREE=1 \
  DEVKIT_NONINTERACTIVE=1 \
  DEVKIT_SKIP_BREW_SERVICES=1 \
  DEVKIT_BREW_CADDYFILE="$BREW_CADDYFILE" \
  bash "$REPO_ROOT/install.sh" 2>&1
)
assert_contains "installer reports ready" "devkit is ready" "$install_out"
assert_file "binary linked onto PATH" "$DEVKIT_BIN"
assert_eq "binary is a symlink into the source dir" "$HOME_DIR/.local/share/devkit/bin/devkit" "$(readlink "$DEVKIT_BIN")"
assert_file "apps.json created in ~/.devkit" "$DATA_DIR/apps.json"
assert_file "Caddyfile created in ~/.devkit" "$DATA_DIR/Caddyfile"
assert_file "dashboard created in ~/.devkit" "$DATA_DIR/dashboard.html"
assert_no_file "no bare ~/devkit data dir polluting home" "$HOME_DIR/devkit"
assert_file "zshrc created" "$HOME_DIR/.zshrc"
assert_contains "zshrc updated with bin path" "$HOME_DIR/.local/bin" "$(cat "$HOME_DIR/.zshrc")"
assert_eq "brew caddyfile is symlink" "true" "$( [[ -L "$BREW_CADDYFILE" ]] && echo true || echo false )"
assert_eq "brew caddyfile points at devkit caddyfile" "$DATA_DIR/Caddyfile" "$(readlink "$BREW_CADDYFILE")"
assert_no_file "claude config untouched in non-interactive mode" "$HOME_DIR/.claude/CLAUDE.md"

echo "--- installed CLI smoke ---"
mkdir -p "$TMP_ROOT/app"
cat > "$TMP_ROOT/app/serve.sh" <<'SH'
#!/bin/sh
exec python3 -m http.server 5093 --bind 127.0.0.1
SH
chmod +x "$TMP_ROOT/app/serve.sh"

out=$(HOME="$HOME_DIR" DEVKIT_HOME="$DATA_DIR" "$DEVKIT_BIN" register smoke --path "$TMP_ROOT/app" --port 5093 --cmd "./serve.sh" 2>&1 || true)
assert_contains "register works after install" "smoke.localhost" "$out"

out=$(HOME="$HOME_DIR" DEVKIT_HOME="$DATA_DIR" "$DEVKIT_BIN" start smoke 2>&1 || true)
assert_contains "start works after install" "started smoke" "$out"
listener_pid=$(wait_for_port_state 5093 listening 60 || true)
assert_eq "pid file matches listener after install" "$listener_pid" "$(cat "$DATA_DIR/pids/smoke.pid")"

out=$(HOME="$HOME_DIR" DEVKIT_HOME="$DATA_DIR" "$DEVKIT_BIN" list 2>&1 || true)
line=$(printf '%s\n' "$out" | grep -E '^smoke[[:space:]]+5093[[:space:]]+' || true)
assert_contains "list shows smoke running after install" "running" "$line"

out=$(HOME="$HOME_DIR" DEVKIT_HOME="$DATA_DIR" "$DEVKIT_BIN" stop smoke 2>&1 || true)
assert_contains "stop works after install" "stopped smoke" "$out"
wait_for_port_state 5093 free 60
assert_eq "pid file removed after installed stop" "false" "$( [[ -f "$DATA_DIR/pids/smoke.pid" ]] && echo true || echo false )"

echo
echo "=== results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
