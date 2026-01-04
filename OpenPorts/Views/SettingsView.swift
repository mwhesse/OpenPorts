import SwiftUI

/// Settings view for configuring app preferences.
/// Displayed in a separate window accessible from the menu.
struct SettingsView: View {
    /// App settings instance
    @ObservedObject var settings: AppSettings

    /// Environment to dismiss the window
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            // Refresh Settings Section
            Section {
                Picker("Auto-refresh interval", selection: $settings.refreshInterval) {
                    ForEach(AppSettings.RefreshInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Label("Refresh", systemImage: "arrow.clockwise")
            } footer: {
                Text("How often to automatically scan for open ports")
                    .foregroundColor(.secondary)
            }

            // Safety Settings Section
            Section {
                Toggle("Confirm before terminating processes", isOn: $settings.confirmBeforeKill)

                Toggle("Confirm before stopping Docker containers", isOn: $settings.confirmBeforeDockerStop)
            } header: {
                Label("Safety", systemImage: "exclamationmark.shield")
            } footer: {
                Text("Show confirmation dialogs before potentially destructive actions")
                    .foregroundColor(.secondary)
            }

            // Display Settings Section
            Section {
                Toggle("Show Docker containers", isOn: $settings.showDockerContainers)

                Toggle("Show system processes", isOn: $settings.showSystemProcesses)
            } header: {
                Label("Display", systemImage: "eye")
            } footer: {
                Text("System processes run as root or system users (e.g., postgres, mysql)")
                    .foregroundColor(.secondary)
            }

            // Appearance Settings Section
            Section {
                Picker("Background style", selection: $settings.backgroundStyle) {
                    ForEach(AppSettings.BackgroundStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.menu)

                if settings.backgroundStyle == .solid {
                    Picker("Background color", selection: $settings.backgroundColor) {
                        ForEach(AppSettings.BackgroundColor.allCases) { color in
                            Text(color.displayName).tag(color)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Opacity")
                        Spacer()
                        Text("\(Int(settings.backgroundOpacity * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.backgroundOpacity, in: 0.5...1.0, step: 0.05)
                }
            } header: {
                Label("Appearance", systemImage: "paintbrush")
            } footer: {
                Text("Customize the popover background appearance")
                    .foregroundColor(.secondary)
            }

            // Startup Settings Section
            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            } header: {
                Label("Startup", systemImage: "power")
            } footer: {
                Text("Start OpenPorts automatically when you log in")
                    .foregroundColor(.secondary)
            }

            // About Section
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.appVersion)
                        .foregroundColor(.secondary)
                }

                Link(destination: URL(string: "https://github.com")!) {
                    HStack {
                        Text("View on GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Label("About", systemImage: "info.circle")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 500)
        .navigationTitle("Settings")
    }
}

// MARK: - Bundle Extension

extension Bundle {
    /// Returns the app version string (e.g., "1.0.0")
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Returns the build number string (e.g., "1")
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Preview

#Preview("Settings") {
    SettingsView(settings: .shared)
}
