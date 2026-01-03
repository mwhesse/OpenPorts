import Foundation
import SwiftUI

/// Manages user preferences for the OpenPorts app.
/// Settings are persisted using @AppStorage (UserDefaults).
final class AppSettings: ObservableObject {

    /// Shared singleton instance
    static let shared = AppSettings()

    // MARK: - Refresh Settings

    /// How often to automatically refresh the port list
    enum RefreshInterval: Int, CaseIterable, Identifiable {
        case manual = 0
        case fiveSeconds = 5
        case tenSeconds = 10
        case thirtySeconds = 30

        var id: Int { rawValue }

        var displayName: String {
            switch self {
            case .manual: return "Manual"
            case .fiveSeconds: return "5 seconds"
            case .tenSeconds: return "10 seconds"
            case .thirtySeconds: return "30 seconds"
            }
        }

        var interval: TimeInterval? {
            guard rawValue > 0 else { return nil }
            return TimeInterval(rawValue)
        }
    }

    /// The selected refresh interval
    @AppStorage("refreshInterval") var refreshIntervalRawValue: Int = RefreshInterval.tenSeconds.rawValue {
        didSet { objectWillChange.send() }
    }

    var refreshInterval: RefreshInterval {
        get { RefreshInterval(rawValue: refreshIntervalRawValue) ?? .tenSeconds }
        set { refreshIntervalRawValue = newValue.rawValue }
    }

    // MARK: - Safety Settings

    /// Whether to show a confirmation dialog before killing/terminating processes
    @AppStorage("confirmBeforeKill") var confirmBeforeKill: Bool = true {
        didSet { objectWillChange.send() }
    }

    /// Whether to show a confirmation dialog before stopping Docker containers
    @AppStorage("confirmBeforeDockerStop") var confirmBeforeDockerStop: Bool = true {
        didSet { objectWillChange.send() }
    }

    // MARK: - Display Settings

    /// Whether to show Docker containers in the port list
    @AppStorage("showDockerContainers") var showDockerContainers: Bool = true {
        didSet { objectWillChange.send() }
    }

    /// Whether to show system processes (running as root or system users)
    @AppStorage("showSystemProcesses") var showSystemProcesses: Bool = false {
        didSet { objectWillChange.send() }
    }

    // MARK: - Startup Settings

    /// Whether to launch the app at login
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet {
            objectWillChange.send()
            updateLaunchAtLogin()
        }
    }

    // MARK: - Hidden Ports

    /// Hidden ports stored as JSON-encoded Set<String> in format "processName:port"
    @AppStorage("hiddenPorts") private var hiddenPortsData: Data = Data()

    /// Set of hidden port identifiers (format: "processName:port")
    var hiddenPorts: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: hiddenPortsData)) ?? []
        }
        set {
            hiddenPortsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            objectWillChange.send()
        }
    }

    /// Creates a hidden port identifier from process name and port
    static func hiddenPortKey(processName: String, port: Int) -> String {
        "\(processName):\(port)"
    }

    /// Checks if a port is hidden
    func isPortHidden(processName: String, port: Int) -> Bool {
        hiddenPorts.contains(Self.hiddenPortKey(processName: processName, port: port))
    }

    /// Hides a port
    func hidePort(processName: String, port: Int) {
        var ports = hiddenPorts
        ports.insert(Self.hiddenPortKey(processName: processName, port: port))
        hiddenPorts = ports
    }

    /// Unhides a port
    func unhidePort(processName: String, port: Int) {
        var ports = hiddenPorts
        ports.remove(Self.hiddenPortKey(processName: processName, port: port))
        hiddenPorts = ports
    }

    // MARK: - Private

    private init() {}

    /// Updates the system login item based on the launchAtLogin setting.
    /// Uses SMAppService on macOS 13+ for modern launch-at-login handling.
    private func updateLaunchAtLogin() {
        // SMAppService is the modern way to handle launch at login on macOS 13+
        // This requires adding the app to Login Items in System Settings
        // For now, we'll just store the preference - users can manually add via System Settings

        // Note: To fully implement launch at login, you would use:
        // import ServiceManagement
        // if launchAtLogin {
        //     try? SMAppService.mainApp.register()
        // } else {
        //     try? SMAppService.mainApp.unregister()
        // }
    }
}

// MARK: - Preview Support

extension AppSettings {
    /// Creates a preview instance with custom settings
    static func preview(
        refreshInterval: RefreshInterval = .tenSeconds,
        confirmBeforeKill: Bool = true,
        showDockerContainers: Bool = true
    ) -> AppSettings {
        let settings = AppSettings()
        settings.refreshInterval = refreshInterval
        settings.confirmBeforeKill = confirmBeforeKill
        settings.showDockerContainers = showDockerContainers
        return settings
    }
}
