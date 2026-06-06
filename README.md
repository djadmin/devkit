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

**Option A — CLI + Menu bar app (recommended)**

```bash
brew tap djadmin/tap
brew install --cask devkit
```

Installs the CLI and the macOS menu bar app in one shot. Then run:

```bash
devkit bootstrap
brew services start caddy
```

**Option B — CLI only (Homebrew)**

```bash
brew tap djadmin/tap
brew install devkit
```

Then run `devkit bootstrap` and `brew services start caddy` to finish.

**Option C — one-liner**

```bash
curl -fsSL https://raw.githubusercontent.com/djadmin/devkit/main/install.sh | bash
```

Installs the CLI, starts Caddy, and offers to wire Claude in automatically. Build the menu bar app from source separately (see below).

---

## Wire into Claude Code

Add this to `~/.claude/CLAUDE.md` and Claude will register every new app automatically — you just visit the URL:

```markdown
## Local Web Apps — devkit
When building any local web app, register it with devkit:
  devkit register <slug> --port <port> --cmd "<start-cmd>"
  devkit start <slug>
Apps are then reachable at http://<slug>.localhost
```

The install script offers to add this for you. If you used Homebrew, paste it manually.

---

## Register an app yourself

```bash
# From inside your project directory:
devkit register notes --port 4010 --cmd "npm run dev -- --port 4010"
devkit start notes
# → http://notes.localhost

# Or specify a path explicitly:
devkit register notes --path ~/code/notes --port 4010 --cmd "npm run dev -- --port 4010"
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

Or open `http://dash.localhost` — the dashboard shows live status for every app.

---

## Requirements

macOS 13+, [Homebrew](https://brew.sh), `jq`, `caddy`

The install script handles all of these automatically.

---

## Menu bar app

A native macOS menu bar app ships alongside the CLI. It shows live status for all your apps, lets you start/stop/open them without touching a terminal, and updates instantly when `apps.json` changes.

Install via Homebrew (see above) or build from source:

```bash
git clone https://github.com/djadmin/devkit
cd devkit/MenuBarApp
./setup.sh
open DevkitBar.xcodeproj   # then ⌘R
```

See [MenuBarApp/README.md](MenuBarApp/README.md) for full details.

---

## How state works

```
apps.json          ← your registry (gitignored, stays on your machine)
apps.example.json  ← example schema (safe to commit)
Caddyfile          ← generated, gitignored
dashboard.html     ← generated, gitignored
```

`DEVKIT_HOME` controls where devkit looks for `apps.json`. It defaults to the directory where devkit is installed. Set it to a custom path to keep your registry elsewhere:

```bash
export DEVKIT_HOME=~/my-registry   # add to ~/.zshrc
```

---

## Migrating or reinstalling

If you're doing a fresh install and want to keep your existing apps:

```bash
# 1. Back up before reinstalling
cp "$DEVKIT_HOME/apps.json" ~/apps_backup.json

# 2. Install fresh
curl -fsSL https://raw.githubusercontent.com/djadmin/devkit/main/install.sh | bash

# 3. Restore your registry
cp ~/apps_backup.json ~/devkit/apps.json
devkit reload
devkit start-all
```

---

## Releasing (maintainers)

Cut a release by tagging — GitHub Actions builds the Mac app and updates the cask automatically:

```bash
git tag v0.1.1
git push origin v0.1.1
```

The workflow (`release.yml`) will:
1. Build `DevkitBar.app` on a macOS runner
2. Zip and upload it to the GitHub Release
3. Update `Casks/devkit.rb` in `djadmin/homebrew-tap` with the new SHA256

**First-time setup:** add a `HOMEBREW_TAP_GITHUB_TOKEN` secret to this repo with a GitHub token that has write access to `djadmin/homebrew-tap`:

```bash
gh auth token | gh secret set HOMEBREW_TAP_GITHUB_TOKEN --repo djadmin/devkit --body -
```

---

## Tests

```bash
bash test/test_registry.sh
# 30 tests, runs in a temp dir, never touches your real registry
```

---

## License

MIT
