# FAQ

## What is devkit in one sentence?

devkit gives every local app your AI builds a stable name, `.localhost` URL, and one place to reopen or control it on macOS.

## Is devkit only for AI-generated apps?

No. That is just the strongest use case.

You can register any local app manually, or track one that is already running. The AI-agent workflow matters because it turns devkit into a habit instead of a one-off tool.

## Can I use it with projects I already have?

Yes. That is one of the main onboarding paths.

- use the menu bar app's `Track` / `Track All`
- or run `devkit register <name> --port <port> --managed-by external`

That gives existing services a stable URL and place in the registry without changing how they are started today.

## How does devkit know whether an app is running?

There are two layers:

- the **CLI** manages devkit-owned apps with pid files plus port ownership checks
- the **menu bar app** shows fast status based on port reachability

That split is deliberate. The CLI is responsible for lifecycle safety. The app is responsible for fast visibility.

## Will devkit kill the wrong process?

It is explicitly designed not to.

Recent lifecycle hardening makes `start` and `stop` refuse unrelated port conflicts, ignore stale pid files, and recover orphaned listeners that still belong to the registered app path.

## What happens if an app crashes?

For devkit-managed apps, the next status check will show it as stopped. You can restart it from the CLI or the menu bar app.

devkit is not a daemon supervisor like `pm2` or `launchd`. It is a local app registry and lifecycle helper, not a forever-process manager.

## Can I use Docker, Homebrew services, or another supervisor with devkit?

Yes. Register those apps as external:

```bash
devkit register redis --port 6379 --managed-by external
```

That gives you naming and URL routing, but not start/stop buttons.

## Does devkit work without the menu bar app?

Yes. The CLI is the foundation.

You can use:

- `devkit list`
- `devkit open`
- `devkit start`
- `devkit stop`
- `http://dash.localhost`

The menu bar app just makes the daily workflow better.

## Does devkit work without the CLI?

Not really as a product.

The menu bar app reads the registry, but the CLI is what bootstraps the registry, owns lifecycle, writes pid files, and generates routing config. Treat the CLI as required.

## Is it macOS-only?

Today, the full product is intentionally macOS-first.

- the menu bar app is native macOS
- the install story assumes Homebrew and Caddy
- the product value is strongest for Mac-based AI-assisted builders

## Does devkit send any data anywhere?

No. State stays on your machine. No telemetry, no analytics, no account.
