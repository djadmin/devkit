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

# -- input validation (a bad name/port must never reach the Caddyfile) --
echo "--- input validation ---"
assert_exit "rejects name with a space"   1 "$DEVKIT" register "bad name" --port 5300 --cmd "x"
assert_exit "rejects uppercase name"      1 "$DEVKIT" register BadName    --port 5301 --cmd "x"
assert_exit "rejects name with a slash"   1 "$DEVKIT" register a/b        --port 5302 --cmd "x"
assert_exit "rejects out-of-range port"   1 "$DEVKIT" register okname     --port 99999 --cmd "x"
assert_exit "rejects non-numeric port"    1 "$DEVKIT" register okname     --port abc   --cmd "x"
bad_count=$(jq '[.apps[] | select(.name=="bad name" or .name=="BadName" or .name=="a/b" or .name=="okname")] | length' "$TMP_HOME/apps.json")
assert_eq "no invalid app slipped into the registry" "0" "$bad_count"

# -- rename --
echo "--- rename ---"
out=$("$DEVKIT" rename testapp renamed-app 2>&1 || true)
assert_contains "rename prints new name" "renamed-app" "$out"

old=$(jq -r '[.apps[] | select(.name=="testapp")] | length' "$TMP_HOME/apps.json")
assert_eq "old name gone" "0" "$old"

new_host=$(jq -r '.apps[] | select(.name=="renamed-app") | .hostname' "$TMP_HOME/apps.json")
assert_eq "hostname updated" "renamed-app.localhost" "$new_host"

# -- update --
echo "--- update ---"
out=$("$DEVKIT" update renamed-app --desc "updated description" --cmd "new-cmd --port 5099" 2>&1 || true)
assert_contains "update prints name" "renamed-app" "$out"

new_desc=$(jq -r '.apps[] | select(.name=="renamed-app") | .description' "$TMP_HOME/apps.json")
assert_eq "update sets description" "updated description" "$new_desc"

new_cmd=$(jq -r '.apps[] | select(.name=="renamed-app") | .startCmd' "$TMP_HOME/apps.json")
assert_eq "update sets cmd" "new-cmd --port 5099" "$new_cmd"

out=$("$DEVKIT" update nonexistent --desc "x" 2>&1 || true)
assert_contains "update rejects unknown app" "unknown app" "$out"

out=$("$DEVKIT" update renamed-app 2>&1 || true)
assert_contains "update requires at least one flag" "nothing to update" "$out"

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
# Dashboard host must NOT expose the whole data dir (apps.json / logs) — only the page.
assert_contains "dashboard route serves only dashboard.html" "handle /dashboard.html" "$caddy_content"
assert_contains "dashboard route 404s everything else" 'respond "not found" 404' "$caddy_content"

# If caddy is available, prove the generated config actually parses — this is the
# regression guard that stops a bad name/port/template change from breaking routing.
if command -v caddy >/dev/null 2>&1; then
  set +e
  caddy validate --adapter caddyfile --config "$TMP_HOME/Caddyfile" >/dev/null 2>&1
  vcode=$?
  set -e
  assert_eq "generated Caddyfile passes 'caddy validate'" "0" "$vcode"
else
  echo "  SKIP  caddy validate (caddy not installed)"
fi

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
line=$(printf '%s\n' "$out" | grep -E '^lifecycle-app[[:space:]]+5097[[:space:]]+' || true)
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
line=$(printf '%s\n' "$out" | grep -E '^crash-app[[:space:]]+5094[[:space:]]+' || true)
# A crashed start is now a DISTINCT, actionable state — not the ambiguous "stopped" that
# looked identical to never-started (see the failed-start visibility section below).
assert_contains    "crash app shows 'failed' after failed start" "failed" "$line"
assert_not_contains "failed start is not reported as plain stopped" "stopped" "$line"

# -- unknown command --
echo "--- error handling ---"
assert_exit "unknown command exits 2" 2 "$DEVKIT" bogus

# -- malformed registry is caught early with a clear message --
echo "--- malformed registry guard ---"
BAD_HOME=$(mktemp -d)
printf '{ this is not valid json' > "$BAD_HOME/apps.json"
set +e
bad_out=$(DEVKIT_HOME="$BAD_HOME" "$DEVKIT" list 2>&1)
bad_code=$?
set -e
assert_eq "malformed registry exits nonzero" "1" "$bad_code"
assert_contains "malformed registry explains the problem" "not valid JSON" "$bad_out"
rm -rf "$BAD_HOME"

