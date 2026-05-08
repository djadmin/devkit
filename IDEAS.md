---
status: idea
type: tooling
created: 2026-05-08
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
