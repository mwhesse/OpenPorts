# OpenPorts

A native macOS menu bar application that lists open ports, allows browsing, copying, and terminating processes, with Docker container support.

## Features

- **Live in your menu bar** - Quick access to all open ports
- **Browse** - Open any port in your default browser
- **Copy** - Copy localhost URLs to clipboard
- **Terminate/Kill** - Stop processes with SIGTERM or SIGKILL
- **Docker support** - Manage containers with published ports
- **Configurable** - Auto-refresh intervals, confirmation dialogs, and more

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15 or later

## Setup Instructions

### 1. Check if Xcode is installed

```bash
xcode-select -p
```

If not installed, install from the Mac App Store or run:
```bash
xcode-select --install
```

### 2. Create the Xcode Project

1. Open Xcode
2. File → New → Project (⇧⌘N)
3. Select **macOS** → **App**
4. Click **Next**
5. Configure the project:
   - **Product Name**: `OpenPorts`
   - **Team**: Your Apple Developer Team (or "None")
   - **Organization Identifier**: `com.yourname` (e.g., `com.martinhesse`)
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - **Storage**: `None`
   - Uncheck "Include Tests"
6. Click **Next**
7. Choose the `openports` folder as the save location
8. Click **Create**

### 3. Configure as Menu Bar App

1. In the Project Navigator, click on the **OpenPorts** project (blue icon at top)
2. Select the **OpenPorts** target
3. Go to the **Info** tab
4. Click the **+** button to add a new key
5. Add: `Application is agent (UIElement)` = `YES`
   - This hides the app from the Dock and makes it a true menu bar app

### 4. Disable App Sandbox (Required for shell commands)

1. Still in the **OpenPorts** target
2. Go to **Signing & Capabilities** tab
3. Find **App Sandbox** and click the **X** to remove it
   - Or keep it and manually add entitlements for shell access

### 5. Replace the Default Files

Xcode creates default files that we need to replace:

1. **Delete** these files from Xcode (move to trash):
   - `ContentView.swift` (in the OpenPorts folder)
   - `OpenPortsApp.swift` (in the OpenPorts folder)

2. **Add our source files** to the project:
   - Right-click on the **OpenPorts** folder in Xcode
   - Select **Add Files to "OpenPorts"...**
   - Navigate to the `OpenPorts` folder containing our code
   - Select all folders: `Models`, `Services`, `Views`, `Utilities`, and the `OpenPortsApp.swift` file
   - Make sure **"Copy items if needed"** is UNCHECKED (files are already in place)
   - Make sure **"Create groups"** is selected
   - Click **Add**

### 6. Build and Run

1. Press **⌘R** to build and run
2. Look for the network icon in your menu bar
3. Click it to see the port list

## Project Structure

```
OpenPorts/
├── OpenPortsApp.swift          # App entry point with MenuBarExtra
├── Models/
│   ├── PortInfo.swift          # Port/process data model
│   ├── DockerContainer.swift   # Docker container model
│   └── AppSettings.swift       # User preferences
├── Services/
│   ├── PortScanner.swift       # Scans for open ports using lsof
│   ├── ProcessManager.swift    # Terminate/kill processes
│   └── DockerService.swift     # Docker container management
├── Views/
│   ├── ContentView.swift       # Main popover content
│   ├── PortRowView.swift       # Individual port entry
│   ├── DockerRowView.swift     # Docker container entry
│   └── SettingsView.swift      # Preferences window
└── Utilities/
    └── ShellExecutor.swift     # Run shell commands safely
```

## Usage

### Port Actions

| Action | Description |
|--------|-------------|
| Safari icon | Open `http://localhost:PORT` in browser |
| Copy icon | Copy URL to clipboard |
| Stop icon (orange) | Send SIGTERM - graceful termination |
| X icon (red) | Send SIGKILL - force kill |

### Docker Actions

| Action | Description |
|--------|-------------|
| Restart icon | Restart the container |
| Stop icon | `docker stop` - graceful stop |
| X icon | `docker kill` - force kill |

### Settings

Access settings by clicking the gear icon:

- **Auto-refresh interval**: Manual, 5s, 10s, or 30s
- **Confirm before kill**: Show confirmation dialogs
- **Show Docker containers**: Toggle Docker section
- **Show system processes**: Include root/system processes
- **Launch at login**: Start with macOS

## Troubleshooting

### "Permission denied" errors

The app needs to run shell commands (`lsof`, `kill`). Make sure:
1. App Sandbox is disabled, OR
2. You've added the necessary entitlements

### Docker not showing

1. Make sure Docker Desktop is running
2. Check "Show Docker containers" is enabled in Settings
3. Verify Docker CLI works: `docker ps`

### Ports not updating

1. Click the refresh button
2. Check the auto-refresh interval in Settings
3. Some ports may be owned by system processes (toggle "Show system processes")

## License

MIT License - Feel free to modify and distribute.
