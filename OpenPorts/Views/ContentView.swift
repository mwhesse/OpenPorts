import SwiftUI

/// Main content view for the menu bar popover.
/// Displays the list of open ports and Docker containers with action buttons.
struct ContentView: View {
    /// Port scanner service
    @StateObject private var portScanner = PortScanner()

    /// Docker service
    @StateObject private var dockerService = DockerService()

    /// App settings
    @ObservedObject var settings: AppSettings = .shared

    /// Controls visibility of the settings window
    @State private var showingSettings = false

    /// Controls visibility of confirmation dialog
    @State private var showingKillConfirmation = false
    @State private var pendingKillAction: (() async -> Void)?
    @State private var confirmationTitle = ""
    @State private var confirmationMessage = ""
    @State private var isPerformingAction = false

    /// Tracks if this is the initial load
    @State private var hasLoaded = false

    /// Tracks which ports are expanded (by port number)
    @State private var expandedPorts: Set<Int> = []

    /// Caches command lines for expanded ports (by port number)
    @State private var commandLineCache: [Int: String] = [:]

    /// Filter text for searching ports
    @State private var filterText: String = ""

    /// Whether the hidden section is expanded
    @State private var isHiddenSectionExpanded: Bool = false

    /// Ports filtered to exclude Docker-owned ports (shown in Docker section instead)
    private var nonDockerPorts: [PortInfo] {
        guard settings.showDockerContainers && dockerService.isDockerAvailable else {
            return portScanner.ports
        }
        // Get all host ports from Docker containers
        let dockerHostPorts = Set(dockerService.containers.flatMap { $0.ports.map { $0.hostPort } })
        // Filter out ports that match Docker published ports
        return portScanner.ports.filter { !dockerHostPorts.contains($0.port) }
    }

    /// Ports matching the current filter (excludes hidden)
    private var visiblePorts: [PortInfo] {
        let ports = nonDockerPorts.filter { !settings.isPortHidden(processName: $0.processName, port: $0.port) }
        return applyFilter(to: ports)
    }

    /// Hidden ports matching the current filter
    private var hiddenPorts: [PortInfo] {
        let ports = nonDockerPorts.filter { settings.isPortHidden(processName: $0.processName, port: $0.port) }
        return applyFilter(to: ports)
    }

    /// Applies the filter text to a list of ports
    private func applyFilter(to ports: [PortInfo]) -> [PortInfo] {
        guard !filterText.isEmpty else { return ports }
        let query = filterText.lowercased()
        return ports.filter { port in
            port.processName.lowercased().contains(query) ||
            String(port.port).contains(query) ||
            (commandLineCache[port.port]?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                header

                // Search field
                searchField

                Divider()

                // Content
                if portScanner.isScanning && portScanner.ports.isEmpty {
                    loadingView
                } else if portScanner.ports.isEmpty && dockerService.containers.isEmpty {
                    emptyStateView
                } else {
                    scrollableContent
                }

                Divider()

                // Footer
                footer
            }

            // Custom confirmation overlay
            if showingKillConfirmation {
                confirmationOverlay
            }
        }
        .frame(width: 360, height: 480)
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await initialLoad()
        }
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Dialog
            VStack(spacing: 16) {
                Text(confirmationTitle)
                    .font(.headline)

                Text(confirmationMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingKillConfirmation = false
                        pendingKillAction = nil
                    }
                    .buttonStyle(.bordered)
                    .disabled(isPerformingAction)

                    Button(isPerformingAction ? "Working..." : "Confirm") {
                        guard let action = pendingKillAction else { return }
                        isPerformingAction = true
                        Task {
                            await action()
                            await MainActor.run {
                                isPerformingAction = false
                                showingKillConfirmation = false
                                pendingKillAction = nil
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isPerformingAction)
                }
            }
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 10)
            .padding(32)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Open Ports")
                .font(.headline)

            Spacer()

