#!/usr/bin/env bash
# test_scan.sh — integration tests for `devkit scan` (web-app discovery).
# Spins up throwaway local servers and asserts detection / classification / naming.
# Runs against a temporary DEVKIT_HOME so nothing touches your real registry.
# Usage: bash test/test_scan.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVKIT="$SCRIPT_DIR/../bin/devkit"
TMP_HOME=$(mktemp -d)
export DEVKIT_HOME="$TMP_HOME"
WEBROOT=$(mktemp -d)
PIDS=()

PASS=0
FAIL=0

cleanup() {
  for p in "${PIDS[@]:-}"; do [[ -n "$p" ]] && kill "$p" 2>/dev/null || true; done
  rm -rf "$TMP_HOME" "$WEBROOT" "${NOTITLE_ROOT:-}"
}
trap cleanup EXIT

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS  $label"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $label"; echo "        expected: $expected"; echo "        actual:   $actual"; FAIL=$((FAIL + 1))
  fi
}
assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  PASS  $label"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $label"; echo "        expected to contain: $needle"; echo "        got: $haystack"; FAIL=$((FAIL + 1))
  fi
}
assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "  PASS  $label"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $label"; echo "        expected NOT to contain: $needle"; echo "        got: $haystack"; FAIL=$((FAIL + 1))
  fi
}

# Pick ports unlikely to clash in CI.
P_WEB=6701      # unregistered HTML app  -> should be found
P_REG=6702      # registered HTML app    -> should be excluded
P_JSON=6703     # JSON API               -> should be excluded (not HTML)
P_DEAD=6704     # nothing listening       -> nothing to find
P_NOTITLE=6705  # HTML with no <title>    -> found, process-port fallback name
P_HTTPS=6706    # HTTPS-only HTML app     -> found via https fallback (if openssl present)
P_IPV6=6707     # IPv6-only (::1) HTML app -> found via the [::1] probe (Vite v6's default)

start_html_server() { # port directory
  # Bind loopback explicitly. python's default (0.0.0.0) is found locally but not on the
  # GitHub macOS runner, and real dev servers bind 127.0.0.1/::1 anyway — which is exactly
  # what scan probes.
  python3 -m http.server "$1" --bind 127.0.0.1 --directory "$2" >/dev/null 2>&1 &
  PIDS+=("$!")
}
start_json_server() { # port
  python3 - "$1" <<'PY' >/dev/null 2>&1 &
import sys, http.server, json
port = int(sys.argv[1])
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.send_header('Content-Type','application/json'); self.end_headers()
        self.wfile.write(json.dumps({"ok": True}).encode())
    def log_message(self, *a): pass
http.server.HTTPServer(('127.0.0.1', port), H).serve_forever()
PY
  PIDS+=("$!")
}
start_https_server() { # port  (self-signed; returns 0 if it could start)
  command -v openssl >/dev/null 2>&1 || return 1
  python3 - "$1" <<'PY' >/dev/null 2>&1 &
import sys, http.server, ssl, tempfile, subprocess, os
port = int(sys.argv[1]); d = tempfile.mkdtemp()
key, crt = os.path.join(d, 'k.pem'), os.path.join(d, 'c.pem')
subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-keyout',key,'-out',crt,
                '-days','1','-nodes','-subj','/CN=localhost'], check=True, capture_output=True)
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.send_header('Content-Type','text/html'); self.end_headers()
        self.wfile.write(b'<!DOCTYPE html><html><head><title>Secure App</title></head><body>x</body></html>')
    def log_message(self, *a): pass
httpd = http.server.HTTPServer(('127.0.0.1', port), H)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); ctx.load_cert_chain(crt, key)
httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True); httpd.serve_forever()
PY
  PIDS+=("$!"); return 0
}
start_ipv6_server() { # port  (binds ::1 ONLY — mirrors Vite v6, which an IPv4-only probe misses)
  python3 - "$1" >/dev/null 2>&1 <<'PY' &
import sys, socket, http.server
port = int(sys.argv[1])
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.send_header('Content-Type','text/html'); self.end_headers()
        self.wfile.write(b'<!DOCTYPE html><html><head><title>IPv6 App</title></head><body>x</body></html>')
    def log_message(self, *a): pass
class S(http.server.HTTPServer):
    address_family = socket.AF_INET6
S(('::1', port), H).serve_forever()
PY
  PIDS+=("$!")
}

