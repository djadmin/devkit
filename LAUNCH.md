# devkit launch positioning

## Core positioning

`devkit` is a local control plane for builders juggling lots of apps.

It is not a generic "developer dashboard."
It is for the specific pain of having too many local apps, too many ports, and too little memory for where everything lives.

## Target user

- solo builders
- indie hackers
- freelancers juggling client apps
- AI-heavy developers spinning up many small tools and dashboards
- anyone with a laptop full of side projects

## Problem statement

Modern builders do not just run one app.
They accumulate ten or twenty local apps, each with its own port, folder, repo, and startup command.
The friction is not building the app. The friction is reopening, routing, and remembering it later.

## Product promise

When an app exists on your laptop, `devkit` gives it a stable identity.

That means:

- a name
- a URL
- a repo path
- a start command
- a known way back in

## Messaging pillars

1. Stable local identities
Every app gets a predictable hostname instead of a forgotten port.

2. One registry, not scattered notes
App metadata lives in one place instead of shell history, browser tabs, and half-remembered folders.

3. Faster context switching
`devkit edit foo` is the point. Re-entering work should be cheap.

4. Better fit for AI-heavy workflows
If you spin up many experiments, small apps, or agents, local app sprawl gets worse. `devkit` keeps that sprawl manageable.

## Taglines

- A local control plane for builders with too many apps.
- Stable localhost URLs for your growing pile of side projects.
- One registry for every app on your laptop.
- Give every local app a name, URL, and way back in.
- Stop remembering ports. Start naming apps.
- The missing control plane for local development.

## Home page hero options

1. A local control plane for builders juggling lots of apps.
Stable localhost URLs, one registry, and one command to jump back into any project.

2. Stop remembering ports.
Give every local app on your laptop a stable name, URL, and restart path.

3. Your laptop has become a mini cloud.
`devkit` gives it a control plane.

## HN angle

Title ideas:

- Show HN: devkit, a local control plane for all the apps on my laptop
- Show HN: I got tired of forgetting which localhost port each side project used
- Show HN: stable localhost URLs and a registry for every app I build

HN post shape:

- Start with the personal pain.
- Show the simplest example: `notes-api.localhost` instead of `localhost:4010`.
- Explain why this gets worse with AI-generated side projects and experiments.
- Be honest that it is macOS-first and opinionated.
- Ask whether others have the same problem or solve it differently.

## X angle

Tweet shape:

- problem in one line
- 15 to 20 second demo gif
- one sharp before/after
- one sentence for who it is for

Example:

"I kept losing track of local apps across side projects, client work, and AI experiments, so I built a tiny local control plane.

Every app gets a stable URL like `notes-api.localhost`, a saved start command, and a way back in.

If you juggle lots of local apps, this might be useful."

## Product Hunt angle

Lead with utility, not architecture.

Suggested subtitle:
A local control plane for your growing pile of local apps.

Suggested bullets:

- Stable localhost hostnames for every app
- One registry for path, repo, and startup command
- Start, stop, and reopen projects quickly
- Built for side-project-heavy and AI-heavy workflows

## Validation goal

The first release should validate three things:

- Do builders actually feel this pain strongly?
- Does the control-plane framing resonate more than the dashboard framing?
- Which wedge gets attention: named URLs, quick resume, or menu bar control?