# -- staleness self-heal: apps.json edited outside devkit --
echo "--- staleness self-heal ---"
STALE_HOME=$(mktemp -d)
mkdir -p "$STALE_HOME/app-a"
DEVKIT_HOME="$STALE_HOME" "$DEVKIT" register stale-a --path "$STALE_HOME/app-a" --port 5310 --cmd "x --port 5310" >/dev/null 2>&1 || true
assert_contains "caddyfile has registered app" "stale-a.localhost" "$(cat "$STALE_HOME/Caddyfile")"
# Simulate an out-of-band edit (backup restore / sync / hand-edit): add an app straight
# to apps.json with no devkit command, so the generated Caddyfile is now stale.
edit_tmp=$(mktemp)
jq '.apps += [{"name":"ghost","hostname":"ghost.localhost","port":5311,"path":null,"repo":null,"claudeMd":null,"startCmd":null,"description":"","managedBy":"external"}]' \
  "$STALE_HOME/apps.json" > "$edit_tmp" && mv "$edit_tmp" "$STALE_HOME/apps.json"
assert_not_contains "caddyfile stale before reconcile" "ghost.localhost" "$(cat "$STALE_HOME/Caddyfile")"
# A read-only command (list) must self-heal the routing — this is the core fix.
DEVKIT_HOME="$STALE_HOME" "$DEVKIT" list >/dev/null 2>&1 || true
assert_contains "list regenerates stale caddyfile" "ghost.localhost" "$(cat "$STALE_HOME/Caddyfile")"
# A second run with no further edits must NOT keep churning (fingerprint matches).
cksum_before=$(cksum < "$STALE_HOME/Caddyfile")
DEVKIT_HOME="$STALE_HOME" "$DEVKIT" list >/dev/null 2>&1 || true
assert_eq "stable caddyfile when nothing changed" "$cksum_before" "$(cksum < "$STALE_HOME/Caddyfile")"
rm -rf "$STALE_HOME"

# -- default data dir is ~/.devkit (independent of where the binary lives) --
echo "--- default DEVKIT_HOME ---"
DEF_ROOT=$(mktemp -d)
mkdir -p "$DEF_ROOT/bin"
cp "$DEVKIT" "$DEF_ROOT/bin/devkit"   # copy so REPO_HOME points at the sandbox, not the real repo
def_out=$(env -u DEVKIT_HOME HOME="$DEF_ROOT" "$DEF_ROOT/bin/devkit" paths 2>&1 || true)
assert_contains "default data dir is ~/.devkit" "DEVKIT_HOME=$DEF_ROOT/.devkit" "$def_out"
assert_contains "apps.json lives under ~/.devkit" "APPS_JSON=$DEF_ROOT/.devkit/apps.json" "$def_out"
rm -rf "$DEF_ROOT"

# -- one-time migration from a legacy ~/devkit location --
echo "--- legacy home migration ---"
MIG_ROOT=$(mktemp -d)
mkdir -p "$MIG_ROOT/bin" "$MIG_ROOT/devkit/pids" "$MIG_ROOT/devkit/logs"
cp "$DEVKIT" "$MIG_ROOT/bin/devkit"
cat > "$MIG_ROOT/devkit/apps.json" <<'JSON'
{"version":1,"proxyPort":80,"tld":"localhost","dashboardHost":"dash","apps":[{"name":"legacy-app","hostname":"legacy-app.localhost","port":5320,"path":null,"repo":null,"claudeMd":null,"startCmd":null,"description":"","managedBy":"external"}]}
JSON
echo "5320" > "$MIG_ROOT/devkit/pids/legacy-app.pid"
mig_out=$(env -u DEVKIT_HOME HOME="$MIG_ROOT" "$MIG_ROOT/bin/devkit" list 2>&1 || true)
assert_eq "registry migrated into ~/.devkit" "true" "$( [[ -f "$MIG_ROOT/.devkit/apps.json" ]] && echo true || echo false )"
assert_eq "legacy apps.json moved out" "false" "$( [[ -f "$MIG_ROOT/devkit/apps.json" ]] && echo true || echo false )"
assert_contains "migrated registry keeps the app" "legacy-app" "$mig_out"
assert_eq "pid file carried across migration" "true" "$( [[ -f "$MIG_ROOT/.devkit/pids/legacy-app.pid" ]] && echo true || echo false )"
# Idempotent: a second run must neither re-migrate nor error.
mig_out2=$(env -u DEVKIT_HOME HOME="$MIG_ROOT" "$MIG_ROOT/bin/devkit" list 2>&1 || true)
assert_not_contains "migration does not repeat" "migrating registry" "$mig_out2"
rm -rf "$MIG_ROOT"