# ---------- fixtures ----------
printf '<!DOCTYPE html><html><head><title>My Vite Dashboard</title></head><body>hi</body></html>' > "$WEBROOT/index.html"
NOTITLE_ROOT=$(mktemp -d)
printf '<!DOCTYPE html><html><body>page with no title element</body></html>' > "$NOTITLE_ROOT/index.html"

# Seed a registry containing an app already on P_REG (so scan must skip it).
cat > "$DEVKIT_HOME/apps.json" <<JSON
{"version":1,"proxyPort":80,"tld":"localhost","dashboardHost":"dash","apps":[
{"name":"already-known","hostname":"already-known.localhost","port":$P_REG,"path":null,"repo":null,"claudeMd":null,"startCmd":null,"description":"","managedBy":"external"}]}
JSON

start_html_server "$P_WEB"  "$WEBROOT"
start_html_server "$P_REG"  "$WEBROOT"
start_html_server "$P_NOTITLE" "$NOTITLE_ROOT"
start_json_server "$P_JSON"
HTTPS_UP=0; start_https_server "$P_HTTPS" && HTTPS_UP=1
start_ipv6_server "$P_IPV6"
sleep 2   # let servers bind (https cert gen needs a moment)
# IPv6 loopback isn't guaranteed in every CI sandbox; only assert it if the bind worked.
IPV6_UP=0; lsof -tiTCP:"$P_IPV6" -sTCP:LISTEN >/dev/null 2>&1 && IPV6_UP=1

# ---------- scan --json ----------
echo "--- scan --json: detection & classification ---"
JSON_OUT="$("$DEVKIT" scan --json)"

assert_eq "output is a JSON array" "array" "$(jq -r 'type' <<<"$JSON_OUT")"

found_web=$(jq --argjson p "$P_WEB" 'any(.[]; .port==$p)' <<<"$JSON_OUT")
assert_eq "unregistered HTML app is found"        "true"  "$found_web"

found_reg=$(jq --argjson p "$P_REG" 'any(.[]; .port==$p)' <<<"$JSON_OUT")
assert_eq "already-registered port is excluded"   "false" "$found_reg"

found_json=$(jq --argjson p "$P_JSON" 'any(.[]; .port==$p)' <<<"$JSON_OUT")
assert_eq "JSON API (non-HTML) is excluded"       "false" "$found_json"

found_dead=$(jq --argjson p "$P_DEAD" 'any(.[]; .port==$p)' <<<"$JSON_OUT")
assert_eq "dead port is not reported"             "false" "$found_dead"

# Regression: a page with no <title> must still be found (fallback name), not dropped.
found_notitle=$(jq --argjson p "$P_NOTITLE" 'any(.[]; .port==$p)' <<<"$JSON_OUT")
assert_eq "HTML app with no <title> is still found" "true" "$found_notitle"
nt_name=$(jq -r --argjson p "$P_NOTITLE" '.[] | select(.port==$p) | .suggestedName' <<<"$JSON_OUT")
assert_contains "no-title app falls back to process-port name" "-$P_NOTITLE" "$nt_name"

# Regression: an HTTPS-only app must be found via the https fallback. curl can exit
# non-zero on a self-signed teardown while still returning a valid status — scan must
# trust the http_code, not the exit code.
if [[ "$HTTPS_UP" == 1 ]]; then
  found_https=$(jq --argjson p "$P_HTTPS" 'any(.[]; .port==$p)' <<<"$JSON_OUT")
  assert_eq "HTTPS-only app is found via fallback" "true" "$found_https"
  https_scheme=$(jq -r --argjson p "$P_HTTPS" '.[] | select(.port==$p) | .scheme' <<<"$JSON_OUT")
  assert_eq "HTTPS app records scheme=https" "https" "$https_scheme"
else
  echo "  SKIP  HTTPS fallback (openssl unavailable)"
fi

# Regression: a server bound to ::1 ONLY (Vite v6's default) is enumerated by lsof but
# was dropped by the old 127.0.0.1-only probe. scan must probe the [::1] family too.
if [[ "$IPV6_UP" == 1 ]]; then
  found_ipv6=$(jq --argjson p "$P_IPV6" 'any(.[]; .port==$p)' <<<"$JSON_OUT")
  assert_eq "IPv6-only (::1) app is found via the [::1] probe" "true" "$found_ipv6"
  ipv6_scheme=$(jq -r --argjson p "$P_IPV6" '.[] | select(.port==$p) | .scheme' <<<"$JSON_OUT")
  assert_eq "IPv6-only app records scheme=http" "http" "$ipv6_scheme"
