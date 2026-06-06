# Releasing devkit

Use this checklist before cutting a public release.

## Automated gates

These should already be green in GitHub Actions:

- `CLI` workflow
- `Installer` workflow
- `Release` workflow changes reviewed

## Manual fresh-machine checks

Run these on a clean macOS machine or VM with no prior `devkit` state.

### 1. Homebrew CLI path

```bash
brew tap djadmin/tap
brew install devkit
devkit version
devkit bootstrap
```

Verify:

- `devkit` is on `PATH`
- `~/devkit/apps.json` is created
- `~/devkit/Caddyfile` and `~/devkit/dashboard.html` are created
- `devkit paths` points at the expected install location

### 2. Homebrew cask path

```bash
brew tap djadmin/tap
brew install --cask devkit
open -a DevkitBar
```

Verify:

- `DevkitBar.app` launches
- the menu bar app finds the CLI automatically
- the menu bar app can read the registry and show status

### 3. Register and lifecycle smoke

Create a throwaway app:

```bash
mkdir -p ~/tmp/devkit-smoke
cd ~/tmp/devkit-smoke
cat > serve.sh <<'SH'
#!/bin/sh
exec python3 -m http.server 5099 --bind 127.0.0.1
SH
chmod +x serve.sh

devkit register smoke --path "$PWD" --port 5099 --cmd "./serve.sh"
devkit start smoke
devkit list
devkit stop smoke
```

Verify:

- `devkit start smoke` reports a PID
- `lsof -nP -i :5099` shows the same PID listening
- `devkit list` shows `smoke` as `running`
- `devkit stop smoke` removes the listener and pid file

### 4. Dashboard and proxy

Verify:

- `http://dash.localhost` loads
- `http://smoke.localhost` works while the app is running
- stopping the app removes direct-port reachability

### 5. Reboot / restore flow

After at least one registered app exists:

```bash
devkit start-all
devkit stop-all
devkit start-all
```

Verify:

- repeated start/stop cycles do not leave stale pid files
- the same app can be started repeatedly without `EADDRINUSE`

## Release decision

Do not cut a public tag until:

- automated CLI and installer smoke tests are green
- Homebrew CLI install was checked on a clean machine
- Homebrew cask install was checked on a clean machine
- one real app was registered, started, stopped, and restarted successfully
