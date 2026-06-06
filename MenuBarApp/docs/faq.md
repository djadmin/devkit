# FAQ

## General

**What is devkit, in one sentence?**  
A macOS menu bar app that tracks every local development service your AI agent builds, giving each one a `.localhost` URL and start/stop control.

**Is devkit free?**  
Yes. The CLI and menu bar app are MIT licensed and free forever.

**Is it open source?**  
Yes. [github.com/djadmin/devkit](https://github.com/djadmin/devkit)

**What's the status?**  
Public beta. Core features work. Some rough edges. Bug reports welcome via GitHub Issues.

---

## Installation

**How do I install the menu bar app?**  
Build from source for now — Homebrew cask coming soon. Run `./setup.sh` in the `MenuBarApp/` directory, then open `DevkitBar.xcodeproj` in Xcode and build.

**Does it auto-update?**  
Not yet. Auto-update via Sparkle is on the roadmap.

**What macOS version is required?**  
macOS 13 Ventura or later. Apple Silicon and Intel both supported.

---

## Agent Integration

**I set up CLAUDE.md. Will it work for existing projects?**  
The hook only runs when Claude creates new projects. For existing projects, register manually: `devkit register <name> --port <port>`.

**Does it work with Cursor's background agent mode?**  
Yes — Cursor reads `.cursor/rules/devkit.mdc` even in agent mode.

**Can I use it without an AI agent?**  
Absolutely. Just register apps manually with `devkit register`. The agent integration is a convenience, not a requirement.

**My agent registered the app with the wrong port. How do I fix it?**  
Edit `apps.json` directly (it's plain JSON) or run `devkit register <name> --port <correct-port>` again to update.

---

## How it works

**How does devkit detect if an app is running?**  
It attempts a TCP connection to `127.0.0.1:<port>` every 8 seconds. If it gets through, the app is running. No process inspection, no PID tracking — just port reachability.

**How do the `.localhost` URLs work?**  
devkit runs a local reverse proxy that routes `appname.localhost` to `localhost:<port>`. You need the devkit CLI running for this to work.

**Does devkit start apps automatically when I log in?**  
Not currently. Launch-at-login for the menu bar app is on the roadmap. Apps themselves need to be started manually or by your normal dev workflow.

**What happens if I register the same name twice?**  
The second registration overwrites the first in `apps.json`.

---

## Troubleshooting

**The menu bar app shows "devkit not found".**  
The CLI binary wasn't found at any of the expected paths. Make sure `devkit` is installed and in your PATH: `which devkit`. Then restart the menu bar app.

**An app shows as running but it's not responding in the browser.**  
The port is open but something else might be listening on it. Check with `lsof -i tcp:<port>`.

**Apps disappear after restarting the menu bar app.**  
The app reads from `apps.json` on startup. If the file was moved or deleted, re-register your apps.

**The app shows as stopped but I can access it in the browser.**  
The `.localhost` URL is routed through devkit's proxy. The proxy might be up even if the underlying app isn't responding on its direct port. Check both `appname.localhost` and `localhost:<port>`.

**Stop doesn't actually stop the process.**  
Known beta limitation. devkit stop sends a stop signal to the registered process. If the app is managed by nodemon, pm2, or another process supervisor, the supervisor will restart it. Stop those directly for now.

---

## Privacy & Data

**Does devkit send any data anywhere?**  
No. Everything runs locally. `apps.json` stays on your machine. No telemetry, no analytics, no account required.

**Does it need internet access?**  
Only to load web fonts on the landing page. The app itself is entirely offline.
