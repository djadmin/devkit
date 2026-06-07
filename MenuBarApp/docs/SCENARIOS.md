# Scenario Coverage Map

This document maps every realistic user scenario to its product and documentation coverage status.

**Statuses:**
- ✅ Covered — product handles it and docs explain it
- 🟡 Partial — product handles it but docs are thin or the UX could be clearer
- ❌ Gap — product does not handle it, docs do not cover it, or both

---

## Installation

| Scenario | Status | Notes |
|---|---|---|
| Fresh Mac, no Homebrew | 🟡 | Docs say install Homebrew first but no link or inline steps |
| brew tap + cask install | ✅ | Three install paths documented |
| Installer script (curl pipe bash) | ✅ | Covered in getting-started and README |
| CLI only (no menu bar) | ✅ | Documented |
| Caddy already running on port 80 | ✅ | Installer detects via admin API; FAQ explains |
| Something else already on port 80 | 🟡 | FAQ mentions lsof but no step-by-step |
| `devkit` not on PATH after install | ✅ | FAQ covers source/new tab; installer adds PATH entry |
| Reinstall / upgrade | 🟡 | Works in practice (installer overwrites binary) but not explicitly documented |
| Menu bar app not appearing after install | ✅ | FAQ covers troubleshooting steps |
| Install on Intel Mac | 🟡 | Not explicitly tested or called out (Apple Silicon assumed in most examples) |

---

## First-time onboarding — existing apps

| Scenario | Status | Notes |
|---|---|---|
| Apps running, ports known | ✅ | Track / Track All in menu bar + CLI register |
| Apps running, don't know which port is what | ✅ | ↗ peek button opens localhost:port in browser |
| Apps running, don't know the start command | ✅ | Register as external; can add --cmd later |
| Apps running on ports not in scanner list | 🟡 | Scanner only checks ~40 common ports; manual register needed; FAQ explains |
| Multiple apps on the same port (impossible) | ✅ | Not possible; handled |
| Docker containers running | ✅ | Register as external; FAQ explains |
| Homebrew services (postgres, redis, etc.) | ✅ | Register as external; FAQ explains |
| pm2-managed apps | ✅ | Register as external |
| App with env vars in start command | ✅ | Inline in --cmd; FAQ explains |
| App listening on 0.0.0.0 | ✅ | Port reachability check works regardless |
| App on a Unix socket (not TCP) | ❌ | Not supported, FAQ mentions this under "does not do" |

---

## First-time onboarding — zero state (no apps running)

| Scenario | Status | Notes |
|---|---|---|
| User has Claude Code installed | ✅ | Setup card shows snippet with copy button |
| User has Cursor | 🟡 | Snippet in agent-setup.md but setup card only shows Claude Code |
| User has Codex | 🟡 | Same — agent-setup.md covers it but onboarding card is Claude-only |
| User has Copilot | 🟡 | agent-setup.md only; no in-app guidance |
| User has Windsurf | 🟡 | agent-setup.md only; no in-app guidance |
| User has no AI tool | ❌ | No guidance on manual-only workflow from the onboarding screen |

**Key gap:** The onboarding setup card shows only the Claude Code snippet. Users on Cursor, Codex, or Windsurf need to find agent-setup.md themselves. Adding agent tabs to the setup card would close this gap.

---

## AI agent integration

| Scenario | Status | Notes |
|---|---|---|
| Claude Code global CLAUDE.md | ✅ | Full snippet in agent-setup.md and setup card |
| Claude Code project CLAUDE.md | ✅ | Documented |
| Cursor .cursor/rules/ | ✅ | Full snippet in agent-setup.md |
| Cursor global user rules | ✅ | Documented |
| OpenAI Codex AGENTS.md | ✅ | Full snippet in agent-setup.md |
| GitHub Copilot instructions | ✅ | Full snippet in agent-setup.md |
| Windsurf | ✅ | Full snippet in agent-setup.md |
| Agent built app before devkit was installed | ✅ | FAQ: register manually |
| Agent registers wrong port | 🟡 | No detection; user must fix manually via re-register |
| Agent registers duplicate name | 🟡 | CLI overwrites silently; no warning |
| Multiple agents on same machine | ✅ | FAQ explains; all write to same registry |
| Agent uses `--managed-by external` incorrectly | 🟡 | No validation; user may not notice limitation |

---

## Lifecycle

