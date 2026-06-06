# devkit

**The home for every local app your AI builds.**

If Claude, Cursor, or Codex keeps leaving you with a pile of forgotten `localhost` ports, devkit turns those apps into named projects you can route, reopen, and control from one place.

```text
localhost:4839   →   notes.localhost
localhost:3000   →   dashboard.localhost
localhost:5173   →   api-tester.localhost
```

devkit gives you:

- stable `.localhost` URLs
- one registry for app name, port, path, and start command
- safe `start` / `stop` / `restart` for devkit-managed apps
- logs, dashboard, and a native macOS menu bar app
- a way to track already-running apps without reworking them

## Who It's For

devkit is strongest for people who:

- use Claude Code, Cursor, or Codex to spin up lots of small local web apps
- keep many prototypes, admin tools, dashboards, or side projects on one Mac
- want to get back to an app later without remembering the port, folder, or start command

It is less compelling if you only ever run one or two long-lived services, or if your team already lives entirely inside Docker Compose or Kubernetes.

## Install

**Option A — CLI + Menu Bar App**

```bash
brew tap djadmin/tap
brew install --cask devkit
devkit bootstrap
brew services start caddy
```

**Option B — CLI Only**

```bash
brew tap djadmin/tap
brew install devkit
devkit bootstrap
brew services start caddy
```

**Option C — Installer Script**

```bash
curl -fsSL https://raw.githubusercontent.com/djadmin/devkit/main/install.sh | bash
```

The script installs the CLI, bootstraps the registry and proxy, and offers to wire Claude Code automatically.

## Start The Way You Actually Work

### 1. You Already Have Apps Running

Open the menu bar app and use `Track` / `Track All`, or register one directly:

```bash
devkit register atlas --port 7780 --managed-by external
```

That gives the app a stable name and URL without asking devkit to own its lifecycle.

### 2. You Want Future AI-Built Apps To Auto-Register

Add this once to `~/.claude/CLAUDE.md`:

````markdown
## Local Web Apps — devkit
After creating any local web app or service:
  devkit register <slug> --port <port> --cmd "<start-cmd>"
  devkit start <slug>
The app should be reachable at http://<slug>.localhost
````

See [MenuBarApp/docs/agent-setup.md](MenuBarApp/docs/agent-setup.md) for Cursor, Codex, Copilot, and Windsurf snippets.

### 3. You Prefer Manual CLI Control

```bash
devkit register notes --path ~/code/notes --port 4010 --cmd "npm run dev -- --port 4010"
devkit start notes
devkit open notes
```

## Daily Commands

| Command | What it does |
|---|---|
| `devkit list` | See every registered app and its status |
| `devkit open <name>` | Open the app in the browser |
| `devkit edit <name>` | Jump into the project and launch Claude Code |
| `devkit start <name>` | Start one app |
| `devkit stop <name>` | Stop one app |
| `devkit restart <name>` | Restart one app safely |
| `devkit start-all` | Bring everything back after a reboot |
| `devkit stop-all` | Stop every devkit-managed app |
| `devkit logs <name>` | Tail the log file |
| `devkit show <name>` | Print the full stored metadata |

You can also open `http://dash.localhost` for a browser dashboard, or use the macOS menu bar app for search, start/stop, open, and copy URL.

## How Lifecycle Works

devkit supports two operating modes:

- **devkit-managed apps**: you register a `--cmd`, then devkit owns `start`, `stop`, logs, pid files, and restart safety.
- **external apps**: you register with `--managed-by external`, and devkit tracks naming, URL routing, and status without trying to supervise the process.

For devkit-managed apps, the CLI now uses both **PID state and port ownership** to avoid stale pid files, orphaned listeners, and unrelated process kills during restart cycles.

## Reliability

Release confidence is backed by automated macOS checks:

- `62` CLI lifecycle tests
- `16` installer smoke tests
- GitHub Actions on fresh macOS runners for CLI and installer paths

The CLI explicitly covers stale pid files, orphan recovery, restart pressure, port conflicts, and failed starts.

## Requirements

- macOS 13+
- [Homebrew](https://brew.sh)
- `jq`
- `caddy`

The installer handles these automatically. Homebrew users only need to run `devkit bootstrap` and start the Caddy service once.

## Menu Bar App

The native menu bar app is the easiest way to use devkit day to day:

- see running, stopped, and external apps at a glance
- search by app name or hostname
- start and stop devkit-managed apps
- copy URLs and open apps without touching the terminal
- track existing running ports during onboarding

Install it with the cask above, or build from source:

```bash
git clone https://github.com/djadmin/devkit
cd devkit/MenuBarApp
./setup.sh
open DevkitBar.xcodeproj
```

See [MenuBarApp/README.md](MenuBarApp/README.md) for the app-specific docs.

## State And Files

```text
apps.json          ← your local registry
apps.example.json  ← schema example
Caddyfile          ← generated proxy config
dashboard.html     ← generated dashboard
logs/<name>.log    ← app logs
pids/<name>.pid    ← PID file for devkit-managed apps
```

`DEVKIT_HOME` controls where devkit stores this state. It defaults to the install directory, usually `~/devkit`.

## Releasing

If you are shipping devkit itself, use [RELEASING.md](RELEASING.md).

## Tests

```bash
bash test/test_registry.sh
bash test/test_install.sh
```

Both suites run in temp state and do not touch your real registry.

## License

MIT
