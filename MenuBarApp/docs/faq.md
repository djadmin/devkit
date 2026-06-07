# FAQ

## The basics

### What is devkit in one sentence?

devkit gives every local app your AI builds a stable name, `.localhost` URL, and one place to reopen or control it on macOS.

### Who is it for?

Anyone on macOS who keeps building or accumulating local web apps — especially people using Claude Code, Cursor, Codex, or similar AI tools that generate runnable apps quickly. The pain is simple: you end up with 10+ things on random ports and no memory of what each one is.

### Is it only for AI-generated apps?

No. That is just the strongest use case because AI tools create apps faster than any human can track them.

You can register any local app manually, or track one that is already running. The AI-agent workflow matters because it turns devkit into a habit instead of a one-off tool — the agent registers every new app automatically.

### Is it free?

Yes. devkit is MIT-licensed, open source, and free. There is no account, no subscription, and no telemetry.

### Does devkit send any data anywhere?

No. Your registry, app state, and usage all stay on your machine. devkit has no network calls, no analytics, and no telemetry.

---

## Installation

### What do I need before installing?

- macOS 14 or later (menu bar app) / macOS 13 or later (CLI only)
- [Homebrew](https://brew.sh)
- `jq` and `caddy` — installed automatically by the installer or by `brew install jq caddy`

### What are the install options?

**Recommended — CLI + menu bar app:**
```bash
brew tap djadmin/tap
brew install --cask devkit
devkit bootstrap
brew services start caddy
```

**CLI only:**
```bash
brew tap djadmin/tap
brew install devkit
devkit bootstrap
brew services start caddy
```

**Installer script (no Homebrew tap required):**
```bash
curl -fsSL https://raw.githubusercontent.com/djadmin/devkit/main/install.sh | bash
```

### Do I need to run `devkit bootstrap` manually?

No, if you used the installer script — it calls bootstrap for you.

If you used `brew install`, run `devkit bootstrap` once after. It creates `~/devkit/apps.json`, generates the initial `Caddyfile`, and links the Caddy config.

### Why does Caddy need to run on port 80?

Caddy is the reverse proxy that makes `http://app-name.localhost` work. Port 80 is the standard HTTP port. Without it, `.localhost` routing would not work and you would have to use `localhost:3000` style URLs.

If something else is already on port 80, run `lsof -nP -i :80 | grep LISTEN` to find it.

### Caddy is already running. Is that a problem?

No. If Caddy's admin API is responding (`curl http://localhost:2019/config/`), devkit will use it directly and skip the `brew services start` step. You only need to start Caddy once.

### The install finished but `devkit` is not found in my shell.

The installer adds `~/devkit/bin` to your `PATH` in `~/.zshrc` and `~/.bash_profile`. Open a new terminal tab, or run `source ~/.zshrc`, then try again.

---

## Existing apps and first-time onboarding

### I already have apps running. How do I add them to devkit?

**Option 1 — Menu bar app (recommended for first run):**
Open DevkitBar. The onboarding screen scans common dev ports and shows what it finds. Click the `↗` arrow next to a port to see what's running there, name it, and click Track. Or use **Track All** to register everything at once.

**Option 2 — CLI:**
```bash
devkit register my-api --port 3000 --managed-by external
```

The `--managed-by external` flag tells devkit you own the process start/stop, not devkit. The app gets a `.localhost` URL but no start/stop button.

### I tracked an app as external but now I want devkit to manage it. How do I upgrade it?

Re-register it with a start command:
```bash
devkit register my-api --port 3000 --cmd "npm run dev -- --port 3000"
```

This overwrites the entry. Now devkit can start and stop it.

### The scanner found a port but I do not know what is running there.

In the menu bar onboarding, click the **↗** arrow next to the port. It opens `http://localhost:<port>` in your browser so you can see what is there before naming it.

### The scanner did not find my app.

The scanner checks a fixed list of common dev ports. If your app is on an unusual port (like 9876), it will not appear automatically. Register it manually:
```bash
devkit register my-api --port 9876 --managed-by external
```

Or run `devkit start-all` scanning mode is only for onboarding — day-to-day you manage apps directly.

### Can I use devkit with Docker containers?

Yes. Register the container's exposed port as external:
```bash
devkit register postgres --port 5432 --managed-by external
devkit register redis --port 6379 --managed-by external
```

devkit gives them a URL and visibility but does not try to manage the Docker lifecycle.

### Can I use devkit alongside Homebrew services, pm2, or launchd?

Yes. Same pattern — register as external. devkit will show the app's status (running/stopped based on port reachability) without interfering with whatever is managing the process.

```bash
devkit register mysql --port 3306 --managed-by external
```

### My app needs environment variables to start. How do I set those?

Embed them in the start command:
```bash
devkit register api --port 4000 --cmd "NODE_ENV=development PORT=4000 npm start"
```

Or wrap in a shell script and point to that. devkit runs whatever string you give to `--cmd` through `sh -c`.

### My app listens on `0.0.0.0` (all interfaces) instead of `127.0.0.1`. Does that matter?

No. devkit detects the port as open regardless of bind address.

---

## AI agent integration

### Which AI agents does devkit support?

Claude Code, Cursor, OpenAI Codex, GitHub Copilot, and Windsurf. Full copy-paste snippets for each are in [agent-setup.md](agent-setup.md).

### Where does the Claude Code snippet go?

`~/.claude/CLAUDE.md` — this is your global instruction file. Claude Code reads it in every session, on every project. One snippet added once, and every future app gets registered.

### I added the snippet but Claude is not registering my apps.

Check three things:
1. `devkit` is on your PATH: run `which devkit` in a terminal
2. The snippet is in `~/.claude/CLAUDE.md`, not just a project-level `CLAUDE.md`
3. The snippet text matches what is in [agent-setup.md](agent-setup.md) — stale or incomplete instructions are the most common failure

### The agent built an app before I installed devkit. How do I add it now?

Register it manually:
```bash
devkit register my-app --port 3000 --path ~/code/my-app --cmd "npm run dev"
```

Or track it as external if you do not know the start command:
```bash
devkit register my-app --port 3000 --managed-by external
```

### Can I use devkit with multiple AI tools at once?

Yes. Each agent's config is independent. You can have Claude Code registering apps via `~/.claude/CLAUDE.md`, Cursor via `.cursor/rules/devkit.mdc`, and Codex via `AGENTS.md` — all pointing to the same devkit registry.

---

## Lifecycle: start, stop, restart

### What does "devkit-managed" mean vs "external"?

- **devkit-managed**: devkit knows the start command. It can start, stop, and restart the app, manage the pid file, and detect crashes.
- **external**: devkit knows the app exists and its port, but something else controls the process. It shows status (running/stopped by port check) but cannot start or stop it.

### What happens if a devkit-managed app crashes?

devkit is not a daemon supervisor. It will not automatically restart a crashed app. On the next status check (when you open the menu bar or run `devkit list`), the app will show as stopped. Restart it with:
```bash
devkit start my-app
# or from the menu bar app's restart button
```

### Start fails with "port already in use". What do I do?

Run `lsof -nP -i :<port> | grep LISTEN` to find what owns the port. devkit intentionally refuses to kill unrelated processes. Options:
- stop the conflicting process manually
- register your app on a different port with `devkit register` using a new port
- if the process is a stale devkit app, run `devkit stop <name>` first

### My app has a stale `.pid` file and won't start.

devkit's lifecycle hardening handles this automatically. When you run `devkit start`, it checks whether the pid in the file actually maps to a live process on the registered port. If not, it clears the stale file and starts fresh.

### Can I start all my apps at once after a reboot?

```bash
devkit start-all
```

This starts every devkit-managed app in the registry. External apps are not touched (something else starts those).

### Can I stop everything before shutting down?

```bash
devkit stop-all
```

---

## Daily workflow

### How do I see all my registered apps?

```bash
devkit list
```

Or open the menu bar app and search or scroll.

### How do I jump into an app's project directory?

```bash
devkit edit my-app
```

This opens the project directory with Claude Code running.

### How do I check logs for an app?

```bash
devkit logs my-app
```

### How do I rename an app?

```bash
devkit register new-name --port <same-port> --cmd "<same-cmd>" --path <same-path>
devkit remove old-name
```

There is no `devkit rename` command. Re-registering and removing is the current path.

### How do I remove an app from the registry?

```bash
devkit remove my-app
```

This stops the app if running, removes the pid file, and removes it from `apps.json`. It does not delete your project files.

### The `.localhost` URL returns a 502. What is wrong?

A 502 from Caddy means the proxy route exists but the app is not running. Start the app:
```bash
devkit start my-app
```

Or check that Caddy is running: `curl http://localhost:2019/config/`

### `dash.localhost` is not loading.

Caddy is probably not running. Check with `brew services list | grep caddy`, then:
```bash
brew services start caddy
```

If it is already listed as started but not working, try `devkit reload` to push the Caddyfile to Caddy's API.

---

## Troubleshooting

### `devkit` says "command not found" even in a new shell.

Your `PATH` is not updated. Check that `~/devkit/bin` appears in your PATH:
```bash
echo $PATH | tr ':' '\n' | grep devkit
```

If missing, add it manually:
```bash
echo 'export PATH="$HOME/devkit/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### The menu bar app shows "Starting up…" and never loads.

The menu bar app looks for the devkit CLI. If it cannot find it, it stays in a loading state. Make sure:
1. `devkit` is on your PATH in a normal terminal
2. You ran `devkit bootstrap` at least once
3. `~/devkit/apps.json` exists

If those are all true, quit and reopen the app.

### The menu bar app shows apps but their status is wrong.

Status in the menu bar is based on port reachability, not pid files. If an app is showing as stopped but you know it is running, check whether it is listening on the expected port:
```bash
lsof -nP -i :<port> | grep LISTEN
```

If it is running on a different port than registered, re-register it with the correct port.

### `devkit reload` is failing.

`devkit reload` regenerates the `Caddyfile` and pushes it to Caddy's admin API. Failures usually mean Caddy is not running. Check:
```bash
curl http://localhost:2019/config/
```

If that fails, start Caddy and try again.

### An app will not stop — the process keeps running.

devkit only stops processes it started (matched by pid file + port ownership). If the process was started externally, devkit will not kill it. Stop it manually:
```bash
kill $(lsof -nP -i :<port> -sTCP:LISTEN | awk 'NR>1 {print $2}')
```

---

## Advanced usage

### Can I register an app without a project path?

Yes. `--path` is optional. If you skip it, `devkit edit` will not know where to open the project, but everything else works.

### Can I use a custom `.localhost` domain name?

The domain is derived from the app name. If you register as `notes-api`, the URL is `http://notes-api.localhost`. There is no way to set a separate domain — choose your name carefully.

### Can I use a TLD other than `.localhost`?

Not currently. `.localhost` is hardcoded as the TLD in `apps.json`.

### Can I share my registry with a teammate?

`apps.json` is gitignored by design because paths are machine-specific. If you want to share the list of apps and their ports, commit `apps.example.json` and have teammates re-register locally.

### Can I run devkit on a remote or shared machine?

The menu bar app is macOS-only. The CLI technically runs anywhere bash + Caddy + jq are available, but it is not tested outside macOS.

---

## Uninstalling

### How do I completely remove devkit?

```bash
# Stop all managed apps
devkit stop-all

# Remove the devkit home directory (registry, binary, config)
rm -rf ~/devkit

# Remove the PATH lines from your shell config
# Remove these two lines from ~/.zshrc and ~/.bash_profile:
#   # devkit
#   export PATH="$HOME/devkit/bin:$PATH"

# Remove the Caddy symlink devkit created
rm -f /opt/homebrew/etc/Caddyfile  # only if it was a devkit symlink

# Stop Caddy if you no longer need it
brew services stop caddy
```

Your apps and project files are not affected. Only the registry and devkit tooling are removed.

### Will removing devkit break my apps?

No. devkit does not modify your app code or configuration. Removing devkit removes the registry, proxy routes, and the binary. Your apps continue to run on their ports; they just lose the `.localhost` URLs and devkit's lifecycle management.

---

## Architecture and design

### How does devkit know whether an app is running?

Two layers:

- **CLI**: manages lifecycle with pid files plus port ownership checks. Only stops or takes action on processes it owns.
- **Menu bar app**: checks port reachability for display purposes. Fast, no pid access needed.

### Why is the CLI required even if I just want the menu bar app?

The CLI bootstraps the registry (`apps.json`), owns lifecycle, writes pid files, and generates the routing config. The menu bar app is a visual layer on top of the CLI's registry — it reads but does not write lifecycle state directly.

### Why macOS only?

The menu bar app is native macOS SwiftUI. The install story (Homebrew + Caddy) is macOS-optimised. The target user — someone building lots of local apps with AI tools — is overwhelmingly on macOS.

Linux and Windows support are not planned short-term. The CLI is mostly portable bash, but the full product is intentionally macOS-first.

### Why Caddy instead of nginx or another proxy?

Caddy has a live admin API that lets devkit push config changes without reloads or restarts. When you register a new app, devkit can immediately update the routing without touching the Caddy process. nginx does not have this.

### Why pid files instead of a daemon?

devkit is not a process supervisor. It is a registry and launcher. Pid files are the minimal, transparent mechanism to track what was started and verify ownership before stopping. No background service, no daemon, no extra process.

---

## What devkit does not do

- **Auto-restart crashed apps** — devkit is not pm2 or launchd. Use those if you need crash recovery.
- **Manage remote services** — devkit is for local development only.
- **Handle non-TCP apps** — Unix socket apps, desktop GUI apps, and CLI tools are not supported.
- **Provide HTTPS locally** — `.localhost` URLs are HTTP only.
- **Multi-machine sync** — the registry is local. There is no cloud sync.
- **Team shared state** — `apps.json` is machine-local by design.
