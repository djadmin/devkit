# Changelog

All notable changes to devkit are documented here.

---

## [0.2.0] — 2026-06-07

### CLI

- `devkit update <name> [--port N] [--cmd C] [--path P] [--desc D] [--managed-by M]` — patch any field on a registered app without re-registering
- `devkit rename <old> <new>` — safely rename a running app (stops, renames, restarts)
- `devkit update` documented in `devkit help` output

### Menu bar app — onboarding

- Port numbers in the onboarding list no longer display with comma separators
- Peek button (↗) next to each port opens `http://localhost:<port>` to see what's running before naming it
- Start command field on each untracked port row — enter it now so devkit can manage the app's lifecycle later
- Manual port input at the bottom of the list — add any port the scanner missed; validated against TCP reachability before adding
- Apps tracked with a start command are registered as devkit-managed; apps tracked without one are registered as external

### Installer

- Caddy start logic now checks the admin API (`http://localhost:2019/config/`) before attempting `brew services start`, preventing a spurious launchctl error when Caddy is already running

### Docs

- FAQ expanded from 11 to 35+ questions across 9 sections
- `SCENARIOS.md` coverage map added — 60+ scenarios mapped with status (covered / partial / gap)
- macOS minimum version corrected to 14+ everywhere (menu bar app requires `onChange(of:initial:_:)` from macOS 14)

### Tests

- CI migrated from ripgrep (`rg`) to `grep -E` for GitHub Actions macOS runners
- 5 new tests for `devkit update`; suite is now 67 tests, 0 failures

---

## [0.1.0-beta] — 2026-06-06

### Initial public beta

**Menu bar app (DevkitBar)**

- Native macOS menu bar app built with SwiftUI + MenuBarExtra
- Real-time status polling every 8 seconds via TCP port check
- Grouped sections: Running / Stopped / External with bulk Start All / Stop All
- Search / filter by app name or hostname (debounced, Escape to clear)
- Running apps sorted to top; flat sorted list when searching
- Status dots: 🟢 green with pulse glow (running), 🔴 red (stopped), 🟣 purple (external)
- Row actions: Copy URL (✓ confirmation), Open in browser, Start/Stop toggle
- Click row to open in browser and close the popover
- Header: devkit monospaced title, amber/green/red fleet health dot, ⌘R reload
- Footer: Dashboard and Quit with proper icons
- Search auto-focuses when the popover opens
- `ultraThinMaterial` background, respects dark/light mode
- Custom app icon (1024×1024, deep indigo with 2×2 tile grid)

**Known issues (beta)**

- Externally-supervised processes (nodemon, launchd, custom respawners) can come back after stop
- Auto-update not yet implemented
- Launch at login not yet implemented

---

## Roadmap

- [ ] Launch at login toggle
- [ ] Crash notifications via macOS notification centre
- [ ] Auto-update via Sparkle
- [ ] `devkit init-agents` — one command to configure all AI agents at once
- [ ] Agent tabs in setup card (Cursor, Codex, Copilot, Windsurf snippets)
- [ ] Linux support (systray)
