# Supported Stacks

devkit tracks **any process that listens on a TCP port**. It doesn't care what language or framework you use. If it has a port, devkit can track it.

---

## How it works

devkit polls each registered port every 8 seconds using a TCP connection attempt. If the port responds, the app shows as 🟢 running. If it doesn't, it shows as 🔴 stopped. No agents, no sidecars, no SDK to install in your app.

---

## Confirmed working

| Stack | Framework | Example command |
|---|---|---|
| **Node.js** | Next.js | `next dev --port 3000` |
| **Node.js** | Express | `node server.js` |
| **Node.js** | Fastify | `node index.js` |
| **Node.js** | NestJS | `nest start --watch` |
| **Ruby** | Rails (Puma) | `rails server -p 3000` |
| **Python** | FastAPI | `uvicorn main:app --port 8000 --reload` |
| **Python** | Django | `python manage.py runserver 8000` |
| **Python** | Flask | `flask run --port 5000` |
| **Go** | net/http, Gin, Echo, Fiber | `go run main.go` |
| **Rust** | Axum, Actix-web | `cargo run` |
| **PHP** | Laravel | `php artisan serve --port 8000` |
| **Java** | Spring Boot | `./mvnw spring-boot:run` |
| **.NET** | ASP.NET Core | `dotnet run` |
| **Static** | Vite | `vite --port 5173` |
| **Static** | Parcel | `parcel --port 1234` |
| **Static** | http-server | `http-server -p 8080` |
| **Elixir** | Phoenix | `mix phx.server` |
| **Haskell** | Servant, Yesod | `stack run` |
| **Deno** | Fresh, Oak | `deno task start` |
| **Bun** | Elysia, Hono | `bun run dev` |

---

## What doesn't work

| Case | Why | Workaround |
|---|---|---|
| **Unix socket only** | devkit checks TCP ports, not sockets | Bind to a TCP port as well |
| **Docker containers** | Port must be forwarded to host | Use `-p 3000:3000` in docker run |
| **Cloud / remote** | devkit only tracks localhost | Register with the local proxy port |
| **Externally managed** | Use `--managed-by external` flag | Status shows 🟣 external |

---

## Externally managed apps

If an app is managed by something outside devkit (Docker Desktop, Homebrew services, etc.), register it with `--managed-by external`:

```bash
devkit register postgres --port 5432 --managed-by external
```

These apps show with a 🟣 purple dot and have no start/stop controls — just a URL and status indicator.

---

## Port ranges

There's no restriction on port numbers. Common ranges:

- **3000–3999** — typical Node.js / Rails
- **4000–4999** — GraphQL, secondary services
- **5000–5999** — Flask, .NET
- **7000–8000** — custom / microservices
- **8000–9000** — Django, Go, Java
