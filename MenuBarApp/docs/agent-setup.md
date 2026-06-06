# Agent Setup

The strongest version of devkit is simple:

Set one global rule once, and every local app your AI builds gets a name, start command, and `.localhost` URL automatically.

## The Rule You Want

No matter which agent you use, the instruction should push toward this behavior:

- after scaffolding a local web app or service, choose a lowercase-hyphenated slug
- register it with `devkit register <slug> --port <port> --cmd "<start-cmd>"`
- start it with `devkit start <slug>`
- skip registration if `devkit` is not installed

## Claude Code

**Global config**: `~/.claude/CLAUDE.md`  
**Project config**: `CLAUDE.md` in the repo root

Copy-paste:

````markdown
## Local Web Apps — devkit
After creating any local web app or service:
  choose a lowercase-hyphenated slug
  run `devkit register <slug> --port <port> --cmd "<start-cmd>"`
  run `devkit start <slug>`
Skip this if `devkit` is not installed.
The app should be reachable at http://<slug>.localhost
````

Claude Code is the most mature and most important integration for devkit.

## Cursor

**Project rule**: `.cursor/rules/devkit.mdc`  
**Global rule**: Cursor Settings → Rules → User Rules

Copy-paste:

````markdown
---
description: Register new local apps with devkit after scaffolding them
alwaysApply: true
---

After creating any local web app or service:
- choose a lowercase-hyphenated slug
- run `devkit register <slug> --port <port> --cmd "<start-cmd>"`
- run `devkit start <slug>`
- skip this if `devkit` is not installed
````

## OpenAI Codex

**Global config**: `~/.codex/AGENTS.md`  
**Project config**: `AGENTS.md` in the repo root

Copy-paste:

````markdown
## Local Web Apps — devkit
After creating any local web app or service:
  run `devkit register <slug> --port <port> --cmd "<start-cmd>"`
  run `devkit start <slug>`
Use lowercase-hyphenated slugs and skip if `devkit` is not installed.
````

## GitHub Copilot

**Project config**: `.github/copilot-instructions.md`

Copy-paste:

````markdown
## Local Web Apps — devkit
After creating any local web app or service:
- run `devkit register <slug> --port <port> --cmd "<start-cmd>"`
- run `devkit start <slug>`
- use a lowercase-hyphenated slug
````

## Windsurf

**Project config**: `.windsurfrules`  
**Global config**: Windsurf Settings → Global Rules

Copy-paste:

````text
## Local Web Apps — devkit
After creating any local web app or service:
- run devkit register <slug> --port <port> --cmd "<start-cmd>"
- run devkit start <slug>
- use a lowercase-hyphenated slug
- skip this if devkit is not installed
````

## Naming Guidance

Good names:

- `atlas`
- `notes-api`
- `ops-dashboard`
- `billing-admin`

Bad names:

- `My App`
- `test`
- `server-final`
- `app2`

The name becomes part of the URL, so treat it like a stable hostname.

## When To Use `--managed-by external`

If the app is already started by something else, do not ask your agent to make devkit supervise it.

Use this instead:

```bash
devkit register postgres --port 5432 --managed-by external
```

That is right for Docker containers, Homebrew services, databases, and any process that devkit should not start or stop itself.

## What Success Looks Like

After setup, a normal flow should look like this:

1. Ask your agent to build a local app.
2. The agent registers it with devkit.
3. The app appears in the menu bar and at `http://<slug>.localhost`.
4. Later, you can reopen it with `devkit open <slug>` or from the menu bar.
