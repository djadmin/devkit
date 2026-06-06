# Changelog

All notable changes to devkit are documented here.

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

- Stop may not kill externally-supervised processes (pm2, nodemon, launchd-managed)
- Auto-update not yet implemented
- Launch at login not yet implemented
- Homebrew cask not yet published

---

## Roadmap

- [ ] `brew install --cask devkit` distribution
- [ ] Launch at login toggle
- [ ] Crash notifications via macOS notification centre
- [ ] Auto-update via Sparkle
- [ ] `devkit init-agents` — one command to configure all AI agents
- [ ] Linux support (systray)
