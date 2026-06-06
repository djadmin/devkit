<div align="center">
  <img src="DevkitBar/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="96" alt="devkit icon" />
  <h1>devkit</h1>
  <p><strong>The home for every local app your AI builds.</strong></p>
  <p>The native macOS control plane for your devkit registry.</p>

  <p>
    <img src="https://img.shields.io/badge/status-beta-orange?style=flat-square" alt="Beta" />
    <img src="https://img.shields.io/badge/macOS-13%2B-brightgreen?style=flat-square&logo=apple" alt="macOS 13+" />
    <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift" alt="Swift 5.9" />
    <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="MIT License" />
    <img src="https://img.shields.io/badge/agent--first-Claude%20%7C%20Cursor%20%7C%20Codex-6366f1?style=flat-square" alt="Agent first" />
  </p>

  <img src="docs/assets/screenshot.png" alt="devkit menu bar screenshot" width="360" />
</div>

---

## Why This App Exists

The CLI solves registration, routing, and lifecycle. The menu bar app solves the part people actually feel every day:

- "What is running right now?"
- "Which app was on `:7780`?"
- "How do I reopen the thing Claude made yesterday?"
- "Can I stop or start that app without dropping back into a terminal?"

If you build lots of local tools, devkit gives them a shelf. The menu bar app is that shelf.

## Best Fit

This app is built for:

- Claude Code, Cursor, and Codex users who create lots of small local apps
- indie hackers and prototypers with a growing pile of `localhost` projects
- people who want existing running apps and future AI-built apps to live in one place

## Install

**Recommended**

```bash
brew tap djadmin/tap
brew install --cask devkit
devkit bootstrap
brew services start caddy
```

**Build from source**

```bash
git clone https://github.com/djadmin/devkit
cd devkit/MenuBarApp
./setup.sh
open DevkitBar.xcodeproj
```

## First-Run Experience

When you open the menu bar app, onboarding is designed for the two real starting points:

### You Already Have Apps Running

devkit scans for open local ports that are not yet registered. You can:

- `Track` one port at a time
- `Track All` to bring your current pile of apps into devkit immediately

Tracked ports are registered as external apps, so devkit gives them names and URLs without trying to take over their process management.

### You Want Future Apps To Register Themselves

The second onboarding step gives you a ready-to-paste Claude Code snippet. Once added globally, future apps Claude builds can:

- register themselves
- get a stable `.localhost` URL
- appear in the menu bar without manual setup

See [docs/agent-setup.md](docs/agent-setup.md) for Cursor, Codex, Copilot, and Windsurf.

## What The App Does Well

- live list of running, stopped, and external apps
- search by app name or hostname
- one-click open, copy URL, start, and stop
- bulk `Start All` / `Stop All` actions
- registry file watching, so changes appear without a manual refresh
- onboarding that works for both fresh installs and existing running apps

## Status Model

The menu bar app reads `apps.json` and checks whether each port is reachable.

- for **devkit-managed apps**, the CLI owns lifecycle safety, pid files, logs, and restart behavior
- for **external apps**, the menu bar app gives you visibility and routing, but no lifecycle control

That split is intentional: the CLI is the source of truth for process management, and the app is the fast visual layer on top.

## Docs

- [Getting Started](docs/getting-started.md)
- [Agent Setup](docs/agent-setup.md)
- [Supported Stacks](docs/supported-stacks.md)
- [FAQ](docs/faq.md)

## License

MIT © [Dheeraj Joshi](https://github.com/djadmin)
