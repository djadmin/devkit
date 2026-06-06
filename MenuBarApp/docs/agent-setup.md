# Agent Setup

The whole point of devkit is that your AI agent registers apps automatically. You set this up once — globally — and every project the agent builds from then on appears in your menu bar.

---

## Claude Code

**Global config** (recommended): `~/.claude/CLAUDE.md`  
**Project config**: `CLAUDE.md` in the repo root

```markdown
## devkit — App Registration

After creating any web application, API server, or local service, register it with devkit:

```bash
devkit register <app-name> \
  --port <port> \
  --cmd "<start-command>" \
  --description "<one-line description>"
```

Rules:
- app-name: lowercase, hyphenated (e.g. my-api, auth-service, dashboard-ui)
- Register AFTER the project structure exists, not before
- Skip if devkit is not installed: check with `which devkit`
```

**Status**: ✅ Working — this is the origin of the project.

---

## Cursor

**Project rule**: `.cursor/rules/devkit.mdc` in repo root  
**Global rule**: Cursor Settings → Rules → User Rules (plain text, no frontmatter)

```markdown
---
description: Register new web apps and services with devkit after creating them
alwaysApply: true
---

## devkit — App Registration

After creating any web application or service, run:

```bash
devkit register <app-name> --port <port> --cmd "<start-command>"
```

- Use lowercase-hyphenated names (e.g. my-api, task-ui)
- Register after the app structure exists
- Skip if devkit is not installed: `which devkit`
```

> Note: Cursor has no global project rules equivalent. For global coverage, use Cursor Settings → Rules.

**Status**: 🧪 Snippet written, needs real-world testing.

---

## OpenAI Codex

**Global config**: `~/.codex/AGENTS.md`  
**Project config**: `AGENTS.md` in repo root

Codex reads configs hierarchically: global → repo root → subdirectory. Global placement is recommended.

```markdown
## devkit — App Registration

After creating any web application or local service, register it with devkit:

```bash
devkit register <app-name> --port <port> --cmd "<start-command>"
```

- Naming: lowercase-hyphenated (e.g. task-api, dashboard-ui)
- Register after the project structure is created
- Skip if devkit is not installed: `which devkit`
```

**Status**: 🧪 Snippet written, needs real-world testing.

---

## GitHub Copilot

**Project config**: `.github/copilot-instructions.md` in repo root  
(No global config available — project-level only)

```markdown
## devkit — App Registration

After scaffolding any web application or service, register it with devkit:

```bash
devkit register <app-name> --port <port>
```

This gives the app a .localhost URL tracked in the devkit menu bar.
```

**Status**: 🧪 Snippet written, needs real-world testing.

---

## Windsurf

**Project config**: `.windsurfrules` in repo root  
**Global config**: Windsurf Settings → Global Rules

```
## devkit — App Registration

After creating any web application or local service:
devkit register <app-name> --port <port> --cmd "<start-command>"

This registers the app at <app-name>.localhost for tracking in devkit.
```

**Status**: 🧪 Snippet written, needs real-world testing.

---

## The register command

```
devkit register <name> [options]

Options:
  --port <port>         Port the app listens on (required)
  --cmd <command>       Command to start the app
  --description <text>  Short description
```

Example:

```bash
devkit register my-api --port 3000 --cmd "npm run dev" --description "REST API"
```

This writes an entry to `apps.json` and the app immediately appears in the menu bar at `my-api.localhost`.
