import SwiftUI

// MARK: – Root

struct OnboardingView: View {
    @EnvironmentObject var registry: AppRegistry

    @State private var phase: Phase = .scanning
    @State private var foundPorts: [Int] = []

    enum Phase { case scanning, found, setup }

    var body: some View {
        Group {
            switch phase {
            case .scanning: scanningView
            case .found:    FoundPortsView(ports: foundPorts, onSkip: { phase = .setup })
            case .setup:    ClaudeSetupView()
            }
        }
        .task { await scan() }
    }

    // MARK: Scanning

    private var scanningView: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Looking for running apps…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func scan() async {
        let registered = Set(registry.apps.map(\.port))
        let found = await PortScanner.scan(excluding: registered)
        withAnimation(.easeOut(duration: 0.2)) {
            foundPorts = found
            phase = found.isEmpty ? .setup : .found
        }
    }
}

// MARK: – Found ports

private struct FoundPortsView: View {
    @EnvironmentObject var registry: AppRegistry
    let ports: [Int]
    let onSkip: () -> Void

    @State private var names: [Int: String] = [:]
    @State private var tracked: Set<Int> = []
    @State private var busy = false

    private var allTracked: Bool { ports.allSatisfy { tracked.contains($0) } }
    private var untracked: [Int] { ports.filter { !tracked.contains($0) } }

    var body: some View {
        VStack(spacing: 0) {
            // Banner
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color(hex: "f59e0b"))
                    .imageScale(.small)
                Text("Found \(ports.count) app\(ports.count == 1 ? "" : "s") running")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if !allTracked {
                    Button {
                        Task { await trackAll() }
                    } label: {
                        Text("Track All")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(hex: "22c55e"))
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Port rows
            ForEach(ports, id: \.self) { port in
                PortRow(
                    port: port,
                    name: binding(for: port),
                    isTracked: tracked.contains(port)
                ) {
                    Task { await track(port: port) }
                }
                if port != ports.last {
                    Divider().padding(.leading, 16)
                }
            }

            // Footer
            Divider()
            Button(action: onSkip) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                    Text("Set up with Claude Code instead")
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
    }

    private func binding(for port: Int) -> Binding<String> {
        Binding(get: { names[port] ?? "" }, set: { names[port] = $0 })
    }

    private func track(port: Int) async {
        let name = names[port]?.trimmingCharacters(in: .whitespaces)
        let slug = (name?.isEmpty == false ? name! : "app-\(port)")
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        await DevkitCLI.run("register --name \(slug) --port \(port) --managed-by external")
        tracked.insert(port)
        registry.reload()
    }

    private func trackAll() async {
        busy = true
        for port in untracked { await track(port: port) }
        busy = false
    }
}

// MARK: – Single port row

private struct PortRow: View {
    let port: Int
    @Binding var name: String
    let isTracked: Bool
    let onTrack: () -> Void

    @State private var hovered = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Status dot
            Circle()
                .fill(isTracked ? Color(hex: "a78bfa") : Color(hex: "22c55e"))
                .frame(width: 7, height: 7)
                .shadow(color: Color(hex: "22c55e").opacity(isTracked ? 0 : 0.5), radius: 4)

            // Port label
            Text(":\(port)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)

            if isTracked {
                Text(name.isEmpty ? "app-\(port)" : name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "checkmark")
                    .imageScale(.small)
                    .foregroundStyle(Color(hex: "a78bfa"))
            } else {
                TextField("name this app", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($focused)
                    .onSubmit { if !name.isEmpty { onTrack() } }

                Spacer()

                Button("Track") { onTrack() }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(hovered ? Color(hex: "22c55e") : Color(hex: "22c55e").opacity(0.6))
                    .buttonStyle(.plain)
                    .onHover { hovered = $0 }
                    .animation(.easeOut(duration: 0.1), value: hovered)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .animation(.easeOut(duration: 0.2), value: isTracked)
    }
}

// MARK: – Claude setup card

private struct ClaudeSetupView: View {
    @State private var copied = false

    private let snippet = """
    ## Local Web Apps — devkit
    When building any local web app, register it with devkit:
      devkit register --name <slug> --path <abs-path> --port <port> --cmd "<start-cmd>"
      devkit start <slug>
    Apps are then reachable at http://<slug>.localhost
    """

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("Wire up Claude Code")
                    .font(.system(size: 13, weight: .semibold))
                Text("Every app Claude builds will appear here automatically.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Steps
            VStack(alignment: .leading, spacing: 12) {
                StepRow(n: "1", text: "Add this snippet to")
                    + StepRow(n: "", text: "~/.claude/CLAUDE.md")

                // Snippet block
                ZStack(alignment: .topTrailing) {
                    Text(snippet)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(snippet, forType: .string)
                        withAnimation(.easeOut(duration: 0.15)) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .imageScale(.small)
                            .foregroundStyle(copied ? Color(hex: "22c55e") : Color.secondary)
                            .frame(width: 26, height: 26)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }

                StepRow(n: "2", text: "Ask Claude to build a web app")
                StepRow(n: "3", text: "It registers itself and appears here ✦")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            // Manual register hint
            Text("Or run devkit register … to add an app manually")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
        }
    }
}

// MARK: – Helpers

private struct StepRow: View {
    let n: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if n.isEmpty {
                Spacer().frame(width: 16)
            } else {
                Text(n)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.accentColor.opacity(0.8), in: Circle())
            }
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(n.isEmpty ? Color.secondary.opacity(0.7) : Color.primary.opacity(0.85))
        }
    }

    // Allow `+` concatenation for multi-part rows
    static func + (lhs: StepRow, rhs: StepRow) -> some View {
        VStack(alignment: .leading, spacing: 2) { lhs; rhs }
    }
}
