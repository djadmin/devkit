# Getting Started

Get devkit useful in the first five minutes, not after a long setup session.

## 1. Install devkit

**Recommended**

```bash
brew tap djadmin/tap
brew install --cask devkit
devkit bootstrap
brew services start caddy
```

**CLI only**

```bash
brew tap djadmin/tap
brew install devkit
devkit bootstrap
brew services start caddy
```

**Installer script**

```bash
curl -fsSL https://raw.githubusercontent.com/djadmin/devkit/main/install.sh | bash
```

Verify:

```bash
devkit version
```

## 2. Open the menu bar app

If you installed the cask, launch `DevkitBar`.

On first run, it handles the two common starting points:

- **Existing apps already running**: use `Track` or `Track All`
- **Fresh AI-first setup**: copy the agent snippet and let future apps register themselves

## 3. Choose your onboarding path

### Existing apps

If you already have a service running on a port, track it as external:

```bash
devkit register atlas --port 7780 --managed-by external
```

devkit will give it a stable `.localhost` URL without trying to supervise the process.

### New apps you want devkit to manage

```bash
devkit register notes --path ~/code/notes --port 4010 --cmd "npm run dev -- --port 4010"
devkit start notes
```

Now the app is reachable at `http://notes.localhost`.

## 4. Set up your AI agent

This is where devkit becomes a habit instead of a one-off tool. Add one global rule and future apps register automatically.

Start with [agent-setup.md](agent-setup.md). Claude Code is the most mature path today, but snippets are included for Cursor, Codex, Copilot, and Windsurf.

## 5. Daily workflow

- use `devkit list` to see everything registered
- use `devkit open <name>` to jump into an app
- use `devkit start-all` after a reboot
- use the menu bar app for fast visual control and search
- use `http://dash.localhost` for the browser dashboard

## What good onboarding looks like

By the end of setup, a new user should be able to answer these four questions immediately:

- what apps do I have?
- which ones are running?
- how do I open one again?
- how do future AI-built apps land here automatically?

If those are not obvious, setup is not done yet.
