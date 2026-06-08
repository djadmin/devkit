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

## Reliability

- 67 CLI lifecycle tests
- 16 installer smoke tests
- GitHub Actions on fresh macOS runners

Explicitly covers stale pid files, orphan recovery, restart pressure, port conflicts, and failed starts.

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

```text
~/devkit/apps.json        ← registry
~/devkit/Caddyfile        ← generated proxy config
~/devkit/dashboard.html   ← generated dashboard
~/devkit/logs/<name>.log  ← app logs
~/devkit/pids/<name>.pid  ← PID files
```

Override location with `DEVKIT_HOME`.

---

## License

MIT
