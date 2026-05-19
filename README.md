# Port Watcher
<img width="546" height="462" alt="Screenshot 2026-03-21 at 12 36 37 PM" src="https://github.com/user-attachments/assets/683f541f-15cc-4ad5-a4b1-ac09f1f2f1f9" />

> A lightweight macOS menu bar app that monitors active TCP listening processes. See which ports are in use, what's using them, and kill processes with a click.

Built for the situation where vibe-coding across projects leaves orphaned dev servers squatting on ports.

## Features

- Lives in the menu bar (no Dock icon)
- Lists all TCP listening processes with port, command, PID, uptime, and working directory
- **Dev Servers** filter for the common ranges (3000s, 4000s, 5000s, 8000s, 9000s)
- Search/filter by port, command, or PID
- Kill or force-kill processes
- Open ports in browser or copy the localhost URL
- Open the process's working directory in Finder
- Menu bar icon flashes when ports change; turns orange for unfamiliar processes
- Right-click the icon for Open at Login, About, Quit
- Auto-refreshes every 5 seconds

## Install

### Download (recommended)

1. Download `PortWatcher.zip` from the [latest release](https://github.com/GreenFlux/port-watcher/releases/latest)
2. Double-click to unzip
3. Drag `PortWatcher.app` to `/Applications`
4. Launch from Spotlight or Applications

The build is signed and notarized by GreenFlux, LLC — no Gatekeeper warnings, no `xattr` workarounds.

### Homebrew

```bash
brew tap GreenFlux/tap
brew install --cask port-watcher
```

### Build from source

Requires Xcode 15+ and macOS 14+.

```bash
git clone https://github.com/GreenFlux/port-watcher.git
cd port-watcher
make install
```

Other targets: `make run`, `make uninstall`, `make clean`.

## Permissions

Port Watcher needs to read other processes' working directories to show where each dev server was launched from. macOS gates this behind **Full Disk Access**:

1. Open **System Settings → Privacy & Security → Full Disk Access**
2. Toggle on Port Watcher

Without it, the app still works but the `cwd` column shows `Unknown` for processes outside your shell environment.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel

## Contributing

Issues and pull requests welcome. For build/release internals, see [`docs/RELEASING.md`](docs/RELEASING.md).

## License

MIT — see [LICENSE](LICENSE).

## Author

Made by [GreenFlux, LLC](https://greenflux.us)
