# devkit — launch notes

## What this is, plainly

devkit is a small CLI that gives every local web app a stable URL and a home in one registry.

The main reason to use it: when you build a lot of apps with Claude Code, you end up with dozens of things running on random ports. devkit makes that manageable without thinking about it — you wire it into your global `CLAUDE.md` once, and Claude registers every new app automatically.

---

## The one-liner

> Claude builds the app. devkit gives it a home.

Alternatives:
- Your Claude-built apps deserve better than `localhost:4839`
- Stop remembering ports. Name your apps.
- One URL per app. One dashboard for all of them.
- The registry Claude uses to manage your local apps for you.

---

## Who this is for

People who build a lot of local apps — especially with Claude Code or other AI tools. Indie hackers, solo builders, people who spin up a new POC every week. If you have more than five things running on your laptop and you've forgotten what's on which port, devkit is for you.

Not for: teams, production infra, anyone looking for a full-featured dev environment manager. This is intentionally small and opinionated.

---

## The story (for HN / blog posts)

After a few months of building with Claude Code, I had 20+ local apps across side projects, experiments, and tools I'd forgotten about. They were on ports like 3000, 4010, 5173, 8080 — and I had no idea which was which.

I built devkit to fix this. Every app gets a name and a URL: `http://notes.localhost`, `http://dashboard.localhost`. One dashboard shows what's running. One command gets me back into any project with Claude already open.

The part I didn't expect to matter: wiring it into my global `CLAUDE.md`. Now whenever I ask Claude to build something new, it registers the app automatically. I literally just visit the URL.

It's a bash CLI, uses Caddy for routing and pm2 for process management, and stores everything in a gitignored `apps.json`.

---

## HN post

**Title options (pick one):**
- Show HN: devkit — stable localhost URLs for all your Claude-built apps
- Show HN: I built a registry so I could stop forgetting which port each local app is on
- Show HN: a tiny CLI that gives every local app a home, built for Claude Code workflows

**Body:**
```
After building lots of local apps with Claude Code, I had 20+ things running on
random ports I kept forgetting.

devkit gives each app a stable URL (http://name.localhost), registers it in one
place, and lets you jump back in with `devkit edit name` (which drops into the
project with Claude Code running).

The trick that made it actually useful: add a few lines to your global CLAUDE.md,
and Claude registers every new app automatically. You never type a port number again.

It's opinionated — macOS, Caddy, pm2 — but that's what made it shippable.
Repo: https://github.com/djadmin/devkit
```

---

## X / Twitter

```
Building with Claude Code? You probably have 10+ local apps and can't remember
which port is which.

devkit gives each one a stable URL like http://notes.localhost.
Add it to your CLAUDE.md and Claude registers new apps automatically.

→ github.com/djadmin/devkit
```

---

## Messaging to avoid

- "local control plane" — too infrastructure-y, sounds like k8s
- "developer dashboard" — sounds like a feature, not a tool
- anything about pm2 or Caddy in the headline — implementation details

---

## Validation questions

1. Do Claude Code users actually feel this port-chaos pain?
2. Does the CLAUDE.md auto-registration click immediately or does it need a demo?
3. Is macOS-only a dealbreaker for the target audience?

---

## What's not in v0.1.0 (intentional)

- Menu bar app (good for v2)
- Web dashboard with live reload (IDEAS.md)
- Windows / Linux support
- Multi-machine sync beyond `clone-all`
- Any Claude API integration beyond `devkit edit` launching the CLI