            // Refresh button
            Button(action: { Task { await refresh() } }) {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(portScanner.isScanning ? 360 : 0))
                    .animation(
                        portScanner.isScanning
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: portScanner.isScanning
                    )
            }
            .buttonStyle(.plain)
            .disabled(portScanner.isScanning)
            .help("Refresh")

            // Settings button
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
            .popover(isPresented: $showingSettings) {
                SettingsView(settings: settings)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Filter by name, port, or path...", text: $filterText)
                .textFieldStyle(.plain)
            if !filterText.isEmpty {
                Button(action: { filterText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Content Views

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Scanning ports...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No open ports")
                .font(.headline)

            Text("No listening TCP ports found on this system")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scrollableContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                // Visible Ports Section
                if !visiblePorts.isEmpty {
                    Section {
                        ForEach(visiblePorts) { port in
                            PortRowView(
                                port: port,
                                isExpanded: expandedPorts.contains(port.port),
                                commandLine: commandLineCache[port.port],
                                onToggleExpand: {
                                    if expandedPorts.contains(port.port) {
                                        expandedPorts.remove(port.port)
                                    } else {
                                        expandedPorts.insert(port.port)
                                    }
                                },
                                onCommandLineFetched: { cmdLine in
                                    commandLineCache[port.port] = cmdLine
                                },
                                onHide: {
                                    settings.hidePort(processName: port.processName, port: port.port)
                                },
                                onBrowse: { browsePort(port.port) },
                                onCopy: { copyPort(port.port) },
                                onTerminate: { terminateProcess(port) },
                                onKill: { killProcess(port) }
                            )
                        }
                    } header: {
                        sectionHeader(title: "Ports", count: visiblePorts.count)
                    }
                }

                // Hidden Ports Section
                if !hiddenPorts.isEmpty {
                    Section {
                        if isHiddenSectionExpanded {
                            ForEach(hiddenPorts) { port in
                                PortRowView(
                                    port: port,
                                    isExpanded: expandedPorts.contains(port.port),
                                    commandLine: commandLineCache[port.port],
                                    isHidden: true,
                                    onToggleExpand: {
                                        if expandedPorts.contains(port.port) {
                                            expandedPorts.remove(port.port)
                                        } else {
                                            expandedPorts.insert(port.port)
                                        }
                                    },
                                    onCommandLineFetched: { cmdLine in
                                        commandLineCache[port.port] = cmdLine
                                    },
                                    onUnhide: {
                                        settings.unhidePort(processName: port.processName, port: port.port)
                                    },
                                    onBrowse: { browsePort(port.port) },
                                    onCopy: { copyPort(port.port) },
                                    onTerminate: { terminateProcess(port) },
                                    onKill: { killProcess(port) }
                                )
                            }
                        }
                    } header: {
                        hiddenSectionHeader
                    }
                }

                // Docker Section
                if settings.showDockerContainers && dockerService.isDockerAvailable {
                    Section {
                        if dockerService.containers.isEmpty {
                            dockerEmptyState
                        } else {
                            ForEach(dockerService.containers) { container in
                                DockerRowView(
                                    container: container,
                                    onBrowse: { port in browsePort(port) },
                                    onCopy: { port in copyPort(port) },
                                    onStop: { stopContainer(container) },
                                    onKill: { killContainer(container) },
                                    onRestart: { restartContainer(container) }
                                )
                            }
                        }
                    } header: {
                        sectionHeader(
                            title: "Docker Containers",
                            count: dockerService.containers.count,
                            icon: "shippingbox.fill"
                        )
                    }
                } else if settings.showDockerContainers && !dockerService.isDockerAvailable {
                    Section {
                        dockerUnavailableView
                    } header: {
                        sectionHeader(title: "Docker", count: 0, icon: "shippingbox.fill")
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func sectionHeader(title: String, count: Int, icon: String = "network") -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Text("(\(count))")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var hiddenSectionHeader: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isHiddenSectionExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: "eye.slash")
                    .font(.caption)
                Text("Hidden")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("(\(hiddenPorts.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: isHiddenSectionExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var dockerEmptyState: some View {
        HStack {
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)
            Text("No containers with published ports")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var dockerUnavailableView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text("Docker is not running")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Status text
            if let error = portScanner.lastError {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text("\(visiblePorts.count) ports")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Quit button
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func initialLoad() async {
        await portScanner.scan()
        if settings.showDockerContainers {
            await dockerService.refresh()
        }
    }

    private func refresh() async {
        await portScanner.scan()
        if settings.showDockerContainers {
            await dockerService.refresh()
        }
    }

    private func browsePort(_ port: Int) {
        guard let url = URL(string: "http://localhost:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func copyPort(_ port: Int) {
        let url = "http://localhost:\(port)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }

    private func terminateProcess(_ port: PortInfo) {
        let action: () async -> Void = {
            let result = await ProcessManager.terminate(pid: port.pid)
            if result.succeeded {
                // Wait a moment then refresh
                try? await Task.sleep(nanoseconds: 500_000_000)
                await portScanner.scan()
            }
        }

        if settings.confirmBeforeKill {
            confirmationTitle = "Terminate Process?"
            confirmationMessage = "This will send SIGTERM to \(port.processName) (PID \(port.pid)) on port \(port.port)."
            pendingKillAction = action
            showingKillConfirmation = true
        } else {
            Task { await action() }
        }
    }

    private func killProcess(_ port: PortInfo) {
        let action: () async -> Void = {
            let result = await ProcessManager.kill(pid: port.pid)
            if result.succeeded {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await portScanner.scan()
            }
        }

        if settings.confirmBeforeKill {
            confirmationTitle = "Kill Process?"
            confirmationMessage = "This will forcefully kill \(port.processName) (PID \(port.pid)) on port \(port.port). Unsaved data may be lost."
            pendingKillAction = action
            showingKillConfirmation = true
        } else {
            Task { await action() }
        }
    }

    private func stopContainer(_ container: DockerContainer) {
        let action: () async -> Void = {
            _ = await dockerService.stopContainer(container.id)
        }

        if settings.confirmBeforeDockerStop {
            confirmationTitle = "Stop Container?"
            confirmationMessage = "This will stop the container '\(container.name)'."
            pendingKillAction = action
            showingKillConfirmation = true
        } else {
            Task { await action() }
        }
    }

    private func killContainer(_ container: DockerContainer) {
        let action: () async -> Void = {
            _ = await dockerService.killContainer(container.id)
        }

        if settings.confirmBeforeDockerStop {
            confirmationTitle = "Kill Container?"
            confirmationMessage = "This will forcefully kill the container '\(container.name)'. Data may be lost."
            pendingKillAction = action
            showingKillConfirmation = true
        } else {
            Task { await action() }
        }
    }

    private func restartContainer(_ container: DockerContainer) {
        Task {
            _ = await dockerService.restartContainer(container.id)
        }
    }
}

// MARK: - Import for NSWorkspace and NSPasteboard

import AppKit

// MARK: - Preview

#Preview("Content View") {
    ContentView()
}

#Preview("With Sample Data") {
    ContentView()
}
