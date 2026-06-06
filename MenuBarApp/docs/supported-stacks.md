# Supported Stacks

devkit works with any local app that listens on a TCP port.

It does not care whether the app is written in Node, Rails, Python, Go, Rust, PHP, Java, or something more obscure. If it exposes a local port, devkit can name it, route it, and usually manage it.

## Two Modes

### devkit-managed

Use this when devkit should own the lifecycle:

```bash
devkit register notes --port 4010 --cmd "npm run dev -- --port 4010"
```

This is the right mode for normal app servers and dashboards you want to start and stop from devkit.

### external

Use this when something else already owns the lifecycle:

```bash
devkit register postgres --port 5432 --managed-by external
```

This is the right mode for Docker containers, databases, Homebrew services, and anything devkit should not supervise directly.

## Confirmed Good Fits

| Stack | Examples |
|---|---|
| Node.js | Next.js, Express, Fastify, NestJS, Vite |
| Ruby | Rails, Sinatra |
| Python | FastAPI, Django, Flask |
| Go | net/http, Gin, Echo, Fiber |
| Rust | Axum, Actix |
| PHP | Laravel |
| Java | Spring Boot |
| .NET | ASP.NET Core |
| Static | Vite, Parcel, `http-server` |
| Other | Deno, Bun, Elixir Phoenix, anything else on TCP |

## Common Examples

```bash
devkit register web --port 3000 --cmd "npm run dev"
devkit register api --port 8000 --cmd "uvicorn main:app --port 8000 --reload"
devkit register rails --port 3000 --cmd "rails server -p 3000"
devkit register admin --port 5173 --cmd "vite --port 5173"
```

## What Does Not Fit Cleanly

- apps that only expose Unix sockets
- remote services that are not reachable on localhost
- stacks where the meaningful endpoint is not a TCP listener

For those, devkit is not the right control plane.

## Important Distinction

Support for a stack means:

- devkit can route and label it if it listens on a port
- devkit can usually manage it if the start command launches a normal local process

It does not mean devkit replaces Docker, `pm2`, `launchd`, or a production process supervisor.
