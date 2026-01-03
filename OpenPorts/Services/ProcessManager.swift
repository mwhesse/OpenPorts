import Foundation

/// Service responsible for terminating and killing processes.
/// Provides both graceful termination (SIGTERM) and forceful kill (SIGKILL).
enum ProcessManager {

    /// Result of a process management operation
    enum Result {
        case success
        case failure(String)

        var succeeded: Bool {
            if case .success = self { return true }
            return false
        }

        var errorMessage: String? {
            if case let .failure(message) = self { return message }
            return nil
        }
    }

    /// Sends SIGTERM to a process, allowing it to clean up gracefully.
    /// This is the preferred way to stop a process.
    /// - Parameter pid: The process ID to terminate
    /// - Returns: Result indicating success or failure
    static func terminate(pid: Int) async -> Result {
        await sendSignal(to: pid, signal: "TERM", description: "terminate")
    }

    /// Sends SIGKILL to a process, forcefully stopping it immediately.
    /// Use this when SIGTERM doesn't work or the process is unresponsive.
    /// - Parameter pid: The process ID to kill
    /// - Returns: Result indicating success or failure
    static func kill(pid: Int) async -> Result {
        await sendSignal(to: pid, signal: "KILL", description: "kill")
    }

    /// Sends a signal to a process.
    /// - Parameters:
    ///   - pid: The process ID
    ///   - signal: The signal name (e.g., "TERM", "KILL")
    ///   - description: Human-readable description for error messages
    /// - Returns: Result indicating success or failure
    private static func sendSignal(to pid: Int, signal: String, description: String) async -> Result {
        // Validate PID
        guard pid > 0 else {
            return .failure("Invalid process ID: \(pid)")
        }

        // Use the kill command to send the signal
        let command = "kill -\(signal) \(pid)"
        let result = await ShellExecutor.execute(command)

        if result.succeeded {
            return .success
        } else {
            // Parse common error messages
            if result.error.contains("No such process") {
                return .failure("Process \(pid) no longer exists")
            } else if result.error.contains("Operation not permitted") {
                return .failure("Permission denied. Cannot \(description) process \(pid)")
            } else {
                return .failure(result.error.isEmpty ? "Failed to \(description) process \(pid)" : result.error)
            }
        }
    }

    /// Checks if a process is still running.
    /// - Parameter pid: The process ID to check
    /// - Returns: True if the process exists, false otherwise
    static func isProcessRunning(pid: Int) async -> Bool {
        guard pid > 0 else { return false }

        // Using kill -0 to check if process exists without sending a signal
        let result = await ShellExecutor.execute("kill -0 \(pid) 2>/dev/null")
        return result.exitCode == 0
    }

    /// Gets the name of a process by its PID.
    /// - Parameter pid: The process ID
    /// - Returns: The process name, or nil if not found
    static func getProcessName(pid: Int) async -> String? {
        guard pid > 0 else { return nil }

        let result = await ShellExecutor.execute("ps -p \(pid) -o comm= 2>/dev/null")
        guard result.succeeded, !result.output.isEmpty else { return nil }

        return result.output
    }

    /// Gets the full command line of a process (path + arguments).
    /// - Parameter pid: The process ID
    /// - Returns: The full command line, or nil if not found
    static func getProcessCommandLine(pid: Int) async -> String? {
        guard pid > 0 else { return nil }

        let result = await ShellExecutor.execute("ps -p \(pid) -o args= 2>/dev/null")
        guard result.succeeded, !result.output.isEmpty else { return nil }

        return result.output
    }
}
