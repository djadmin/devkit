#!/usr/bin/env bash
# test_registry.sh — integration tests for devkit registry operations.
# Runs against a temporary DEVKIT_HOME so nothing touches real pm2 or Caddy.
# Usage: bash test/test_registry.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVKIT="$SCRIPT_DIR/../bin/devkit"
TMP_HOME=$(mktemp -d)
export DEVKIT_HOME="$TMP_HOME"

PASS=0
FAIL=0

cleanup() { rm -rf "$TMP_HOME"; }
trap cleanup EXIT

# ---------- helpers ----------

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

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label"
    echo "        expected NOT to contain: $needle"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit() {
  local label="$1" expected_code="$2"
  shift 2
  set +e
  "$@" >/dev/null 2>&1
  local code=$?
  set -e
  if [[ "$code" == "$expected_code" ]]; then
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label (exit $code, expected $expected_code)"
    FAIL=$((FAIL + 1))
  fi
}

# ---------- tests ----------

echo "=== devkit integration tests ==="
echo "DEVKIT_HOME=$TMP_HOME"
echo

# -- version --
echo "--- version ---"
out=$("$DEVKIT" version)
assert_contains "version prints semver" "devkit 0." "$out"

# -- bootstrap creates registry --
echo "--- fresh registry ---"
# Just running list should create a fresh registry
out=$("$DEVKIT" list 2>&1 || true)
assert_eq "apps.json created" "true" "$( [[ -f "$TMP_HOME/apps.json" ]] && echo true || echo false )"

count=$(jq '.apps | length' "$TMP_HOME/apps.json")
assert_eq "registry starts empty" "0" "$count"

default_port=$(jq '.proxyPort' "$TMP_HOME/apps.json")
assert_eq "default proxyPort is 8080" "8080" "$default_port"

# -- register --
echo "--- register ---"
mkdir -p "$TMP_HOME/fake-app"
out=$("$DEVKIT" register --name testapp --path "$TMP_HOME/fake-app" --port 5000 --cmd "node server.js --port 5000" 2>&1 || true)
assert_contains "register prints URL" "testapp.localhost" "$out"

count=$(jq '.apps | length' "$TMP_HOME/apps.json")
assert_eq "one app registered" "1" "$count"

name=$(jq -r '.apps[0].name' "$TMP_HOME/apps.json")
assert_eq "app name is testapp" "testapp" "$name"

port=$(jq '.apps[0].port' "$TMP_HOME/apps.json")
assert_eq "app port is 5000" "5000" "$port"

hostname=$(jq -r '.apps[0].hostname' "$TMP_HOME/apps.json")
assert_eq "hostname is testapp.localhost" "testapp.localhost" "$hostname"

# -- show --
echo "--- show ---"
out=$("$DEVKIT" show testapp)
assert_contains "show includes name" "testapp" "$out"
assert_contains "show includes port" "5000" "$out"

# -- register second app --
echo "--- register second app ---"
mkdir -p "$TMP_HOME/fake-app2"
out=$("$DEVKIT" register --name second --path "$TMP_HOME/fake-app2" --port 5001 --cmd "npm start --port 5001" 2>&1 || true)
count=$(jq '.apps | length' "$TMP_HOME/apps.json")
assert_eq "two apps registered" "2" "$count"

# -- duplicate port rejected --
echo "--- duplicate port ---"
mkdir -p "$TMP_HOME/fake-app3"
assert_exit "duplicate port rejected" 1 "$DEVKIT" register --name third --path "$TMP_HOME/fake-app3" --port 5000 --cmd "x --port 5000"

# -- rename --
echo "--- rename ---"
out=$("$DEVKIT" rename testapp renamed-app 2>&1 || true)
assert_contains "rename prints new name" "renamed-app" "$out"

old=$(jq -r '[.apps[] | select(.name=="testapp")] | length' "$TMP_HOME/apps.json")
assert_eq "old name gone" "0" "$old"

new_host=$(jq -r '.apps[] | select(.name=="renamed-app") | .hostname' "$TMP_HOME/apps.json")
assert_eq "hostname updated" "renamed-app.localhost" "$new_host"

# -- list --
echo "--- list ---"
out=$("$DEVKIT" list 2>&1 || true)
assert_contains "list shows renamed-app" "renamed-app" "$out"
assert_contains "list shows second" "second" "$out"
assert_not_contains "list has no testapp" "testapp" "$out"

# -- remove --
echo "--- remove ---"
"$DEVKIT" remove second >/dev/null 2>&1 || true
count=$(jq '.apps | length' "$TMP_HOME/apps.json")
assert_eq "one app after remove" "1" "$count"

# -- re-register on freed port --
echo "--- re-register freed port ---"
mkdir -p "$TMP_HOME/fake-app4"
out=$("$DEVKIT" register --name reuse --path "$TMP_HOME/fake-app4" --port 5001 --cmd "x --port 5001" 2>&1 || true)
count=$(jq '.apps | length' "$TMP_HOME/apps.json")
assert_eq "port reuse works" "2" "$count"

# -- Caddyfile generated --
echo "--- generated files ---"
assert_eq "Caddyfile exists" "true" "$( [[ -f "$TMP_HOME/Caddyfile" ]] && echo true || echo false )"
assert_eq "dashboard.html exists" "true" "$( [[ -f "$TMP_HOME/dashboard.html" ]] && echo true || echo false )"

caddy_content=$(cat "$TMP_HOME/Caddyfile")
assert_contains "Caddyfile has renamed-app" "renamed-app.localhost" "$caddy_content"
assert_contains "Caddyfile has reuse" "reuse.localhost" "$caddy_content"
assert_contains "Caddyfile uses port 8080" ":8080" "$caddy_content"

dash_content=$(cat "$TMP_HOME/dashboard.html")
assert_contains "dashboard has renamed-app" "renamed-app" "$dash_content"
assert_contains "dashboard has status dot" "dot-unknown" "$dash_content"

# -- paths --
echo "--- paths ---"
out=$("$DEVKIT" paths)
assert_contains "paths shows DEVKIT_HOME" "$TMP_HOME" "$out"

# -- unknown command --
echo "--- error handling ---"
assert_exit "unknown command exits 2" 2 "$DEVKIT" bogus

# ---------- summary ----------

echo
echo "=== results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
