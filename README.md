# devkit

**The home for every local app your AI builds.**

If Claude, Cursor, or Codex keeps leaving you with a pile of forgotten `localhost` ports, devkit turns those apps into named projects you can route, reopen, and control from one place.

```text
localhost:4839   →   notes.localhost
localhost:3000   →   dashboard.localhost
localhost:5173   →   api-tester.localhost
```

---

## Install

```bash
brew tap djadmin/tap
brew install devkit
devkit bootstrap
```

The Mac app (menu bar + full window) is available separately at [djadmin.github.io/devkit](https://djadmin.github.io/devkit).

---

## Wire Your AI Agent (do this first)

Add one snippet to your agent's global config. Every app it builds after that registers itself automatically — no extra steps.

**Claude Code** — add to `~/.claude/CLAUDE.md`:

```markdown
## devkit — App Registration
After creating any local web app or service:
  devkit register <slug> --port <port> --cmd "<start-cmd>"
  devkit start <slug>
```

**OpenAI Codex** — add to `~/.codex/AGENTS.md`:

```markdown
## devkit — App Registration
After creating any local web app or service:
  devkit register <slug> --port <port> --cmd "<start-cmd>"
```

**Cursor** — add to `.cursor/rules/devkit.mdc`:

```markdown
---
alwaysApply: true
---
After creating any web app:
  devkit register <slug> --port <port> --cmd "<start-cmd>"
```

**Windsurf** — add to `.windsurf/rules/devkit.md` with the same content as Cursor.

---

## Track Apps You Already Have Running

```bash
# Track without taking over lifecycle
devkit register atlas --port 7780 --managed-by external

# Track and let devkit own start/stop
devkit register notes --path ~/code/notes --port 4010 --cmd "npm run dev -- --port 4010"
devkit start notes
```

### Find apps you forgot to register

`devkit scan` looks for web apps already listening on localhost that aren't in the
registry yet — useful when another tool started something with a raw `npm run dev` and a
bare `localhost:5173`. It detects only HTTP/HTML services (databases and JSON-only APIs
are skipped), suggests a name from the page title, and best-effort recovers the start
command so you can register it as managed or external.

```bash
devkit scan          # human-readable table of unregistered web apps
devkit scan --json   # machine-readable (used by the menu bar app's "Scan Now")
```

See [docs/scan.md](docs/scan.md) for detection details, tuning, and the menu bar
integration contract.

---

## Daily Commands

| Command | What it does |
|---|---|
| `devkit list` | See every registered app and its status |
| `devkit start <name>` | Start a devkit-managed app |
| `devkit stop <name>` | Stop a devkit-managed app |
| `devkit restart <name>` | Restart safely |
| `devkit start-all` | Bring everything back after a reboot |
| `devkit stop-all` | Stop all devkit-managed apps |
| `devkit open <name>` | Open in browser |
| `devkit edit <name>` | Jump into the project directory with Claude Code |
| `devkit logs <name>` | Tail the log file |
| `devkit show <name>` | Print full stored metadata |
| `devkit scan` | Find running web apps not yet registered |
| `devkit rename <old> <new>` | Rename a running app safely |
| `devkit update <name>` | Update port, cmd, path, or description |
| `devkit remove <name>` | Deregister an app |

Browse everything at `http://dash.localhost`.

---

## How Lifecycle Works

- **devkit-managed**: register with `--cmd`. devkit owns start, stop, logs, pid files, and restart safety.
- **external**: register with `--managed-by external`. devkit tracks name, URL, and status — does not supervise the process.

---

## Reliability

- 114 CLI lifecycle tests + 23 scan tests
- 18 installer smoke tests
- GitHub Actions on fresh macOS runners

Explicitly covers stale pid files, orphan recovery, port conflicts, fail-fast on a
crashing start, out-of-band `apps.json` edits, and malformed registries.

devkit manages an app's lifecycle on demand (`start` / `stop` / `restart`); it does not
run a background daemon, so a crashed app stays down until you start it again.

```bash
bash test/test_registry.sh
bash test/test_install.sh
```

---

## Requirements

- macOS 13+
- [Homebrew](https://brew.sh)
- `jq`
- `caddy`

`devkit bootstrap` handles all of these.

---

## State Files

devkit keeps its data in `~/.devkit` — a hidden dotfile directory, like `~/.ssh`,
`~/.aws`, or `~/.kube`. This is separate from where the binary is installed, so the
registry survives reinstalls and Homebrew upgrades and never clutters your home folder.

```text
~/.devkit/apps.json        ← registry (source of truth)
~/.devkit/Caddyfile        ← generated proxy config
~/.devkit/dashboard.html   ← generated dashboard
~/.devkit/logs/<name>.log  ← app logs
~/.devkit/pids/<name>.pid  ← PID files
```

Override the location with `DEVKIT_HOME` (e.g. `export DEVKIT_HOME="$XDG_DATA_HOME/devkit"`).

The binary itself lives wherever your install method puts it — `/opt/homebrew/bin/devkit`
(Homebrew), `~/.local/bin/devkit` (install script), or `bin/devkit` in a source checkout.
`devkit paths` prints exactly where everything is.

> **Upgrading from an older devkit?** Earlier versions stored data in `~/devkit`. The
> first time you run any command, devkit moves your registry to `~/.devkit` automatically
> and leaves the old binary/checkout untouched. You can then remove the stale
> `export PATH=".../devkit/bin:$PATH"` line from your shell rc if the installer added one.

---

## License

MIT
