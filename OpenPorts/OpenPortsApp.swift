import SwiftUI

/// Main entry point for the OpenPorts application.
/// This app runs exclusively in the menu bar (no dock icon).
@main
struct OpenPortsApp: App {
    /// App settings shared across the app
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        // MenuBarExtra creates a menu bar icon with a popover
        // Available on macOS 13.0+
        MenuBarExtra {
            ContentView(settings: settings)
        } label: {
            // Menu bar icon - using SF Symbol for network/port
            Image(systemName: "network")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window) // Use window style for richer content

        // Settings window (accessible via Settings menu or keyboard shortcut)
        Settings {
            SettingsView(settings: settings)
        }
    }
}
