import SwiftUI

/// A row view displaying information about a Docker container with published ports.
/// Shows the container name, image, ports, and action buttons.
struct DockerRowView: View {
    /// The Docker container to display
    let container: DockerContainer

    /// Callback when a port's browse action is triggered
    var onBrowse: (Int) -> Void = { _ in }

    /// Callback when a port's copy action is triggered
    var onCopy: (Int) -> Void = { _ in }

    /// Callback when the stop action is triggered
    var onStop: () -> Void = {}

    /// Callback when the kill action is triggered
    var onKill: () -> Void = {}

    /// Callback when the restart action is triggered
    var onRestart: () -> Void = {}

    /// Tracks hover state for showing action buttons
    @State private var isHovered = false

    /// Tracks expanded state for showing all ports
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main container row
            HStack(spacing: 12) {
                // Docker icon
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)

                // Container info
                VStack(alignment: .leading, spacing: 2) {
                    Text(container.name)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)

                    Text(container.image)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Port count badge
                if container.ports.count > 1 {
                    Button(action: { withAnimation { isExpanded.toggle() } }) {
                        HStack(spacing: 4) {
                            Text("\(container.ports.count) ports")
                                .font(.caption)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Action buttons
                if isHovered {
                    containerActionButtons
                }
            }

            // Port mappings (collapsed or expanded)
            if container.ports.count == 1 {
                // Single port - show inline
                portRow(for: container.ports[0])
            } else if isExpanded {
                // Multiple ports - show expanded list
                VStack(spacing: 4) {
                    ForEach(container.ports) { port in
                        portRow(for: port)
                    }
                }
                .padding(.leading, 32)
            } else {
                // Multiple ports - show first one with indicator
                portRow(for: container.ports[0])
                    .padding(.leading, 32)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    /// Port mapping row with actions
    private func portRow(for mapping: DockerContainer.PortMapping) -> some View {
        HStack(spacing: 8) {
            Text(mapping.displayString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            Spacer()

            // Port-specific actions
            Button(action: { onBrowse(mapping.hostPort) }) {
                Image(systemName: "safari")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help("Open in browser")

            Button(action: { onCopy(mapping.hostPort) }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy URL")
        }
    }

    /// Action buttons for the container
    private var containerActionButtons: some View {
        HStack(spacing: 4) {
            // Restart button
            Button(action: onRestart) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Restart container")

            // Stop button
            Button(action: onStop) {
                Image(systemName: "stop.circle")
                    .foregroundColor(.orange)
            }
            .buttonStyle(.plain)
            .help("Stop container")

            // Kill button
            Button(action: onKill) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Kill container")
        }
        .font(.system(size: 14))
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

// MARK: - Preview

#Preview("Docker Row") {
    VStack(spacing: 0) {
        ForEach(DockerContainer.samples) { container in
            DockerRowView(container: container)
        }
    }
    .frame(width: 360)
    .padding()
}

#Preview("Multi-port Container") {
    DockerRowView(container: DockerContainer.samples[2])
        .frame(width: 360)
        .padding()
}
