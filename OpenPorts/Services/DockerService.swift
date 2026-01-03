import Foundation
import Combine

/// Service responsible for interacting with Docker to list and manage containers.
/// Requires Docker Desktop or Docker CLI to be installed and running.
@MainActor
final class DockerService: ObservableObject {

    /// List of Docker containers with published ports
    @Published private(set) var containers: [DockerContainer] = []

    /// Whether Docker is available on the system
    @Published private(set) var isDockerAvailable: Bool = false

    /// Whether a refresh is currently in progress
    @Published private(set) var isRefreshing: Bool = false

    /// Last error message, if any
    @Published private(set) var lastError: String?

    // MARK: - Public Methods

    /// Checks if Docker is installed and running
    func checkDockerAvailability() async {
        let result = await ShellExecutor.execute("docker info 2>/dev/null", timeout: 5)
        isDockerAvailable = result.succeeded
    }

    /// Refreshes the list of Docker containers with published ports
    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        lastError = nil

        // First check if Docker is available
        await checkDockerAvailability()

        guard isDockerAvailable else {
            containers = []
            isRefreshing = false
            return
        }

        // Get list of running containers with their port mappings
        // Using a custom format for easier parsing
        let format = "{{.ID}}|{{.Names}}|{{.Image}}|{{.Ports}}|{{.Status}}"
        let result = await ShellExecutor.execute("docker ps --format '\(format)'")

        if result.succeeded {
            containers = parseDockerOutput(result.output)
        } else {
            lastError = result.error
            // Don't clear existing containers on error
        }

        isRefreshing = false
    }

    /// Stops a Docker container gracefully
    /// - Parameter containerId: The container ID or name
    /// - Returns: True if successful, false otherwise
    func stopContainer(_ containerId: String) async -> Bool {
        let result = await ShellExecutor.execute("docker stop \(containerId)", timeout: 30)
        if result.succeeded {
            await refresh()
            return true
        }
        lastError = result.error
        return false
    }

    /// Kills a Docker container forcefully
    /// - Parameter containerId: The container ID or name
    /// - Returns: True if successful, false otherwise
    func killContainer(_ containerId: String) async -> Bool {
        let result = await ShellExecutor.execute("docker kill \(containerId)", timeout: 10)
        if result.succeeded {
            await refresh()
            return true
        }
        lastError = result.error
        return false
    }

    /// Restarts a Docker container
    /// - Parameter containerId: The container ID or name
    /// - Returns: True if successful, false otherwise
    func restartContainer(_ containerId: String) async -> Bool {
        let result = await ShellExecutor.execute("docker restart \(containerId)", timeout: 30)
        if result.succeeded {
            await refresh()
            return true
        }
        lastError = result.error
        return false
    }

    /// Opens the Docker Desktop app (if installed)
    func openDockerDesktop() {
        let url = URL(fileURLWithPath: "/Applications/Docker.app")
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private Methods

    /// Parses the output of `docker ps --format`
    private func parseDockerOutput(_ output: String) -> [DockerContainer] {
        guard !output.isEmpty else { return [] }

        let lines = output.components(separatedBy: "\n")
        var parsedContainers: [DockerContainer] = []

        for line in lines {
            guard !line.isEmpty else { continue }

            let components = line.components(separatedBy: "|")
            guard components.count >= 5 else { continue }

            let id = components[0]
            let name = components[1]
            let image = components[2]
            let portsString = components[3]
            let status = components[4]

            // Parse port mappings
            let ports = DockerContainer.parsePortsString(portsString)

            // Only include containers with published ports
            guard !ports.isEmpty else { continue }

            parsedContainers.append(DockerContainer(
                id: id,
                name: name,
                image: image,
                ports: ports,
                status: status
            ))
        }

        // Sort by name
        return parsedContainers.sorted { $0.name < $1.name }
    }
}

// MARK: - Import for NSWorkspace

import AppKit

// MARK: - Preview Support

extension DockerService {
    /// Creates a preview instance with sample data
    static var preview: DockerService {
        let service = DockerService()
        service.isDockerAvailable = true
        service.containers = DockerContainer.samples
        return service
    }

    /// Creates a preview instance showing Docker unavailable
    static var previewUnavailable: DockerService {
        let service = DockerService()
        service.isDockerAvailable = false
        service.containers = []
        return service
    }
}
