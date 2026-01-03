# OpenPorts

A native macOS menu bar application for monitoring and managing open TCP ports and Docker containers.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Menu bar app** - Lives in your menu bar for quick access
- **Port scanning** - Displays all listening TCP ports with process info
- **Expandable details** - Click any port to see the full command line path
- **App icons** - Shows application icons for GUI processes
- **Filter & search** - Filter ports by name, port number, or path
- **Hide ports** - Hide frequently-running ports you don't need to see
- **Process control** - Terminate (SIGTERM) or kill (SIGKILL) processes
- **Docker support** - View and manage containers with published ports
- **Auto-refresh** - Configurable refresh intervals (5s, 10s, 30s, or manual)

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for generating the Xcode project)

## Installation

### Download the Release

1. Download `OpenPorts.zip` from the [latest release](https://github.com/mwhesse/OpenPorts/releases/latest)
2. Unzip and move `OpenPorts.app` to your Applications folder
3. **Important**: Remove the quarantine attribute (required for unsigned apps):
   ```bash
   xattr -cr /Applications/OpenPorts.app
   ```
4. Double-click to launch, or right-click and select "Open"

### Build from Source

#### 1. Install XcodeGen

```bash
brew install xcodegen
```

#### 2. Clone and build

```bash
git clone https://github.com/mwhesse/OpenPorts.git
cd OpenPorts
xcodegen generate
open OpenPorts.xcodeproj
```

#### 3. Build and run

Press **⌘R** in Xcode to build and run. Look for the network icon in your menu bar.

## Project Structure

```
OpenPorts/
├── OpenPortsApp.swift          # App entry point with MenuBarExtra
├── Models/
│   ├── PortInfo.swift          # Port/process data model
│   ├── DockerContainer.swift   # Docker container model
│   └── AppSettings.swift       # User preferences (persisted)
├── Services/
│   ├── PortScanner.swift       # Scans for open ports using lsof
│   ├── ProcessManager.swift    # Terminate/kill processes
│   └── DockerService.swift     # Docker container management
├── Views/
│   ├── ContentView.swift       # Main popover content
│   ├── PortRowView.swift       # Individual port row (expandable)
│   ├── DockerRowView.swift     # Docker container row
│   └── SettingsView.swift      # Settings popover
└── Utilities/
    └── ShellExecutor.swift     # Shell command execution
```

## Usage

### Port List

- **Click a port row** to expand and see the full process command line
- **Hover** over a port to reveal the hide/unhide button
- Use the **filter field** to search by process name, port number, or path

### Port Actions (in expanded view)

| Button | Action |
|--------|--------|
| **Open** | Open `http://localhost:PORT` in browser |
| **Copy** | Copy URL to clipboard |
| **Terminate** | Send SIGTERM (graceful shutdown) |
| **Kill** | Send SIGKILL (force kill) |

### Docker Actions

| Button | Action |
|--------|--------|
| **Restart** | Restart the container |
| **Stop** | Graceful stop (`docker stop`) |
| **Kill** | Force kill (`docker kill`) |

### Settings

Click the gear icon to access settings:

| Setting | Description |
|---------|-------------|
| Auto-refresh | Manual, 5s, 10s, or 30s intervals |
| Confirm before kill | Show confirmation dialog for process termination |
| Confirm before Docker stop | Show confirmation for container operations |
| Show Docker containers | Toggle Docker section visibility |
| Show system processes | Include root/system-owned processes |
| Launch at login | Start OpenPorts when you log in |

## Troubleshooting

### Ports not appearing

- Click the refresh button
- Check if the process is owned by root (enable "Show system processes" in settings)
- Verify the port is listening: `lsof -iTCP -sTCP:LISTEN -P -n | grep PORT`

### "Permission denied" when killing

Some processes (especially system processes) require elevated privileges. The app cannot kill processes owned by root or other users.

### Docker section not showing

1. Ensure Docker Desktop is running
2. Enable "Show Docker containers" in settings
3. Verify Docker CLI works: `docker ps`

## License

MIT License - See [LICENSE](LICENSE) for details.
