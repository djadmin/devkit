# devkit

> A local control plane for builders juggling lots of apps.
> Stable localhost URLs, one registry, one command to get back into any project.

`devkit` is for people who always have too many local web apps open at once.

If you keep asking yourself:

- Which port is this app on?
- What did I call this side project?
- Which repo and folder does this URL belong to?
- What should I restart after a reboot?

That is the problem `devkit` solves.

## What it does

- Gives every app a stable local hostname like `http://notes-api.localhost`
- Keeps a single registry of app name, path, repo, start command, and optional assistant instructions
- Starts and stops apps through `pm2`
- Generates a lightweight dashboard at `http://dash.localhost`
- Lets you jump back into a project with `devkit edit <name>`

This is opinionated on purpose. It is designed for builders running many local apps, especially side-project-heavy and AI-assisted workflows.

## Current scope

Today `devkit` is intentionally narrow:

- macOS
- Homebrew-managed Caddy
- `pm2` for app lifecycle
- local HTTP apps

That constraint is fine for an early public release. The value is workflow compression, not cross-platform breadth.

## Quick start

```bash
git clone https://github.com/djadmin/devkit.git ~/devkit
echo 'export PATH="$HOME/devkit/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

devkit bootstrap
brew services start caddy   # no sudo needed on port 8080
pm2 startup
pm2 save
```

> **Port note:** devkit defaults to port 8080, so hostnames look like `http://app.localhost:8080`.
> If you prefer clean URLs on port 80, set `"proxyPort": 80` in `apps.json` and restart Caddy with `sudo`.

Then register your first app:

```bash
devkit register \
  --name notes-api \
  --path ~/code/notes-api \
  --port 4010 \
  --cmd "npm run dev -- --port 4010"

devkit start notes-api
devkit open notes-api
```

## Daily commands

```bash
devkit list
devkit open <name>
devkit edit <name>
devkit start|stop|restart <name>
devkit start-all|stop-all|restart-all
devkit logs <name>
devkit show <name>
devkit version
```

Or open `http://dash.localhost`.

## How state works

By default, `devkit` stores its live registry in the repo root next to the CLI:

- `apps.json`: your private local registry, intentionally gitignored
- `apps.example.json`: committed sample structure for reference
- `Caddyfile`: generated, gitignored
- `dashboard.html`: generated, gitignored

If you want the state elsewhere, set `DEVKIT_HOME` before running the CLI.

## Repo layout

```text
devkit/
├── apps.example.json       # committed sample registry
├── apps.json               # local registry, gitignored
├── bin/devkit              # CLI
├── test/test_registry.sh   # integration tests
├── Caddyfile               # generated, gitignored
├── dashboard.html          # generated, gitignored
├── README.md
├── CLAUDE.md
└── IDEAS.md
```

## Registering an app

Pick a fixed port and a stable slug.

```bash
devkit register \
  --name <slug> \
  --path <absolute-project-path> \
  --port <port> \
  --cmd "<start command>"
```

`register` will also try to detect:

- the git remote from `origin`
- an optional `CLAUDE.md` file at the project root

After registration, the app is reachable at `http://<slug>.localhost` and appears in `devkit list` and the dashboard.

## Persistence model

- Caddy handles hostname routing.
- `pm2` keeps your app processes managed.
- `devkit start`, `stop`, and `remove` automatically call `pm2 save`.

After a reboot, the goal is simple: your routing and process inventory should come back without remembering a pile of ports and shell history.

## Bootstrap details

`devkit bootstrap` does three things:

- ensures Caddy exists
- regenerates the Caddyfile and dashboard
- symlinks the generated Caddyfile into Homebrew's default Caddy location when safe

After that, start Caddy once and enable `pm2` startup. On the default port 8080, Caddy does not need `sudo`.

## Release positioning

The strongest framing for `devkit` is not "dashboard for apps."

It is:

- a local control plane for builders with many apps
- stable identities for messy local development
- one place to reopen and restart every project on your laptop

See [LAUNCH.md](./LAUNCH.md) for taglines, story, and launch copy. See [RELEASE_PLAN.md](./RELEASE_PLAN.md) for the validation checklist.

## Running tests

```bash
bash test/test_registry.sh
```

Tests run against a temporary `DEVKIT_HOME` and do not touch your real registry, pm2, or Caddy.

## Troubleshooting

`devkit list` shows `stopped`
Run `devkit start <name>`.

Browser says the hostname does not resolve
Check that Caddy is running, then run `devkit reload`.

`pm2` is missing
Install `pm2` in the Node environment you actually use, then rerun the command.

Two apps want the same port
`devkit register` rejects duplicates. Pick a different port or remove the old app first.