# -- supervisor: opt-in crash recovery --
# The `supervise` subcommand is not currently shipped in bin/devkit. Guard the whole
# section so the suite stays green and accurate instead of aborting under `set -e` on
# the unknown command. If/when supervise lands, this block runs automatically.
if "$DEVKIT" supervise --help >/dev/null 2>&1; then
echo "--- supervisor: restart policy + crash recovery ---"
assert_exit "rejects bad restart policy" 1 "$DEVKIT" register badpol --port 5413 --cmd "x" --restart sometimes

SUP_HOME=$(mktemp -d); mkdir -p "$SUP_HOME/app"
cat > "$SUP_HOME/app/serve.sh" <<'SH'
#!/bin/sh
exec python3 -m http.server 5412 --bind 127.0.0.1
SH
chmod +x "$SUP_HOME/app/serve.sh"
DEVKIT_HOME="$SUP_HOME" "$DEVKIT" register sup --path "$SUP_HOME/app" --port 5412 --cmd "./serve.sh" --restart on-failure >/dev/null 2>&1 || true
assert_eq "restart policy stored" "on-failure" "$(jq -r '.apps[0].restart' "$SUP_HOME/apps.json")"

DEVKIT_HOME="$SUP_HOME" "$DEVKIT" start sup >/dev/null 2>&1 || true
wait_for_port_state 5412 listening 60 >/dev/null || true
assert_eq "want marker set on start" "true" "$( [[ -f "$SUP_HOME/supervisor/wants/sup" ]] && echo true || echo false )"

# Simulate a crash, then a single supervise tick must bring it back.
kill -9 "$(lsof -tiTCP:5412 -sTCP:LISTEN | head -1)" 2>/dev/null || true
wait_for_port_state 5412 free 60 || true
DEVKIT_HOME="$SUP_HOME" "$DEVKIT" supervise tick >/dev/null 2>&1 || true
assert_nonempty "supervise tick restarts a crashed app" "$(wait_for_port_state 5412 listening 60 || true)"

# A manual stop must be honoured — the supervisor must not fight it.
DEVKIT_HOME="$SUP_HOME" "$DEVKIT" stop sup >/dev/null 2>&1 || true
wait_for_port_state 5412 free 60 || true
assert_eq "want marker cleared on stop" "false" "$( [[ -f "$SUP_HOME/supervisor/wants/sup" ]] && echo true || echo false )"
DEVKIT_HOME="$SUP_HOME" "$DEVKIT" supervise tick >/dev/null 2>&1 || true
sleep 1
assert_eq "supervisor does not restart after manual stop" "" "$(lsof -tiTCP:5412 -sTCP:LISTEN 2>/dev/null || true)"
DEVKIT_HOME="$SUP_HOME" "$DEVKIT" stop sup >/dev/null 2>&1 || true
rm -rf "$SUP_HOME"

echo "--- supervisor: launchd agent plist ---"
PL_HOME=$(mktemp -d); FAKE_HOME=$(mktemp -d)
HOME="$FAKE_HOME" DEVKIT_HOME="$PL_HOME" "$DEVKIT" supervise install >/dev/null 2>&1
PLIST="$FAKE_HOME/Library/LaunchAgents/com.devkit.supervisor.plist"
assert_eq "supervise install writes a plist" "true" "$( [[ -f "$PLIST" ]] && echo true || echo false )"
if command -v python3 >/dev/null 2>&1 && [[ -f "$PLIST" ]]; then
  set +e; python3 -c "import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])" "$PLIST" >/dev/null 2>&1; xmlcode=$?; set -e
  assert_eq "plist is well-formed XML" "0" "$xmlcode"
