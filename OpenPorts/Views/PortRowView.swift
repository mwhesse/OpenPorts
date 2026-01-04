import SwiftUI
import AppKit

/// A row view displaying information about a single open port.
/// Clicking expands to show full process details and action buttons.
struct PortRowView: View {
    /// The port information to display
    let port: PortInfo

    /// Whether this row is expanded (controlled by parent)
    var isExpanded: Bool = false

    /// Cached command line from parent (persists across refreshes)
    var commandLine: String? = nil

    /// Whether this port is hidden
    var isHidden: Bool = false

    /// Callback to toggle expanded state
    var onToggleExpand: () -> Void = {}

    /// Callback when command line is fetched (to cache in parent)
    var onCommandLineFetched: (String) -> Void = { _ in }

    /// Callback to hide this port
    var onHide: () -> Void = {}

    /// Callback to unhide this port
    var onUnhide: () -> Void = {}

    /// Callback when the browse action is triggered
    var onBrowse: () -> Void = {}

    /// Callback when the copy action is triggered
    var onCopy: () -> Void = {}

    /// Callback when the terminate action is triggered
    var onTerminate: () -> Void = {}

    /// Callback when the kill action is triggered
    var onKill: () -> Void = {}

    /// Tracks hover state for visual feedback
    @State private var isHovered = false

    /// Loading state while fetching command line
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row - clickable to expand
            HStack(spacing: 8) {
                // App icon
                appIcon

                // Port number
                Text(String(port.port))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .frame(width: 50, alignment: .trailing)

                // Process info
                VStack(alignment: .leading, spacing: 2) {
                    Text(port.processName)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)

                    Text(port.detailDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Hide/unhide button (visible on hover)
                if isHovered {
                    Button(action: isHidden ? onUnhide : onHide) {
                        Image(systemName: isHidden ? "eye" : "eye.slash")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isHidden ? "Unhide" : "Hide")
                    .transition(.opacity)
                }

                // Expand/collapse indicator
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onToggleExpand()
                }
            }
            .onChange(of: isExpanded) { expanded in
                if expanded && commandLine == nil && !isLoading {
                    fetchCommandLine()
                }
            }
            .onAppear {
                // Fetch if view appears already expanded (e.g., after refresh)
                if isExpanded && commandLine == nil && !isLoading {
                    fetchCommandLine()
                }
            }

            // Expanded details
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isHovered || isExpanded ? Color.primary.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    /// Expanded content showing command line and actions
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Command line
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let commandLine = commandLine {
                Text(commandLine)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(3)
            } else {
                Text("Unable to get process details")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Action buttons
            HStack(spacing: 6) {
                ActionButton(title: "Open", icon: "safari", color: .accentColor, action: onBrowse)
                ActionButton(title: "Copy", icon: "doc.on.doc", color: .secondary, action: onCopy)

                Spacer()

                ActionButton(title: "Terminate", icon: "stop.circle", color: .orange, action: onTerminate)
                ActionButton(title: "Kill", icon: "xmark.circle.fill", color: .red, action: onKill)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    /// Fetches the full command line for the process
    private func fetchCommandLine() {
        isLoading = true
        Task {
            let result = await ProcessManager.getProcessCommandLine(pid: port.pid)
            await MainActor.run {
                if let cmdLine = result {
                    onCommandLineFetched(cmdLine)
                }
                isLoading = false
            }
        }
    }

    /// App icon for the process (or terminal icon for CLI apps)
    private var appIcon: some View {
        Group {
            if let app = NSRunningApplication(processIdentifier: pid_t(port.pid)),
               let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 14))
                    .frame(width: 20, height: 20)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Action Button

/// A styled button for port actions with hover effect
private struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(isHovered ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? color : color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(title)
        .fixedSize()
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview("Port Row") {
    VStack(spacing: 0) {
        ForEach(PortInfo.samples) { port in
            PortRowView(port: port)
        }
    }
    .frame(width: 320)
    .padding()
}

#Preview("Single Port Expanded") {
    PortRowView(port: PortInfo.samples[0])
        .frame(width: 320)
        .padding()
}
