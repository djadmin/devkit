# devkit release plan

## Release goal

Ship a public alpha that tests whether builders with many local apps resonate with the "local control plane" framing.

## Do before release

- add a real public git remote
- record a short demo showing register, open, list, and edit
- replace placeholder clone instructions in the README with the actual repo URL
- verify bootstrap on a second machine or a clean macOS user account
- decide whether the first public screenshot is the CLI, dashboard, or both

## Recommended launch asset set

- one README hero screenshot of the dashboard
- one terminal gif: register -> start -> open -> edit
- one short architecture diagram showing app -> hostname -> Caddy -> local port
- one honest note about current scope: macOS + Homebrew + PM2

## Fast validation sequence

1. Publish the repo and README.
2. Post on X with a short clip.
3. Launch on HN within a few days if the X responses show recognition.
4. Use Product Hunt only after the repo, screenshots, and onboarding feel polished.

## What to watch

- how many people say "I have this exact problem"
- whether people care more about named localhost URLs or project re-entry
- whether the macOS-only constraint blocks adoption
- whether users ask for Docker, worktrees, Linux, or menu bar support first

## Likely next wedge

If people like the idea but do not love the dashboard, build the menu bar version next.
That is the most distinctive follow-up for a second wave of attention.
