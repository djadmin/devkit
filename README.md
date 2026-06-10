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
| `devkit rename <old> <new>` | Rename a running app safely |
| `devkit update <name>` | Update port, cmd, path, or description |
| `devkit remove <name>` | Deregister an app |

Browse everything at `http://dash.localhost`.

---

## How Lifecycle Works

- **devkit-managed**: register with `--cmd`. devkit owns start, stop, logs, pid files, and restart safety.
- **external**: register with `--managed-by external`. devkit tracks name, URL, and status — does not supervise the process.

---

## Crash Recovery (opt-in)

By default devkit starts an app and steps back — if the app later dies, it stays down
until you start it again. Opt a devkit-managed app into automatic recovery with a
restart policy:

```bash
devkit register api --port 3000 --cmd "npm start" --restart on-failure
# or change it later:
devkit update api --restart on-failure        # policies: no (default) | on-failure | always
```

Then install the background supervisor once:

```bash
devkit supervise install      # installs a launchd agent that watches your apps
devkit supervise status       # list supervised apps + agent state
devkit supervise uninstall    # remove it
```

How it behaves:

- It only revives apps you actually want running. `devkit start` marks intent up;
  `devkit stop` / `stop-all` marks it down — so the supervisor **never restarts something
  you deliberately stopped**.
- Crash loops are throttled with exponential backoff (5s → capped at 5min), reset once an
  app comes back healthy.
- Each pass also re-checks the proxy, so `.localhost` routing self-heals even when no
  devkit command is running.

`devkit supervise tick` runs a single pass by hand (this is what the launchd agent calls).

Tuning env vars: `DEVKIT_SUPERVISE_INTERVAL` (seconds between checks, default 10),
`DEVKIT_SUPERVISE_BACKOFF_BASE` (default 5), `DEVKIT_SUPERVISE_BACKOFF_CAP` (default 300).
For a non-Homebrew Caddy setup, set `DEVKIT_CADDY_MANAGED=1` so reloads still apply.

---

## Reliability

- 97 CLI lifecycle tests (including crash recovery, restart policy, and the launchd plist)
- 18 installer smoke tests
- GitHub Actions on fresh macOS runners

Explicitly covers stale pid files, orphan recovery, restart pressure, port conflicts,
failed starts, out-of-band `apps.json` edits, malformed registries, and supervised crash
recovery.

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
