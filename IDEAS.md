---
status: idea
type: tooling
created: 2026-05-08
---

# devkit MCP server — Claude Code native integration

## Problem

The current Claude integration relies on global CLAUDE.md text instructions — Claude reads them and *hopefully* runs `devkit register`. It's fragile and depends on prompt following.

## Idea

Build devkit as an MCP server so Claude Code can call devkit tools directly, as structured function calls. No text instructions needed.

**Tools to expose:**
- `register_app(name, path, port, cmd, repo?)` — register + start
- `list_apps()` — see what's registered and running
- `start_app(name)` / `stop_app(name)`
- `open_app(name)` — open in browser
- `edit_app(name)` — cd into project, launch Claude Code

**Installation (user runs once):**
```bash
claude mcp add devkit -- node ~/devkit/mcp-server.js
```

**Implementation:** thin Node.js wrapper over existing `devkit` CLI. Each MCP tool shells out to the CLI. No rewrite of devkit core.

**Estimated effort:** 3–4 days.

## Distribution

- Package as a Claude Code plugin for one-command install
- Submit to community plugin marketplace after MCP server is solid
- Skills (`/devkit:register`, `/devkit:list`) for discoverability on top of MCP tools

## Hooks angle

`PostToolUse` and `SessionEnd` hooks exist but aren't enough alone to auto-detect "Claude just built a web app." Best used alongside MCP tools, not instead of them.

## Why this matters

Upgrades devkit from "Claude follows a text instruction" to "Claude has devkit as a real tool." Every app Claude builds automatically gets a stable URL — no user intervention, no CLAUDE.md dependency.

## Build after

CLI is public and has traction. MCP is the v2 story.

---

# devkit menubar — menu bar control for local apps

## Problem

The dashboard answers a glance-level question: what is running, what is it called, and where do I jump back in?
A browser tab is heavier than that question deserves.

## Idea

A small macOS menu bar app or SwiftBar plugin that reads the local `apps.json` registry and shows:

- one row per app with name, hostname, and status
- click to open `http://<name>.localhost`
- secondary actions for start, stop, restart, open folder, open repo, and `devkit edit`
- a fallback link to the dashboard

## Why it matters

This is a better wedge than a generic dashboard because it makes `devkit` feel like a real local control plane.

## Recommendation

Build this only after the CLI and public story are clean enough to release.