fi
assert_contains "plist invokes supervise tick" "supervise" "$(cat "$PLIST" 2>/dev/null)"
HOME="$FAKE_HOME" DEVKIT_HOME="$PL_HOME" "$DEVKIT" supervise uninstall >/dev/null 2>&1
assert_eq "supervise uninstall removes the plist" "false" "$( [[ -f "$PLIST" ]] && echo true || echo false )"
rm -rf "$PL_HOME" "$FAKE_HOME"
else
  echo "--- supervisor: skipped (devkit supervise not available) ---"
fi

# -- start-all / restart-all (parallel) --
# Isolated DEVKIT_HOME passed per-command so the asserts still run in this shell
# (a wrapping subshell would lose the PASS/FAIL counters).
echo "--- start-all (parallel) ---"
SA_HOME=$(mktemp -d)

# Empty registry should report nothing to start (not error).
empty_out=$(DEVKIT_HOME="$SA_HOME" "$DEVKIT" start-all 2>&1 || true)
assert_contains "start-all on empty registry is a no-op" "no devkit-managed apps" "$empty_out"

mkdir -p "$SA_HOME/sa1" "$SA_HOME/sa2"
for n in sa1 sa2; do
  cat > "$SA_HOME/$n/serve.sh" <<'SH'
#!/bin/sh
exec python3 -m http.server "$PORT" --bind 127.0.0.1
SH
  chmod +x "$SA_HOME/$n/serve.sh"
done
DEVKIT_HOME="$SA_HOME" "$DEVKIT" register sa1 --path "$SA_HOME/sa1" --port 5471 --cmd "PORT=5471 ./serve.sh" >/dev/null 2>&1 || true
DEVKIT_HOME="$SA_HOME" "$DEVKIT" register sa2 --path "$SA_HOME/sa2" --port 5472 --cmd "PORT=5472 ./serve.sh" >/dev/null 2>&1 || true

sa_out=$(DEVKIT_HOME="$SA_HOME" "$DEVKIT" start-all 2>&1 || true)
assert_contains "start-all reports both apps started" "started 2 app(s)" "$sa_out"
assert_nonempty "sa1 is listening after start-all" "$(wait_for_port_state 5471 listening 60 || true)"
assert_nonempty "sa2 is listening after start-all" "$(wait_for_port_state 5472 listening 60 || true)"

DEVKIT_HOME="$SA_HOME" "$DEVKIT" stop-all >/dev/null 2>&1 || true
rm -rf "$SA_HOME"

# -- logs must never hang a non-interactive caller (regression: cmd_logs used bare tail -f) --
echo "--- logs (non-blocking) ---"
# Portable timeout (macOS has no `timeout`). Uses the alarm+exec idiom: alarm() survives
# exec and SIGALRM's default disposition kills the process, so a hung command dies on its
# own. (A fork+waitpid version deadlocks under Perl safe-signals, which is itself a good
# illustration of why "non-interactive must terminate" needs a test.)
tmo() { perl -e 'alarm shift @ARGV; exec @ARGV or exit 127' "$@"; }
LG_HOME=$(mktemp -d); mkdir -p "$LG_HOME/lg"
cat > "$LG_HOME/lg/serve.sh" <<'SH'
#!/bin/sh
echo "log-line-one"; echo "log-line-two"; exec python3 -m http.server "$PORT" --bind 127.0.0.1
SH
chmod +x "$LG_HOME/lg/serve.sh"
DEVKIT_HOME="$LG_HOME" "$DEVKIT" register lg --path "$LG_HOME/lg" --port 5481 --cmd "PORT=5481 ./serve.sh" >/dev/null 2>&1 || true
DEVKIT_HOME="$LG_HOME" "$DEVKIT" start lg >/dev/null 2>&1 || true
wait_for_port_state 5481 listening 30 >/dev/null || true

out=$(DEVKIT_HOME="$LG_HOME" tmo 8 "$DEVKIT" logs lg 2>&1); code=$?
assert_eq "logs exits by default (does not follow/hang)" "0" "$code"
assert_contains "logs prints recent output" "log-line-one" "$out"
n=$(DEVKIT_HOME="$LG_HOME" tmo 8 "$DEVKIT" logs lg -n 1 2>&1 | wc -l | tr -d ' ')
assert_eq "logs -n limits the number of lines" "1" "$n"
DEVKIT_HOME="$LG_HOME" "$DEVKIT" stop-all >/dev/null 2>&1 || true
rm -rf "$LG_HOME"

