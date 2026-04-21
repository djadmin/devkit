# devkit

> A local control plane for builders juggling lots of apps.
> Stable localhost URLs, one registry, one command to get back into any project.

`devkit` is for people who always have too many local web apps running at once.

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

## Quick start

```bash
git clone https://github.com/djadmin/devkit.git ~/devkit
echo 'export PATH="$HOME/devkit/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

devkit bootstrap
sudo brew services start caddy
pm2 startup
pm2 save
```

Then register your first app:

```bash
devkit register \
  --name notes-api \
  --path ~/code/notes-api \
  --port 4010 \
  --cmd "npm run dev -- --port 4010"

devkit start notes-api
devkit open notes-api
# → opens http://notes-api.localhost in your browser
```

## Daily commands

```bash
devkit list
devkit open <name>
devkit edit <name>
devkit start|stop|restart <name>
devkit logs <name>
devkit show <name>
```

Or just open `http://dash.localhost`.

## How state works

- `apps.json` — your private local registry, intentionally gitignored
- `apps.example.json` — committed sample structure for reference
- `Caddyfile` — generated, gitignored
- `dashboard.html` — generated, gitignored

## Repo layout

```text
devkit/
├── apps.example.json
├── apps.json               # local registry, gitignored
├── bin/devkit              # CLI
├── Caddyfile               # generated, gitignored
├── dashboard.html          # generated, gitignored
└── README.md
```

## Registering an app

```bash
devkit register \
  --name <slug> \
  --path <absolute-project-path> \
  --port <port> \
  --cmd "<start command>"
```

`register` auto-detects the git remote and any `CLAUDE.md` at the project root.

## Troubleshooting

`devkit list` shows `stopped` — run `devkit start <name>`.

Browser says hostname doesn't resolve — check Caddy is running, then `devkit reload`.

`pm2` is missing — install it in the Node environment you use, then rerun.

Two apps want the same port — `devkit register` rejects duplicates; pick a different port.
