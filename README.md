# devkit

You build a lot of apps with Claude. After a while, they're scattered across random ports — 3000, 4010, 5173, 8080 — and you can't remember which is which, what's still running, or how to get back into any of them.

devkit fixes that. Every app gets a permanent home at `http://name.localhost`. One dashboard shows everything. One command gets you back into any project with Claude already running.

The best part: wire it into your global `CLAUDE.md` once, and Claude handles registration automatically. You just open the URL.

---

## How it works in practice

You ask Claude to build a dashboard. Claude builds it, registers it with devkit, starts it. You open `http://my-dashboard.localhost`. That's it — you never typed a port.

Next week you ask Claude to build something else. Same thing. Everything shows up at `http://dash.localhost`. Nothing gets lost.

After a reboot: `devkit start-all`. Everything comes back.

---

## Setup (one time)

**1. Install**

```bash
git clone https://github.com/djadmin/devkit.git ~/devkit
echo 'export PATH="$HOME/devkit/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
devkit bootstrap
brew services start caddy
pm2 startup && pm2 save
```

**2. Wire into Claude (the important part)**

Add this to your global `~/.claude/CLAUDE.md`:

```markdown
## Local Web Apps — devkit

Every local web app goes through devkit. When building a new web app, pick a
fixed port and run:

  devkit register --name <slug> --path <abs-path> --port <port> --cmd "<start-cmd>"
  devkit start <slug>

Apps are then reachable at http://<slug>.localhost.
```

That's it. From now on, Claude registers every new app automatically.

---

## Registering an app yourself

If you're not using Claude, or want to register something manually:

```bash
devkit register \
  --name notes \
  --path ~/code/notes \
  --port 4010 \
  --cmd "npm run dev -- --port 4010"

devkit start notes
# → http://notes.localhost is live
```

---

## Commands you'll actually use

```bash
devkit list                    # see everything and its status
devkit open <name>             # open in browser
devkit edit <name>             # cd into project and launch Claude Code
devkit start-all               # bring everything back after a reboot
devkit start|stop <name>       # control individual apps
devkit rename <old> <new>      # rename an app and its URL
devkit logs <name>             # tail logs
```

Or just open `http://dash.localhost` — the dashboard shows live status for every app.

---

## What devkit stores for each app

```json
{
  "name": "notes",
  "hostname": "notes.localhost",
  "port": 4010,
  "path": "/Users/you/code/notes",
  "repo": "git@github.com:you/notes.git",
  "claudeMd": "/Users/you/code/notes/CLAUDE.md",
  "startCmd": "npm run dev -- --port 4010",
  "managedBy": "pm2"
}
```

The `claudeMd` field means `devkit edit <name>` opens the project with full AI context intact — no re-explaining what the project is.

---

## Requirements

- macOS
- [Homebrew](https://brew.sh)
- [Caddy](https://caddyserver.com) (installed by `devkit bootstrap`)
- [pm2](https://pm2.keyv.io) (`npm install -g pm2`)
- [jq](https://jqlang.github.io/jq/) (`brew install jq`)

---

## How state works

- `apps.json` — your local registry, gitignored (stays on your machine)
- `apps.example.json` — example schema, safe to commit
- `Caddyfile`, `dashboard.html` — generated from `apps.json`, gitignored

Set `DEVKIT_HOME` to store the registry somewhere other than the repo root.

---

## Running tests

```bash
bash test/test_registry.sh
```

---

## What's next

The CLI is the foundation. Ideas on deck: a menu bar app, a web dashboard with drag-to-reorder, and deeper Claude integration. See [IDEAS.md](./IDEAS.md).
