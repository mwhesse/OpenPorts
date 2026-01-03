import Foundation

/// A utility for executing shell commands and capturing their output.
/// This is used throughout the app to run system commands like `lsof` and `docker`.
enum ShellExecutor {

    /// Result of a shell command execution
    struct CommandResult {
        let output: String
        let error: String
        let exitCode: Int32

        var succeeded: Bool { exitCode == 0 }
    }

    /// Executes a shell command and returns the result.
    /// - Parameters:
    ///   - command: The command to execute (e.g., "lsof -iTCP")
    ///   - timeout: Optional timeout in seconds (default: 10)
    /// - Returns: CommandResult containing stdout, stderr, and exit code
    @discardableResult
    static func execute(_ command: String, timeout: TimeInterval = 10) async -> CommandResult {
        await withCheckedContinuation { continuation in
            let task = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            // Use /bin/zsh as the shell (default on modern macOS)
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments = ["-c", command]
            task.standardOutput = outputPipe
            task.standardError = errorPipe

            // Set up environment to include common paths
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
            task.environment = environment

            do {
                try task.run()

                // Set up timeout
                let timeoutWorkItem = DispatchWorkItem {
                    if task.isRunning {
                        task.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)

                task.waitUntilExit()
                timeoutWorkItem.cancel()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""

                continuation.resume(returning: CommandResult(
                    output: output.trimmingCharacters(in: .whitespacesAndNewlines),
                    error: error.trimmingCharacters(in: .whitespacesAndNewlines),
                    exitCode: task.terminationStatus
                ))
            } catch {
                continuation.resume(returning: CommandResult(
                    output: "",
                    error: error.localizedDescription,
                    exitCode: -1
                ))
            }
        }
    }

    /// Executes a command synchronously (for use in non-async contexts).
    /// Prefer the async version when possible.
    @discardableResult
    static func executeSync(_ command: String, timeout: TimeInterval = 10) -> CommandResult {
        let semaphore = DispatchSemaphore(value: 0)
        var result: CommandResult?

        Task {
            result = await execute(command, timeout: timeout)
            semaphore.signal()
        }

        semaphore.wait()
        return result ?? CommandResult(output: "", error: "Execution failed", exitCode: -1)
    }
}
