import Foundation
import Combine

/// Service responsible for scanning and listing open TCP ports on the system.
/// Uses `lsof` to discover listening ports and their associated processes.
@MainActor
final class PortScanner: ObservableObject {

    /// List of currently open ports
    @Published private(set) var ports: [PortInfo] = []

    /// Whether a scan is currently in progress
    @Published private(set) var isScanning: Bool = false

    /// Last error message, if any
    @Published private(set) var lastError: String?

    /// Reference to app settings
    private let settings: AppSettings

    /// Timer for auto-refresh
    private var refreshTimer: AnyCancellable?

    init(settings: AppSettings = .shared) {
        self.settings = settings
        setupAutoRefresh()
    }

    // MARK: - Public Methods

    /// Performs a single scan for open ports
    func scan() async {
        guard !isScanning else { return }

        isScanning = true
        lastError = nil

        // Run lsof command to list all listening TCP connections
        // -iTCP: Show only TCP connections
        // -sTCP:LISTEN: Show only listening sockets
        // -P: Don't resolve port numbers to service names
        // -n: Don't resolve hostnames
        let result = await ShellExecutor.execute("lsof -iTCP -sTCP:LISTEN -P -n")

        if result.succeeded {
            var parsedPorts = parseLsofOutput(result.output)

            // Fetch full process names using ps (lsof truncates names)
            parsedPorts = await fetchFullProcessNames(for: parsedPorts)

            ports = parsedPorts
        } else {
            lastError = result.error.isEmpty ? "Failed to scan ports" : result.error
            // Don't clear existing ports on error
        }

        isScanning = false
    }

    /// Fetches full process names for all ports using a single ps command
    private func fetchFullProcessNames(for ports: [PortInfo]) async -> [PortInfo] {
        guard !ports.isEmpty else { return ports }

        // Get all PIDs
        let pids = ports.map { String($0.pid) }.joined(separator: ",")

        // Fetch process names in one call: ps -p pid1,pid2,... -o pid=,comm=
        let result = await ShellExecutor.execute("ps -p \(pids) -o pid=,comm= 2>/dev/null")

        guard result.succeeded else { return ports }

        // Parse ps output into a dictionary of PID -> process name
        var processNames: [Int: String] = [:]
        for line in result.output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Format: "  PID /path/to/command" or "PID command"
            let parts = trimmed.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
            guard parts.count == 2,
                  let pid = Int(parts[0]) else { continue }

            // Get just the executable name from the path
            let fullPath = String(parts[1])
            let execName = (fullPath as NSString).lastPathComponent
            processNames[pid] = execName
        }

        // Update ports with full names
        return ports.map { port in
            if let fullName = processNames[port.pid] {
                return PortInfo(
                    id: port.id,
                    port: port.port,
                    pid: port.pid,
                    processName: fullName,
                    user: port.user,
                    address: port.address,
                    type: port.type
                )
            }
            return port
        }
    }

    /// Starts auto-refresh based on settings
    func startAutoRefresh() {
        setupAutoRefresh()
    }

    /// Stops auto-refresh
    func stopAutoRefresh() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }

    // MARK: - Private Methods

    /// Sets up the auto-refresh timer based on current settings
    private func setupAutoRefresh() {
        refreshTimer?.cancel()

        guard let interval = settings.refreshInterval.interval else {
            refreshTimer = nil
            return
        }

        refreshTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.scan() }
            }
    }

    /// Parses the output of `lsof -iTCP -sTCP:LISTEN -P -n`
    /// Sample output:
    /// ```
    /// COMMAND     PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    /// node      12345 martin   22u  IPv4 0x1234567890      0t0  TCP *:3000 (LISTEN)
    /// postgres   5432 _postgres 5u  IPv6 0x0987654321      0t0  TCP [::1]:5432 (LISTEN)
    /// ```
    private func parseLsofOutput(_ output: String) -> [PortInfo] {
        let lines = output.components(separatedBy: "\n")
        var parsedPorts: [PortInfo] = []
        var seenPorts: Set<Int> = [] // Avoid duplicates (IPv4 and IPv6 for same port)

        // Skip header line
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }

            // Split by whitespace, but be careful with variable spacing
            let components = line.split(whereSeparator: { $0.isWhitespace })
            guard components.count >= 9 else { continue }

            // lsof truncates command names and uses escape sequences like \x20 for spaces
            // We'll use the PID to get the real name later
            let lsofCommand = String(components[0])
            guard let pid = Int(components[1]) else { continue }
            let user = String(components[2])
            let type = String(components[4]) // IPv4 or IPv6

            // The NAME column contains the address:port, followed by (LISTEN)
            // Examples: "*:3000 (LISTEN)", "localhost:8080 (LISTEN)", "[::1]:5432 (LISTEN)"
            // So we need the second-to-last component
            guard components.count >= 10 else { continue }
            let name = String(components[components.count - 2])

            // Extract port number from NAME column
            guard let port = extractPort(from: name) else { continue }

            // Filter system processes if setting is disabled
            if !settings.showSystemProcesses && isSystemUser(user) {
                continue
            }

            // Skip if we've already seen this port (avoid IPv4/IPv6 duplicates)
            guard !seenPorts.contains(port) else { continue }
            seenPorts.insert(port)

            // Decode escape sequences in command name (e.g., \x20 -> space)
            let processName = decodeEscapeSequences(lsofCommand)

            parsedPorts.append(PortInfo(
                port: port,
                pid: pid,
                processName: processName,
                user: user,
                address: name,
                type: type
            ))
        }

        // Sort by port number
        return parsedPorts.sorted { $0.port < $1.port }
    }

    /// Decodes escape sequences like \x20 in lsof output
    private func decodeEscapeSequences(_ input: String) -> String {
        var result = input
        // Match \xNN patterns and replace with actual characters
        let pattern = #"\\x([0-9A-Fa-f]{2})"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()
            for match in matches {
                if let hexRange = Range(match.range(at: 1), in: result),
                   let byte = UInt8(result[hexRange], radix: 16) {
                    let char = Character(UnicodeScalar(byte))
                    let fullRange = Range(match.range, in: result)!
                    result.replaceSubrange(fullRange, with: String(char))
                }
            }
        }
        return result
    }

    /// Extracts the port number from a lsof NAME column value
    /// Examples: "*:3000" -> 3000, "[::1]:5432" -> 5432, "localhost:8080" -> 8080
    private func extractPort(from name: String) -> Int? {
        // Find the last colon and extract everything after it
        guard let colonIndex = name.lastIndex(of: ":") else { return nil }
        let portString = name[name.index(after: colonIndex)...]

        // Remove any trailing text like "(LISTEN)"
        let cleanPort = portString.prefix(while: { $0.isNumber })
        return Int(cleanPort)
    }

    /// Checks if a username is a system user
    private func isSystemUser(_ user: String) -> Bool {
        let systemUsers = ["root", "_postgres", "_mysql", "_www", "_windowserver", "_spotlight", "_mdnsresponder"]
        return user.hasPrefix("_") || systemUsers.contains(user.lowercased())
    }
}

// MARK: - Preview Support

extension PortScanner {
    /// Creates a preview instance with sample data
    static var preview: PortScanner {
        let scanner = PortScanner()
        scanner.ports = PortInfo.samples
        return scanner
    }
}