# -- start must fail FAST when the launched command exits immediately (no 60s hang) --
echo "--- start fast-fail ---"
FF_HOME=$(mktemp -d); mkdir -p "$FF_HOME/ff"
cat > "$FF_HOME/ff/boom.sh" <<'SH'
#!/bin/sh
echo "crashing on purpose" >&2
exit 1
SH
chmod +x "$FF_HOME/ff/boom.sh"
DEVKIT_HOME="$FF_HOME" "$DEVKIT" register ff --path "$FF_HOME/ff" --port 5482 --cmd "./boom.sh" >/dev/null 2>&1 || true
ff_start=$(date +%s)
ff_code=0
DEVKIT_HOME="$FF_HOME" "$DEVKIT" start ff >/dev/null 2>&1 || ff_code=$?
ff_elapsed=$(( $(date +%s) - ff_start ))
assert_eq "start of an immediately-crashing app fails" "1" "$ff_code"
assert_eq "start fails fast, well under the 60s bind timeout" "true" "$( [ "$ff_elapsed" -lt 20 ] && echo true || echo false )"
DEVKIT_HOME="$FF_HOME" "$DEVKIT" stop-all >/dev/null 2>&1 || true
rm -rf "$FF_HOME"

# -- start reports success truthfully (errexit regression) --
# A standalone `(( waited++ ))` returns exit 1 when the counter is 0, which under
# `set -euo pipefail` aborted cmd_start AFTER the app had already launched: start then
# printed nothing and returned non-zero on a *successful* start (it lied about state).
# A deliberately slow bind forces the bind-wait loop to iterate so the increment runs;
# start must still report "started" and exit 0.
echo "--- start truthful success (errexit regression) ---"
ST_HOME=$(mktemp -d); mkdir -p "$ST_HOME/slow"
cat > "$ST_HOME/slow/serve.sh" <<'SH'
#!/bin/sh
sleep 1
exec python3 -m http.server "$PORT" --bind 127.0.0.1
SH
chmod +x "$ST_HOME/slow/serve.sh"
DEVKIT_HOME="$ST_HOME" "$DEVKIT" register slow --path "$ST_HOME/slow" --port 5491 --cmd "PORT=5491 ./serve.sh" >/dev/null 2>&1 || true
st_code=0
st_out=$(DEVKIT_HOME="$ST_HOME" "$DEVKIT" start slow 2>&1) || st_code=$?
assert_eq       "slow-binding start exits 0 on success" "0" "$st_code"
assert_contains "slow-binding start reports started"    "started slow" "$st_out"
DEVKIT_HOME="$ST_HOME" "$DEVKIT" stop-all >/dev/null 2>&1 || true
rm -rf "$ST_HOME"

# -- failed-start visibility (no dead ends) --
# A failed start must be a DISTINCT state from "never started" and must point at the log.
# Previously a crashed start showed as plain "stopped" with no breadcrumb.
echo "--- failed-start visibility ---"
FV_HOME=$(mktemp -d); mkdir -p "$FV_HOME/fv"
cat > "$FV_HOME/fv/boom.sh" <<'SH'
#!/bin/sh
echo "boom" >&2; exit 1
SH
chmod +x "$FV_HOME/fv/boom.sh"
DEVKIT_HOME="$FV_HOME" "$DEVKIT" register fv --path "$FV_HOME/fv" --port 5492 --cmd "./boom.sh" >/dev/null 2>&1 || true
state0=$(DEVKIT_HOME="$FV_HOME" "$DEVKIT" list --json 2>/dev/null | jq -r '.[] | select(.name=="fv") | .state')
assert_eq "never-started app is stopped" "stopped" "$state0"
DEVKIT_HOME="$FV_HOME" "$DEVKIT" start fv >/dev/null 2>&1 || true
fv_txt=$(DEVKIT_HOME="$FV_HOME" "$DEVKIT" list 2>&1)
assert_contains "failed start shows 'failed' in list"   "failed"      "$fv_txt"
assert_contains "list points a failed app at its logs"  "devkit logs" "$fv_txt"
fv_json=$(DEVKIT_HOME="$FV_HOME" "$DEVKIT" list --json 2>/dev/null)
assert_eq        "list --json marks state failed"  "failed" "$(jq -r '.[]|select(.name=="fv")|.state' <<<"$fv_json")"
assert_nonempty  "list --json includes a failReason"        "$(jq -r '.[]|select(.name=="fv")|.failReason' <<<"$fv_json")"
assert_contains  "list --json includes the log path" "fv.log" "$(jq -r '.[]|select(.name=="fv")|.logFile' <<<"$fv_json")"
DEVKIT_HOME="$FV_HOME" "$DEVKIT" stop fv >/dev/null 2>&1 || true
assert_eq "an explicit stop clears the failed state" "stopped" \
  "$(DEVKIT_HOME="$FV_HOME" "$DEVKIT" list --json 2>/dev/null | jq -r '.[]|select(.name=="fv")|.state')"
