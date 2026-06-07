# devkit TODO

Ordered by priority. Move items to CHANGELOG.md when shipped.

## Immediate

- [ ] Add agent tabs to onboarding setup card — Cursor / Codex / Copilot / Windsurf snippets with per-agent config file path *(done in code, needs real screenshot)*

## Next

- [ ] Launch at login toggle in menu bar app settings
- [ ] `devkit init-agents` — one command that writes the snippet to all detected agent config files (CLAUDE.md, AGENTS.md, .cursor/rules/, .windsurfrules)
- [ ] Crash notifications via macOS Notification Centre when a devkit-managed app exits unexpectedly
- [ ] Auto-update via Sparkle

## Backlog

- [ ] Real screenshots for landing page and MenuBarApp README — need the popover open (Accessibility permission required for scripted capture)
- [ ] `devkit update` shown in `devkit help` short summary (currently only in full help)
- [ ] `devkit rename` added to FAQ "daily workflow" section more prominently
- [ ] Path field shown in onboarding cmd row — currently defaults to `$HOME` when user enters a start command without a path; a small note or input would make this clearer
- [ ] Linux systray port (CLI is mostly portable bash; menu bar app is macOS-only)

## Known gaps (from SCENARIOS.md)

- No graceful shutdown hook config — devkit sends SIGTERM; apps that need a custom shutdown signal have no way to configure it
- No `--no-path` shorthand for registering without a path (workaround: just omit `--path`)
