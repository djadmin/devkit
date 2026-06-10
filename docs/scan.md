# `devkit scan` — discovering running web apps

`devkit scan` finds web apps already listening on a localhost port that the registry
doesn't know about, and suggests how to register them. It exists for apps that were
started **outside** devkit — e.g. another tool handed you `npm install && npm run dev`
and a bare `http://localhost:5173`, and that app never made it into `apps.json`.

It is a **read-only suggestion** command: it never writes to the registry. The user (or
the menu bar app) decides what to register.

---

## Why it's a CLI command, not a daemon

Detection is a point-in-time question ("what's listening right now?"), so a long-running
service would add moving parts — and bugs — for no benefit. `devkit scan --json` is the
single source of truth; both the terminal and the macOS menu bar app consume the same
output. If we ever want continuous discovery, the menu bar app can simply call `scan`
on a timer (it already polls `devkit list`). Keep the surface area small.

---

## How detection works

```
lsof  →  filter  →  parallel HTTP probe  →  classify  →  suggest name + command
```

1. **Enumerate** every listening TCP socket once: `lsof -nP -iTCP -sTCP:LISTEN`.
2. **Filter** the candidate list:
   - dedupe by port (a server often binds IPv4 *and* IPv6),
   - drop ports `< DEVKIT_SCAN_MIN_PORT` (default 1024 — skips system/privileged ports),
   - drop ports already present in `apps.json`.
3. **Probe** each candidate in parallel with `curl`:
   `GET http://127.0.0.1:<port>/`, following up to 3 redirects, `--connect-timeout 1
   -m 2`. On a no-response (`000`), retry once over `https` with `-k` (self-signed ok).
4. **Classify as a web app** only if we got an HTTP status **and** either the
   `Content-Type` contains `text/html` **or** the first ~256 bytes of the body contain
   `<!doctype` / `<html>`. This is what makes scan "web apps only": Postgres, Redis,
   gRPC, and JSON-only APIs are excluded by construction.
5. **Suggest a name** from the page `<title>`, slugified to a DNS-safe label; fall back
   to `<process>-<port>` (e.g. `node-5173`) when there's no usable title. The name is
   guaranteed unique against the existing registry (appends `-2`, `-3`, …).
6. **Recover a start command + path**: from the listener PID we read `ps -o command=`
   and the working directory via `lsof -d cwd`. This lets a found app usually be
   registered as **devkit-managed** (restartable), not merely `external`.

### Performance: no slow port scanning

Probes are launched in **parallel, batched** at `DEVKIT_SCAN_CONCURRENCY` (default 24).
Total wall time is therefore bounded by roughly **one probe timeout**, not
`ports × timeout`. Scanning dozens of ports costs ~2 seconds, not dozens of seconds.
The batching loop is bash-3.2 safe (no `wait -n`), so it runs on the stock macOS shell.

---

## Output

### Human-readable (`devkit scan`)

```
NAME                   PORT    PROCESS   TITLE
cool-vite-app          5173    node      Cool Vite App
md-notes               4823    python3   Markdown Notes

Register one with:  devkit register <name> --port <port> [--cmd "..." --path P | --managed-by external]
```

### Machine-readable (`devkit scan --json`)

A JSON array, sorted by port. One object per discovered web app:

```json
[
  {
    "suggestedName": "cool-vite-app",
    "port": 5173,
    "process": "node",
    "title": "Cool Vite App",
    "startCmdHint": "node /Users/you/app/node_modules/.bin/vite",
    "pathHint": "/Users/you/app",
    "scheme": "http",
    "registered": false
  }
]
```

| Field           | Meaning                                                                 |
|-----------------|-------------------------------------------------------------------------|
| `suggestedName` | DNS-safe slug from `<title>`, or `process-port`. Pre-validated, unique. |
| `port`          | Listening port (integer).                                               |
| `process`       | Process name from `lsof` (`node`, `python3`, `ruby`, …).                |
| `title`         | Raw HTML `<title>` text (may be empty).                                 |
| `startCmdHint`  | Best-effort start command from `ps`, secrets stripped. May be `null`.   |
| `pathHint`      | Working directory of the process from `lsof`. May be `null`.            |
| `scheme`        | `http` or `https` (which probe succeeded).                              |
| `registered`    | Always `false` here (scan only returns unregistered apps).              |

`scan --json` always prints a valid JSON array — `[]` when nothing is found — so callers
can decode unconditionally.

---

## The restart caveat (read before relying on `startCmdHint`)

`startCmdHint` is **best effort**:

- It's the *resolved* command from the process table, so it may read
  `node .../node_modules/.bin/vite` rather than the friendly `npm run dev`. It usually
  still runs; if not, the user edits one pre-filled field.
- Some apps have no clean re-runnable command (a compiled binary launched by another
  supervisor, a Docker-published port). For those, `startCmdHint`/`pathHint` may be
  `null` — register as `--managed-by external`. The app still gets a stable
  `*.localhost` URL and appears in the dashboard; devkit just won't claim to restart it.
  This is exactly how devkit already treats Postgres and other externally-owned services.