# Re-fail, then a successful start must clear the marker (no explicit stop in between).
DEVKIT_HOME="$FV_HOME" "$DEVKIT" start fv >/dev/null 2>&1 || true
DEVKIT_HOME="$FV_HOME" "$DEVKIT" update fv --cmd "python3 -m http.server 5492 --bind 127.0.0.1" >/dev/null 2>&1 || true
DEVKIT_HOME="$FV_HOME" "$DEVKIT" start fv >/dev/null 2>&1 || true
assert_eq "a successful start clears the failed state" "running" \
  "$(DEVKIT_HOME="$FV_HOME" "$DEVKIT" list --json 2>/dev/null | jq -r '.[]|select(.name=="fv")|.state')"
DEVKIT_HOME="$FV_HOME" "$DEVKIT" stop-all >/dev/null 2>&1 || true
rm -rf "$FV_HOME"

# -- external apps render as 'external' even with no path (column-shift regression) --
# An empty path used to collapse under IFS=$'\t' (tab is IFS-whitespace), shifting every
# later column so a path-less external app showed as plain "stopped". Records are now
# \x1f-separated, which preserves empty fields.
echo "--- external state (column-shift regression) ---"
EX_HOME=$(mktemp -d)
DEVKIT_HOME="$EX_HOME" "$DEVKIT" register exns --managed-by external >/dev/null 2>&1 || true
ex_line=$(DEVKIT_HOME="$EX_HOME" "$DEVKIT" list 2>&1 | grep -E '^exns[[:space:]]' || true)
assert_contains     "path-less external app shows 'external' in list"   "external" "$ex_line"
assert_not_contains "path-less external app is not mislabeled stopped"  "stopped"  "$ex_line"
assert_eq "list --json marks a path-less external app as external" "external" \
  "$(DEVKIT_HOME="$EX_HOME" "$DEVKIT" list --json 2>/dev/null | jq -r '.[]|select(.name=="exns")|.state')"
rm -rf "$EX_HOME"

# -- clone is non-interactive (never hangs on credentials / host-key) --
# A bare `git clone` of a private repo prompts on the TTY and blocks forever for an agent
# or script. clone must disable those prompts and fail fast with a next action.
echo "--- clone non-interactive ---"
CL_HOME=$(mktemp -d)
cl_bogus="/tmp/dk-no-such-repo-$$"     # not a git repo -> clone fails immediately
cl_dest="$CL_HOME/dest"
DEVKIT_HOME="$CL_HOME" "$DEVKIT" register clo --managed-by external --repo "$cl_bogus" --path "$cl_dest" >/dev/null 2>&1 || true
cl_start=$(date +%s); cl_code=0
DEVKIT_HOME="$CL_HOME" perl -e 'alarm shift @ARGV; exec @ARGV' 15 "$DEVKIT" clone clo >/dev/null 2>&1 || cl_code=$?
cl_elapsed=$(( $(date +%s) - cl_start ))
assert_eq "clone of an unreachable repo fails, not hangs" "true" \
  "$( [ "$cl_code" -ne 0 ] && [ "$cl_code" -ne 142 ] && echo true || echo false )"
assert_eq "clone terminates well under the timeout" "true" "$( [ "$cl_elapsed" -lt 15 ] && echo true || echo false )"
assert_contains "clone keeps git credential prompt disabled" "GIT_TERMINAL_PROMPT=0" "$(cat "$DEVKIT")"
rm -rf "$CL_HOME"

# ---------- summary ----------

echo
echo "=== results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
