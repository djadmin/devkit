# devkit

**Give every local app a home.**

You build a lot of local apps — side projects, POCs, AI experiments. After a while they're scattered across forgotten ports like `:3847`, `:5173`, `:8080`. You can't remember which is which, what's still running, or how to get back into any of them.

devkit fixes that. One registry, stable URLs, one command to get back in.

```
localhost:4839   →   notes.localhost
localhost:3000   →   dashboard.localhost
localhost:5173   →   api-tester.localhost
```

---

## Install

**Option A — one-liner (recommended)**

```bash
curl -fsSL https://raw.githubusercontent.com/djadmin/devkit/main/install.sh | bash
```

Installs everything, starts Caddy, and offers to wire Claude in automatically.

**Option B — Homebrew**

```bash
brew tap djadmin/tap
brew install devkit
```

Then run `devkit bootstrap` and `brew services start caddy` to finish.

---

## Wire into Claude Code

Add this to `~/.claude/CLAUDE.md` and Claude will register every new app automatically — you just visit the URL:

```markdown
## Local Web Apps — devkit
When building any local web app, register it with devkit:
  devkit register --name <slug> --path <abs-path> --port <port> --cmd "<start-cmd>"
  devkit start <slug>
Apps are then reachable at http://<slug>.localhost:8080
```

The install script offers to add this for you. If you used Homebrew, paste it manually.

---

## Register an app yourself

```bash
devkit register \
  --name notes \
  --path ~/code/notes \
  --port 4010 \
  --cmd "npm run dev -- --port 4010"

devkit start notes
# → http://notes.localhost:8080
```

devkit auto-detects the git remote and any `CLAUDE.md` in the project.

---

## Daily commands

| Command | What it does |
|---|---|
| `devkit list` | See all apps and their status |
| `devkit open <name>` | Open in browser |
| `devkit edit <name>` | cd into project and launch Claude Code |
| `devkit start-all` | Bring everything back after a reboot |
| `devkit start / stop <name>` | Control individual apps |
| `devkit rename <old> <new>` | Rename an app and its URL |
| `devkit logs <name>` | Tail logs |
| `devkit show <name>` | Print full app metadata |

Or open `http://dash.localhost:8080` — the dashboard shows live status for every app.

---

## Requirements

macOS, [Homebrew](https://brew.sh), `jq`, `caddy`, `pm2`

The install script handles all of these. For Homebrew installs, `npm install -g pm2` is the only manual step.

---

## How state works

```
apps.json          ← your registry (gitignored, stays on your machine)
apps.example.json  ← example schema (safe to commit)
Caddyfile          ← generated, gitignored
dashboard.html     ← generated, gitignored
```

Set `DEVKIT_HOME` to store the registry somewhere other than the repo root.

---

## Tests

```bash
bash test/test_registry.sh
# 30 tests, runs in a temp dir, never touches your real registry
```

---

## License

MIT
