import Foundation

/// Represents a Docker container with published ports.
/// This model is populated by parsing the output of `docker ps`.
struct DockerContainer: Identifiable, Hashable {
    /// Unique identifier (Docker container ID)
    let id: String

    /// Container name
    let name: String

    /// Image name the container was created from
    let image: String

    /// Published port mappings (host:container)
    let ports: [PortMapping]

    /// Container status (e.g., "Up 2 hours")
    let status: String

    /// Whether the container is currently running
    var isRunning: Bool {
        status.lowercased().contains("up")
    }

    /// Represents a port mapping between host and container
    struct PortMapping: Identifiable, Hashable {
        let id = UUID()

        /// Host port (the port exposed on your machine)
        let hostPort: Int

        /// Container port (the port inside the container)
        let containerPort: Int

        /// Protocol (tcp or udp)
        let proto: String

        /// Host IP (usually 0.0.0.0 or 127.0.0.1)
        let hostIP: String

        init(hostPort: Int, containerPort: Int, proto: String = "tcp", hostIP: String = "0.0.0.0") {
            self.hostPort = hostPort
            self.containerPort = containerPort
            self.proto = proto
            self.hostIP = hostIP
        }

        /// Display string for the port mapping
        var displayString: String {
            "\(hostPort) → \(containerPort)/\(proto)"
        }

        /// URL to access this port
        var localhostURL: URL? {
            URL(string: "http://localhost:\(hostPort)")
        }
    }
}

// MARK: - Parsing

extension DockerContainer {
    /// Parses the ports string from `docker ps` output.
    /// Format examples:
    /// - "0.0.0.0:3000->3000/tcp"
    /// - "0.0.0.0:8080->80/tcp, 0.0.0.0:8443->443/tcp"
    /// - "3000/tcp" (exposed but not published)
    static func parsePortsString(_ portsString: String) -> [PortMapping] {
        guard !portsString.isEmpty else { return [] }

        var mappings: [PortMapping] = []
        let portEntries = portsString.components(separatedBy: ", ")

        for entry in portEntries {
            // Match pattern: IP:hostPort->containerPort/protocol
            // Example: 0.0.0.0:3000->3000/tcp
            let pattern = #"(?:(\d+\.\d+\.\d+\.\d+):)?(\d+)->(\d+)/(\w+)"#

            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: entry, range: NSRange(entry.startIndex..., in: entry))
            {
                let hostIP = match.range(at: 1).location != NSNotFound
                    ? String(entry[Range(match.range(at: 1), in: entry)!])
                    : "0.0.0.0"

                if let hostPortRange = Range(match.range(at: 2), in: entry),
                   let containerPortRange = Range(match.range(at: 3), in: entry),
                   let protoRange = Range(match.range(at: 4), in: entry),
                   let hostPort = Int(entry[hostPortRange]),
                   let containerPort = Int(entry[containerPortRange])
                {
                    mappings.append(PortMapping(
                        hostPort: hostPort,
                        containerPort: containerPort,
                        proto: String(entry[protoRange]),
                        hostIP: hostIP
                    ))
                }
            }
        }

        return mappings
    }
}

// MARK: - Sample Data for Previews

extension DockerContainer {
    static let samples: [DockerContainer] = [
        DockerContainer(
            id: "abc123def456",
            name: "my-postgres",
            image: "postgres:15",
            ports: [PortMapping(hostPort: 5432, containerPort: 5432)],
            status: "Up 2 hours"
        ),
        DockerContainer(
            id: "def456ghi789",
            name: "redis-cache",
            image: "redis:7",
            ports: [PortMapping(hostPort: 6379, containerPort: 6379)],
            status: "Up 30 minutes"
        ),
        DockerContainer(
            id: "ghi789jkl012",
            name: "nginx-proxy",
            image: "nginx:latest",
            ports: [
                PortMapping(hostPort: 80, containerPort: 80),
                PortMapping(hostPort: 443, containerPort: 443),
            ],
            status: "Up 5 hours"
        ),
    ]
}
