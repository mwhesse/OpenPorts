import Foundation

/// Represents information about an open network port on the system.
/// This model is populated by parsing the output of `lsof -iTCP -sTCP:LISTEN`.
struct PortInfo: Identifiable, Hashable {
    /// Unique identifier for SwiftUI lists
    let id: UUID

    /// The port number (e.g., 3000, 8080)
    let port: Int

    /// Process ID that owns this port
    let pid: Int

    /// Name of the process/command (e.g., "node", "python3")
    let processName: String

    /// Username running the process
    let user: String

    /// The full address string from lsof (e.g., "*:3000", "localhost:8080")
    let address: String

    /// File descriptor type (usually "IPv4" or "IPv6")
    let type: String

    init(
        id: UUID = UUID(),
        port: Int,
        pid: Int,
        processName: String,
        user: String,
        address: String = "",
        type: String = "IPv4"
    ) {
        self.id = id
        self.port = port
        self.pid = pid
        self.processName = processName
        self.user = user
        self.address = address
        self.type = type
    }

    /// Returns the localhost URL for this port
    var localhostURL: URL? {
        URL(string: "http://localhost:\(port)")
    }

    /// Display-friendly description of the port
    var displayName: String {
        "\(processName) :\(port)"
    }

    /// Detailed description including PID
    var detailDescription: String {
        "PID \(pid) • \(user)"
    }
}

// MARK: - Sample Data for Previews

extension PortInfo {
    /// Sample data for SwiftUI previews
    static let samples: [PortInfo] = [
        PortInfo(port: 3000, pid: 1234, processName: "node", user: "martin", type: "IPv4"),
        PortInfo(port: 8080, pid: 5678, processName: "java", user: "martin", type: "IPv6"),
        PortInfo(port: 5432, pid: 9012, processName: "postgres", user: "_postgres", type: "IPv4"),
        PortInfo(port: 6379, pid: 3456, processName: "redis-server", user: "martin", type: "IPv4"),
    ]
}