else
  echo "  SKIP  IPv6-only probe (::1 loopback unavailable in this environment)"
fi

# ---------- name suggestion ----------
echo "--- scan --json: name suggestion from <title> ---"
name=$(jq -r --argjson p "$P_WEB" '.[] | select(.port==$p) | .suggestedName' <<<"$JSON_OUT")
assert_eq "title slugified to valid name" "my-vite-dashboard" "$name"

# every suggested name must satisfy devkit's DNS-slug rule
all_valid=true
while IFS= read -r n; do
  [[ "$n" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || all_valid=false
done < <(jq -r '.[].suggestedName' <<<"$JSON_OUT")
assert_eq "all suggested names are valid slugs" "true" "$all_valid"

# ---------- command recovery ----------
echo "--- scan --json: start command + path recovery ---"
hint=$(jq -r --argjson p "$P_WEB" '.[] | select(.port==$p) | .startCmdHint' <<<"$JSON_OUT")
assert_contains "startCmdHint recovered from ps" "http.server" "$hint"
scheme=$(jq -r --argjson p "$P_WEB" '.[] | select(.port==$p) | .scheme' <<<"$JSON_OUT")
assert_eq "scheme recorded as http" "http" "$scheme"

# ---------- name collision guard ----------
echo "--- scan: collision guard against existing registry name ---"
# Register an app literally named "my-vite-dashboard"; the next scan must NOT reuse it.
"$DEVKIT" register my-vite-dashboard --port 6709 --managed-by external >/dev/null 2>&1
JSON_OUT2="$("$DEVKIT" scan --json)"
name2=$(jq -r --argjson p "$P_WEB" '.[] | select(.port==$p) | .suggestedName' <<<"$JSON_OUT2")
assert_not_contains "collision-guarded name differs from taken name" "my-vite-dashboard " "$name2 "
assert_contains "collision guard appends a suffix" "my-vite-dashboard-2" "$name2"

# ---------- secret stripping ----------
# Exercise the SHIPPED scan_sanitize_cmd by sourcing the script (dispatch silenced) and
# calling the function directly, so the test tracks the real implementation.
echo "--- scan_sanitize_cmd: env-var prefixes stripped ---"
SAN=$(
  source "$DEVKIT" >/dev/null 2>&1
  scan_sanitize_cmd "API_KEY=supersecret PORT=3000 node server.js"
)
assert_eq "secret env prefix removed"   "node server.js" "$SAN"
SAN2=$(
  source "$DEVKIT" >/dev/null 2>&1
  scan_sanitize_cmd "node server.js"
)
assert_eq "plain command left untouched" "node server.js" "$SAN2"

# ---------- text output ----------
echo "--- scan: human-readable output ---"
TXT="$("$DEVKIT" scan)"
assert_contains "text output lists the found app" "my-vite-dashboard" "$TXT"
assert_contains "text output shows a header"       "PORT" "$TXT"

# ---------- empty case ----------
echo "--- scan: empty registry-everything case ---"
# Register the found app too, then a fresh scan over the same servers should report none
# of OUR fixture ports (they're all registered now).
"$DEVKIT" register thefound --port "$P_WEB" --managed-by external >/dev/null 2>&1
JSON_OUT3="$("$DEVKIT" scan --json)"
still=$(jq --argjson p "$P_WEB" 'any(.[]; .port==$p)' <<<"$JSON_OUT3")
assert_eq "registering the found app removes it from scan" "false" "$still"

# ---------- performance bound ----------
echo "--- scan: completes within the parallel time bound ---"
start=$(date +%s)
"$DEVKIT" scan --json >/dev/null
end=$(date +%s)
elapsed=$((end - start))
# This scans every listener on the host, so the absolute time scales with how many ports
# are up (unbounded on a busy dev box). The point is only that batched parallelism keeps it
# bounded, not (ports * timeout): a 60s ceiling clears any realistic machine while a
# serialized regression (minutes) still trips it.
assert_eq "scan finished under 60s" "true" "$( (( elapsed < 60 )) && echo true || echo false )"

# ---------- summary ----------
echo
echo "=== results: $PASS passed, $FAIL failed (scan took ${elapsed}s) ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