**Secrets:** a process's argv can contain `KEY=value` env prefixes (API keys, tokens).
`scan_sanitize_cmd` strips leading `KEY=value ` tokens before `startCmdHint` is emitted,
so they are not persisted into `apps.json`. Always show the captured command to the user
for confirmation before registering as devkit-managed.

---

## Registering a scan result

Devkit-managed (restartable) — when a usable command was recovered:

```bash
devkit register cool-vite-app --port 5173 \
  --cmd "node node_modules/.bin/vite" --path /Users/you/app
```

External (no lifecycle ownership) — when no command could be inferred:

```bash
devkit register some-service --port 9000 --managed-by external
```

`devkit register` already validates the name (`valid_name`) and port
(`assert_valid_port`) and is an upsert, so re-registering the same name is safe.

---

## Configuration (environment variables)

| Variable                      | Default | Purpose                                   |
|-------------------------------|---------|-------------------------------------------|
| `DEVKIT_SCAN_TIMEOUT`         | `2`     | Total seconds per HTTP probe.             |
| `DEVKIT_SCAN_CONNECT_TIMEOUT` | `1`     | Seconds allowed to establish the TCP conn.|
| `DEVKIT_SCAN_CONCURRENCY`     | `24`    | Max parallel probes per batch.            |
| `DEVKIT_SCAN_MIN_PORT`        | `1024`  | Ignore ports below this (system ports).   |

---

## Debugging / support

- **An app isn't found.** It's probably still booting (probe timed out) — re-run
  `devkit scan`, it's idempotent. Or it doesn't serve HTML at `/` (a pure JSON API is
  excluded by design). Or it's HTTPS with a slow handshake — bump `DEVKIT_SCAN_TIMEOUT`.
- **A non-web service shows up.** Rare, but an app that returns an HTML error page at `/`
  can be misclassified. The user simply doesn't register it; nothing is written.
- **`suggestedName` looks like `node-5173`.** The page had no usable `<title>`; that's the
  intended fallback. Rename freely at register time.
- **`startCmdHint` is `null`.** `ps`/`lsof` couldn't attribute a command/cwd to the PID
  (permissions, or a kernel/helper process). Register as `--managed-by external`.
- **Manually inspect a candidate:**
  ```bash
  lsof -nP -iTCP -sTCP:LISTEN          # what's listening
  curl -sS -D - http://127.0.0.1:PORT/ # what it answers
  ps -o command= -p <pid>              # how it was started
  ```
- **Tests:** `bash test/test_scan.sh` spins up throwaway HTML / JSON servers and asserts
  detection, classification, naming, the collision guard, secret stripping, and the
  parallel time bound. Runs against a temp `DEVKIT_HOME`; touches nothing real.

---

## macOS menu bar app integration (consumer contract)

The app keeps **all detection in the CLI** and just consumes `devkit scan --json`.
A minimal, dependency-free Swift consumer:

```swift
import Foundation

struct ScanResult: Codable, Identifiable {
    var id: Int { port }
    let suggestedName: String
    let port: Int
    let process: String
    let title: String
    let startCmdHint: String?
    let pathHint: String?
    let scheme: String
    let registered: Bool
}

enum Devkit {
    /// Adjust to wherever devkit is installed (Homebrew: /opt/homebrew/bin/devkit).
    static let binary = "/usr/local/bin/devkit"

    @discardableResult
    private static func run(_ args: [String]) throws -> Data {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: binary)
        p.arguments = args
        let out = Pipe(); p.standardOutput = out
        p.standardError = Pipe()
        try p.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return data
    }

    /// Discover unregistered web apps. Returns [] on any decode/exec issue.
    static func scan() -> [ScanResult] {
        guard let data = try? run(["scan", "--json"]),
              let results = try? JSONDecoder().decode([ScanResult].self, from: data)
        else { return [] }
        return results
    }

    /// Register a discovered app. If a start command was recovered, register it
    /// devkit-managed (restartable); otherwise register it external.
    static func register(_ r: ScanResult, name: String) throws {
        var args = ["register", name, "--port", String(r.port)]
        if let cmd = r.startCmdHint, !cmd.isEmpty {
            args += ["--cmd", cmd]
            if let path = r.pathHint, !path.isEmpty { args += ["--path", path] }
        } else {
            args += ["--managed-by", "external"]
        }
        _ = try run(args)
    }
}
```

UI sketch for the "Scan Now" sheet:

- Call `Devkit.scan()` off the main thread; show a row per result.
- Pre-fill an **editable** `TextField` with `suggestedName` (auto-fill, user can change).
- Show port, process, and title; show `startCmdHint` so the user can confirm/clear it
  before registering (secret-confirmation step).
- A per-row **Register** button calls `Devkit.register(_:name:)`, then re-polls
  `devkit list` (the existing path) so the new app appears immediately.

Run `scan` on demand (button) rather than on a tight timer; it's cheap but it does open
short-lived connections to every candidate port.
