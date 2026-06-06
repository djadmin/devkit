# Getting Started

Get devkit running in under 5 minutes.

---

## Prerequisites

- macOS 13 Ventura or later
- devkit CLI installed
- Xcode 16 (to build the menu bar app from source)

---

## Step 1 — Install the CLI

```bash
# Homebrew (coming soon)
brew install devkit

# From source
git clone https://github.com/djadmin/devkit
cd devkit
make install
```

Verify:
```bash
devkit --version
```

---

## Step 2 — Build the menu bar app

```bash
cd devkit/MenuBarApp
./setup.sh        # installs xcodegen if needed, generates .xcodeproj
```

Then open in Xcode and run (⌘R), or build to your Applications folder.

---

## Step 3 — Register your first app

```bash
# In your project directory
devkit register my-api --port 3000 --cmd "npm run dev"
```

The app appears immediately in your menu bar at `my-api.localhost`.

---

## Step 4 — Set up your AI agent (optional but recommended)

This is the magic part. Add one snippet to your agent's global config and every app it builds from now on auto-registers.

**Claude Code** — add to `~/.claude/CLAUDE.md`:

```markdown
## devkit

After creating any web app or service:
devkit register <name> --port <port> --cmd "<start-command>"
```

See [agent-setup.md](agent-setup.md) for Cursor, Codex, and other agents.

---

## What you'll see

Once an app is registered, the menu bar shows:

- 🟢 **Running** — port is reachable, app is up
- 🔴 **Stopped** — port not responding
- 🟣 **External** — managed outside devkit (Docker, Homebrew, etc.)

Click any row to open the app in your browser. Use the ▶ / ■ buttons to start and stop.

---

## Next steps

- [Agent Setup](agent-setup.md) — set up Claude, Cursor, Codex
- [Supported Stacks](supported-stacks.md) — what frameworks work
- [FAQ](faq.md) — common questions