| Scenario | Status | Notes |
|---|---|---|
| Start a devkit-managed app | ✅ | devkit start |
| Stop a devkit-managed app | ✅ | devkit stop |
| Restart an app | ✅ | devkit restart |
| Start all apps | ✅ | devkit start-all |
| Stop all apps | ✅ | devkit stop-all |
| App crashes after start | ✅ | Shows stopped on next check; FAQ explains |
| Stale pid file from crashed app | ✅ | Auto-detected and cleared on next start |
| Port taken by unrelated process | ✅ | Start refuses with error identifying the conflicting process |
| Orphaned devkit process (pid matches port) | ✅ | Start replaces it safely |
| Start-all after reboot | ✅ | FAQ explains; devkit start-all |
| App needs startup warmup time | 🟡 | devkit start waits briefly for port but no configurable timeout |
| App forks on start (double-fork) | ✅ | Fixed in v0.2.0 with Perl double-fork |
| Logs access | ✅ | devkit logs |
| App needs sudo to bind low port | ❌ | Not supported; use a port above 1024 |
| Graceful shutdown (SIGTERM vs SIGKILL) | 🟡 | devkit sends SIGTERM; no configurable grace period |

---

## Daily workflow

| Scenario | Status | Notes |
|---|---|---|
| See all apps | ✅ | devkit list or menu bar |
| Open app in browser | ✅ | devkit open or ↗ button in menu bar |
| Open app project in editor | ✅ | devkit edit |
| Search for an app | ✅ | Menu bar search bar |
| Rename an app | 🟡 | Re-register + remove; no rename command |
| Remove an app | ✅ | devkit remove |
| Update an app's port | 🟡 | Re-register with new port; no update command |
| Update an app's start command | 🟡 | Re-register; no update command |
| Add description to an app | 🟡 | CLI flag exists (--description) but not prominent |
| View app logs | ✅ | devkit logs |
| dash.localhost dashboard | ✅ | Auto-generated, always available |
| 502 on .localhost URL | ✅ | FAQ explains |
| dash.localhost not loading | ✅ | FAQ covers Caddy check |

---

## Advanced / edge cases

| Scenario | Status | Notes |
|---|---|---|
| Same port reused by a new app | ✅ | Re-register with new name; remove old |
| App moved to a different directory | 🟡 | Re-register with new --path; no move command |
| App moved to a different port | 🟡 | Re-register with new --port |
| Two apps competing for same port | ✅ | Second start will fail with conflict message |
| Custom TLD (not .localhost) | ❌ | Not supported |
| HTTPS locally | ❌ | Not supported |
| Non-localhost bind (remote access) | ❌ | Caddy listens on loopback only |
| Sharing registry across machines | ❌ | apps.json is local and gitignored |
| Team-shared registry | ❌ | Out of scope for current version |
| Intel Mac | 🟡 | Should work; not explicitly tested |

---

## Uninstall and migration

| Scenario | Status | Notes |
|---|---|---|
| Complete uninstall | ✅ | FAQ has full step-by-step |
| Migrate to new Mac | 🟡 | apps.json can be copied but paths differ; not documented |
| Back up registry | 🟡 | Copy apps.json; not documented |
| Remove just the menu bar app | 🟡 | Drag to trash; not documented |
| Downgrade devkit version | ❌ | Not documented |

---

## Gaps summary (by priority)

### High impact — address soon
1. **Setup card shows only Claude Code** — users on Cursor, Codex, Windsurf see irrelevant instructions. Fix: add agent tabs to `ClaudeSetupView`.
2. **No rename / update commands** — current workaround (re-register + remove) is friction. Fix: add `devkit rename` and `devkit update` CLI commands.
3. **Scanner misses unusual ports** — user has to know to register manually. Fix: add a manual "register by port" input in the onboarding screen.

### Medium impact — address before broad launch
4. **No graceful shutdown config** — SIGTERM with no wait. Fix: document the behavior; optionally add `--stop-timeout` flag.
5. **App startup warmup** — no way to configure how long devkit waits before declaring a start failed. Fix: add `--start-timeout` flag.
6. **No migration guide for new Mac** — Fix: add to FAQ.
7. **Intel Mac not explicitly tested** — Fix: add to CI matrix or call out in requirements.

### Lower impact — post-launch
8. **No `devkit rename` command** — UX friction but workaround is clear.
9. **No `devkit update` command** — same.
10. **apps.json schema not documented** — power users editing it manually have no reference.
11. **Custom TLD not supported** — niche request; document it as "not planned".
