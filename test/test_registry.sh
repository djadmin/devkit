#!/usr/bin/env bash
# test_registry.sh — integration tests for devkit registry operations.
# Runs against a temporary DEVKIT_HOME so nothing touches your real registry or Caddy.
# Usage: bash test/test_registry.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVKIT="$SCRIPT_DIR/../bin/devkit"
TMP_HOME=$(mktemp -d)
export DEVKIT_HOME="$TMP_HOME"

PASS=0
FAIL=0

cleanup() {
  "$DEVKIT" stop-all >/dev/null 2>&1 || true
  rm -rf "$TMP_HOME"
}
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

assert_nonempty() {
  local label="$1" value="$2"
  if [[ -n "$value" ]]; then
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label"
    FAIL=$((FAIL + 1))
  fi
}

wait_for_port_state() {
  local port="$1" desired="$2" attempts="${3:-40}"
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

assert_process_alive() {
  local label="$1" pid="$2"
  if kill -0 "$pid" 2>/dev/null; then
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label"
    FAIL=$((FAIL + 1))
  fi
}

assert_process_dead() {
  local label="$1" pid="$2"
  if kill -0 "$pid" 2>/dev/null; then
    echo "  FAIL  $label"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  fi
}

wait_for_pid_exit() {
  local pid="$1" attempts="${2:-60}"
  local i=0
  while kill -0 "$pid" 2>/dev/null && (( i < attempts )); do
    sleep 0.1
    (( i++ ))
  done
  ! kill -0 "$pid" 2>/dev/null
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
assert_eq "default proxyPort is 80" "80" "$default_port"

# -- read-only list --
echo "--- read-only list ---"
RO_HOME=$(mktemp -d)
mkdir -p "$RO_HOME/pids" "$RO_HOME/logs"
cat > "$RO_HOME/apps.json" <<'JSON'
{"version":1,"proxyPort":80,"tld":"localhost","dashboardHost":"dash","apps":[{"name":"frozen","hostname":"frozen.localhost","port":5009,"path":null,"repo":null,"claudeMd":null,"startCmd":null,"description":"","managedBy":"external"}]}
JSON
chmod 555 "$RO_HOME"
set +e
read_only_out=$(DEVKIT_HOME="$RO_HOME" "$DEVKIT" list 2>&1)
read_only_code=$?
set -e
chmod 755 "$RO_HOME"
rm -rf "$RO_HOME"
assert_eq "list works when registry dir is not writable" "0" "$read_only_code"
assert_contains "read-only list prints app" "frozen" "$read_only_out"

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

# -- positional name syntax --
echo "--- positional register syntax ---"
mkdir -p "$TMP_HOME/fake-positional"
out=$("$DEVKIT" register positional-app --path "$TMP_HOME/fake-positional" --port 5099 --cmd "node s.js --port 5099" 2>&1 || true)
assert_contains "positional register prints URL" "positional-app.localhost" "$out"
pos_name=$(jq -r '.apps[] | select(.name=="positional-app") | .name' "$TMP_HOME/apps.json")
assert_eq "positional name stored correctly" "positional-app" "$pos_name"
# clean up
"$DEVKIT" remove positional-app >/dev/null 2>&1 || true

# -- default path (--path omitted, should use CWD) --
echo "--- default path = CWD ---"
mkdir -p "$TMP_HOME/cwd-test" && cd "$TMP_HOME/cwd-test"
out=$("$DEVKIT" register cwd-app --port 5098 --cmd "node s.js" 2>&1 || true)
assert_contains "register without --path succeeds" "cwd-app.localhost" "$out"
stored_path=$(jq -r '.apps[] | select(.name=="cwd-app") | .path' "$TMP_HOME/apps.json")
expected_cwd_path="$(cd "$TMP_HOME/cwd-test" && pwd -P)"
assert_eq "path defaults to CWD" "$expected_cwd_path" "$stored_path"
"$DEVKIT" remove cwd-app >/dev/null 2>&1 || true
cd "$SCRIPT_DIR"

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
assert_contains "Caddyfile has http:// prefix" "http://" "$caddy_content"

dash_content=$(cat "$TMP_HOME/dashboard.html")
assert_contains "dashboard has renamed-app" "renamed-app" "$dash_content"
assert_contains "dashboard has status dot" "dot-unknown" "$dash_content"

# -- paths --
echo "--- paths ---"
out=$("$DEVKIT" paths)
assert_contains "paths shows DEVKIT_HOME" "$TMP_HOME" "$out"

# -- lifecycle --
echo "--- lifecycle ---"
mkdir -p "$TMP_HOME/lifecycle-app"
cat > "$TMP_HOME/lifecycle-app/serve.sh" <<'SH'
#!/bin/sh
exec python3 -m http.server "$PORT" --bind 127.0.0.1
SH
chmod +x "$TMP_HOME/lifecycle-app/serve.sh"

out=$("$DEVKIT" register lifecycle-app --path "$TMP_HOME/lifecycle-app" --port 5097 --cmd "PORT=5097 ./serve.sh" 2>&1 || true)
assert_contains "lifecycle app registered" "lifecycle-app.localhost" "$out"

out=$("$DEVKIT" start lifecycle-app 2>&1 || true)
assert_contains "start reports lifecycle app" "started lifecycle-app" "$out"

listener_pid=$(wait_for_port_state 5097 listening 60 || true)
assert_nonempty "listener appears on lifecycle port" "$listener_pid"

pid_file_value=$(cat "$TMP_HOME/pids/lifecycle-app.pid")
assert_eq "pid file tracks listener pid" "$listener_pid" "$pid_file_value"

out=$("$DEVKIT" list 2>&1 || true)
assert_contains "list shows lifecycle app running" "lifecycle-app      5097" "$out"
line=$(printf '%s\n' "$out" | rg '^lifecycle-app\s+5097\s+' || true)
assert_contains "list marks lifecycle app running" "running" "$line"

out=$("$DEVKIT" stop lifecycle-app 2>&1 || true)
assert_contains "stop reports lifecycle app" "stopped lifecycle-app" "$out"
wait_for_port_state 5097 free 60
assert_eq "pid file removed after stop" "false" "$( [[ -f "$TMP_HOME/pids/lifecycle-app.pid" ]] && echo true || echo false )"

# -- stale pid file with unrelated live process --
echo "--- stale pid file ---"
( sleep 30 ) &
sleep_pid=$!
echo "$sleep_pid" > "$TMP_HOME/pids/lifecycle-app.pid"
out=$("$DEVKIT" start lifecycle-app 2>&1 || true)
assert_contains "start succeeds with unrelated stale pid file" "started lifecycle-app" "$out"
assert_process_alive "unrelated stale pid process is untouched" "$sleep_pid"
new_listener_pid=$(wait_for_port_state 5097 listening 60 || true)
assert_nonempty "listener appears after stale pid recovery" "$new_listener_pid"
assert_eq "pid file replaced after stale pid recovery" "$new_listener_pid" "$(cat "$TMP_HOME/pids/lifecycle-app.pid")"
kill "$sleep_pid" >/dev/null 2>&1 || true
wait "$sleep_pid" 2>/dev/null || true
"$DEVKIT" stop lifecycle-app >/dev/null 2>&1 || true

# -- unrelated process on app port --
echo "--- unrelated port conflict ---"
mkdir -p "$TMP_HOME/other-app"
(
  cd "$TMP_HOME/other-app"
  python3 -m http.server 5096 --bind 127.0.0.1 >/dev/null 2>&1
) &
foreign_pid=$!
foreign_listener_pid=$(wait_for_port_state 5096 listening 60 || true)
mkdir -p "$TMP_HOME/conflict-app"
cat > "$TMP_HOME/conflict-app/serve.sh" <<'SH'
#!/bin/sh
exec python3 -m http.server 5096 --bind 127.0.0.1
SH
chmod +x "$TMP_HOME/conflict-app/serve.sh"
out=$("$DEVKIT" register conflict-app --path "$TMP_HOME/conflict-app" --port 5096 --cmd "./serve.sh" 2>&1 || true)
assert_contains "conflict app registered" "conflict-app.localhost" "$out"
set +e
out=$("$DEVKIT" start conflict-app 2>&1)
code=$?
set -e
assert_eq "start fails when unrelated process owns port" "1" "$code"
assert_contains "conflict mentions other process" "port 5096 is still in use by another process" "$out"
assert_eq "foreign listener survives conflict start" "$foreign_listener_pid" "$(wait_for_port_state 5096 listening 60 || true)"
kill "$foreign_pid" >/dev/null 2>&1 || true
wait "$foreign_pid" 2>/dev/null || true
"$DEVKIT" remove conflict-app >/dev/null 2>&1 || true

# -- orphan recovery --
echo "--- orphan recovery ---"
out=$("$DEVKIT" start lifecycle-app 2>&1 || true)
assert_contains "baseline start works before orphan recovery" "started lifecycle-app" "$out"
orphan_pid=$(cat "$TMP_HOME/pids/lifecycle-app.pid")
rm -f "$TMP_HOME/pids/lifecycle-app.pid"
out=$("$DEVKIT" start lifecycle-app 2>&1 || true)
assert_contains "start succeeds with orphaned listener" "started lifecycle-app" "$out"
wait_for_pid_exit "$orphan_pid" 60 || true
assert_process_dead "orphan listener from devkit is replaced" "$orphan_pid"
replacement_pid=$(cat "$TMP_HOME/pids/lifecycle-app.pid")
assert_nonempty "replacement pid recorded after orphan recovery" "$replacement_pid"
assert_process_alive "replacement listener is running" "$replacement_pid"
"$DEVKIT" stop lifecycle-app >/dev/null 2>&1 || true

# -- crash cleanup --
echo "--- crash cleanup ---"
mkdir -p "$TMP_HOME/crash-app"
cat > "$TMP_HOME/crash-app/crash.sh" <<'SH'
#!/bin/sh
exit 3
SH
chmod +x "$TMP_HOME/crash-app/crash.sh"
out=$("$DEVKIT" register crash-app --path "$TMP_HOME/crash-app" --port 5094 --cmd "./crash.sh" 2>&1 || true)
assert_contains "crash app registered" "crash-app.localhost" "$out"
set +e
out=$("$DEVKIT" start crash-app 2>&1)
code=$?
set -e
assert_eq "start fails for crashing app" "1" "$code"
assert_contains "crash start reports bind failure" "failed to bind port 5094" "$out"
assert_eq "crash app pid file cleaned up" "false" "$( [[ -f "$TMP_HOME/pids/crash-app.pid" ]] && echo true || echo false )"
out=$("$DEVKIT" list 2>&1 || true)
line=$(printf '%s\n' "$out" | rg '^crash-app\s+5094\s+' || true)
assert_contains "crash app shows stopped after failed start" "stopped" "$line"

# -- unknown command --
echo "--- error handling ---"
assert_exit "unknown command exits 2" 2 "$DEVKIT" bogus

# ---------- summary ----------

echo
echo "=== results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
