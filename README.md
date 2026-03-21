# Port Watcher
<img width="546" height="462" alt="Screenshot 2026-03-21 at 12 36 37 PM" src="https://github.com/user-attachments/assets/683f541f-15cc-4ad5-a4b1-ac09f1f2f1f9" />

> A lightweight macOS menu bar app that monitors active TCP listening processes. See which ports are in use, what's using them, and kill processes with a click.

## Features

- Lives in the menu bar (no Dock icon)
- Lists all TCP listening processes with port, command, PID, uptime, and working directory
- **Dev Servers** filter to focus on development ports (3000–3999, 4000–4999, 5000–5999, 8000–8999, 9000–9999)
- Search/filter by port, command, or PID
- Kill or force-kill processes
- Open ports in browser or copy localhost URL
- Open process working directory in Finder
- Menu bar icon flashes yellow when ports change
- Right-click icon for Open at Login, About, Quit
- Auto-refreshes every 5 seconds

## Requirements

- macOS 14+

## Install

```bash
git clone https://github.com/GreenFlux/port-watcher.git
cd port-watcher
make install
```

This builds a Release binary and copies `PortWatcher.app` to `/Applications`. To install elsewhere:

```bash
make install INSTALL_DIR=~/Applications
```

Then launch from Applications or Spotlight.

## Other Commands

```bash
make run         # build, install, and launch
make uninstall   # remove from /Applications
make clean       # delete local build artifacts
```

## License

MIT — see [LICENSE](LICENSE)

## Author

Made by [GreenFlux, LLC](https://greenflux.us)
