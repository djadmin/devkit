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
            Text("Looking for local apps already running…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    @MainActor
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

    @State private var extraPorts: [Int] = []
    @State private var names: [Int: String] = [:]
    @State private var cmds: [Int: String] = [:]
    @State private var tracked: Set<Int> = []
    @State private var tracking: Set<Int> = []
    @State private var busy = false
    @State private var manualPort = ""
    @State private var checkingManual = false
    @State private var manualError: String? = nil

    private var allPorts: [Int] { (ports + extraPorts).sorted() }
    private var allTracked: Bool { allPorts.allSatisfy { tracked.contains($0) } }
    private var untracked: [Int] { allPorts.filter { !tracked.contains($0) } }

    var body: some View {
        VStack(spacing: 0) {
            // Banner
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color(hex: "f59e0b"))
                        .imageScale(.small)
                    Text("Found \(allPorts.count) running app\(allPorts.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    if !allTracked {
                        Button {
                            Task { await trackAll() }
                        } label: {
                            Text(busy ? "Tracking…" : "Track All")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(hex: "22c55e"))
                        }
                        .buttonStyle(.plain)
                        .disabled(busy || !tracking.isEmpty)
                    }
                }
                Text("Name each app and optionally add its start command so devkit can restart it later.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Port rows
            ForEach(allPorts, id: \.self) { port in
                PortRow(
                    port: port,
                    name: nameBinding(for: port),
                    cmd: cmdBinding(for: port),
                    isTracked: tracked.contains(port),
                    isBusy: busy || tracking.contains(port)
                ) {
                    Task { await track(port: port) }
                }
                Divider().padding(.leading, 16)
            }

            // Manual port input
            manualPortRow

            // Footer
            Divider()
            Button(action: onSkip) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                    Text("Make future apps auto-register")
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
    }

    // MARK: – Manual port row

    private var manualPortRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)

                TextField("add port…", text: $manualPort)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 56)
                    .onSubmit { Task { await addManualPort() } }
                    .onChange(of: manualPort) { _, _ in manualError = nil }

                if checkingManual {
                    ProgressView().controlSize(.mini)
                } else {
                    Button("Add") { Task { await addManualPort() } }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(manualPort.isEmpty ? Color.secondary.opacity(0.3) : Color.secondary)
                        .buttonStyle(.plain)
                        .disabled(manualPort.isEmpty)
                }

                if let err = manualError {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "ef4444"))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: – Bindings

    private func nameBinding(for port: Int) -> Binding<String> {
        Binding(get: { names[port] ?? "" }, set: { names[port] = $0 })
    }

    private func cmdBinding(for port: Int) -> Binding<String> {
        Binding(get: { cmds[port] ?? "" }, set: { cmds[port] = $0 })
    }

    // MARK: – Actions

    @MainActor
    private func addManualPort() async {
        let raw = manualPort.trimmingCharacters(in: .whitespaces)
        guard let port = Int(raw), port > 0, port < 65536 else {
            manualError = "invalid port"
            return
        }
        guard !allPorts.contains(port) else {
            manualError = "already listed"
            return
        }
        checkingManual = true
        manualError = nil
        defer { checkingManual = false }

        let reachable = await PortChecker.isReachable(port: port)
        guard reachable else {
            manualError = "nothing on :\(port)"
            return
        }
        withAnimation(.easeOut(duration: 0.15)) {
            extraPorts.append(port)
            manualPort = ""
        }
    }

    @MainActor
    private func track(port: Int) async {
        let name = names[port]?.trimmingCharacters(in: .whitespaces)
        let raw = (name?.isEmpty == false ? name! : "app-\(port)")
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        let slug = raw.replacingOccurrences(of: #"[^a-z0-9\-]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let safeName = slug.isEmpty ? "app-\(port)" : slug
        guard !tracking.contains(port) else { return }

        tracking.insert(port)
        registry.errorMessage = nil
        defer { tracking.remove(port) }

        let cmdText = cmds[port]?.trimmingCharacters(in: .whitespaces) ?? ""
        let result: DevkitCLI.Result
        if cmdText.isEmpty {
            result = await DevkitCLI.run(["register", safeName, "--port", String(port), "--managed-by", "external"])
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            result = await DevkitCLI.run(["register", safeName, "--port", String(port), "--cmd", cmdText, "--path", home])
        }

        guard result.exitCode == 0 else {
            let message = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            registry.errorMessage = message.isEmpty ? "Could not track app on port \(port)" : message
            return
        }

        names[port] = safeName
        tracked.insert(port)
        registry.reload()
    }

    @MainActor
    private func trackAll() async {
        busy = true
        defer { busy = false }
        for port in untracked {
            await track(port: port)
            if registry.errorMessage != nil { break }
        }
    }
}

// MARK: – Single port row

private struct PortRow: View {
    let port: Int
    @Binding var name: String
    @Binding var cmd: String
    let isTracked: Bool
    let isBusy: Bool
    let onTrack: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var hovered = false
    @State private var peekHovered = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 10) {
                // Status dot
                Circle()
                    .fill(isTracked ? Color(hex: "a78bfa") : Color(hex: "22c55e"))
                    .frame(width: 7, height: 7)
                    .shadow(color: Color(hex: "22c55e").opacity(isTracked ? 0 : 0.5), radius: 4)

                // Port label + peek
                HStack(spacing: 3) {
                    Text(verbatim: ":\(port)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Button {
                        if let url = URL(string: "http://localhost:\(port)") { openURL(url) }
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .imageScale(.small)
                            .foregroundStyle(peekHovered ? Color.accentColor : Color.secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .onHover { peekHovered = $0 }
                    .help("Open in browser to see what's running")
                }
                .frame(width: 70, alignment: .leading)

                if isTracked {
                    Text(name.isEmpty ? "app-\(port)" : name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: cmd.isEmpty ? "checkmark" : "checkmark.circle.fill")
                        .imageScale(.small)
                        .foregroundStyle(Color(hex: "a78bfa"))
                        .help(cmd.isEmpty ? "Tracked as external" : "devkit can start/stop this app")
                } else {
                    TextField("name this app", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($nameFocused)
                        .disabled(isBusy)
                        .onSubmit { if !name.isEmpty && !isBusy { onTrack() } }

                    Spacer()

                    Button(isBusy ? "Tracking…" : "Track") { onTrack() }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(hovered ? Color(hex: "22c55e") : Color(hex: "22c55e").opacity(0.6))
                        .buttonStyle(.plain)
                        .disabled(isBusy)
                        .onHover { hovered = $0 }
                        .animation(.easeOut(duration: 0.1), value: hovered)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)

            // Cmd row — shown only when not yet tracked
            if !isTracked {
                HStack(spacing: 0) {
                    // Indent to align with the name field
                    Spacer().frame(width: 97)
                    TextField("start cmd (optional, enables restart)", text: $cmd)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .disabled(isBusy)
                        .onSubmit { if !name.isEmpty && !isBusy { onTrack() } }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isTracked)
    }
}

// MARK: – Agent setup card

private struct AgentConfig {
    let name: String
    let icon: String
    let configFile: String
    let snippet: String
    let step2: String
}

private let agentConfigs: [AgentConfig] = [
    AgentConfig(
        name: "Claude",
        icon: "c.circle.fill",
        configFile: "~/.claude/CLAUDE.md",
        snippet: """
        ## Local Web Apps — devkit
        After creating any local web app or service:
          devkit register <slug> --port <port> --cmd "<start-cmd>"
          devkit start <slug>
        The app should be reachable at http://<slug>.localhost
        """,
        step2: "Ask Claude to build a local app"
    ),
    AgentConfig(
        name: "Cursor",
        icon: "cursorarrow.click",
        configFile: ".cursor/rules/devkit.mdc",
        snippet: """
        ---
        description: Register new local apps with devkit
        alwaysApply: true
        ---

        After creating any local web app or service:
        - run `devkit register <slug> --port <port> --cmd "<start-cmd>"`
        - run `devkit start <slug>`
        - skip if `devkit` is not installed
        """,
        step2: "Ask Cursor to build a local app"
    ),
    AgentConfig(
        name: "Codex",
        icon: "terminal.fill",
        configFile: "~/.codex/AGENTS.md",
        snippet: """
        ## Local Web Apps — devkit
        After creating any local web app or service:
          run `devkit register <slug> --port <port> --cmd "<start-cmd>"`
          run `devkit start <slug>`
        Use lowercase-hyphenated slugs. Skip if `devkit` is not installed.
        """,
        step2: "Ask Codex to build a local app"
    ),
    AgentConfig(
        name: "Copilot",
        icon: "person.circle.fill",
        configFile: ".github/copilot-instructions.md",
        snippet: """
        ## Local Web Apps — devkit
        After creating any local web app or service:
        - run `devkit register <slug> --port <port> --cmd "<start-cmd>"`
        - run `devkit start <slug>`
        - use a lowercase-hyphenated slug
        """,
        step2: "Ask Copilot to build a local app"
    ),
    AgentConfig(
        name: "Windsurf",
        icon: "wind",
        configFile: ".windsurfrules",
        snippet: """
        ## Local Web Apps — devkit
        After creating any local web app or service:
        - run devkit register <slug> --port <port> --cmd "<start-cmd>"
        - run devkit start <slug>
        - use a lowercase-hyphenated slug
        - skip if devkit is not installed
        """,
        step2: "Ask Windsurf to build a local app"
    ),
]

private struct ClaudeSetupView: View {
    @State private var selectedAgent = 0
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("Make future apps show up automatically")
                    .font(.system(size: 13, weight: .semibold))
                Text("One global rule. New apps your agent builds get a name, URL, and place here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Agent tabs
            HStack(spacing: 0) {
                ForEach(agentConfigs.indices, id: \.self) { i in
                    let agent = agentConfigs[i]
                    Button {
                        withAnimation(.easeOut(duration: 0.12)) {
                            if selectedAgent != i { copied = false }
                            selectedAgent = i
                        }
                    } label: {
                        Text(agent.name)
                            .font(.system(size: 11, weight: selectedAgent == i ? .semibold : .regular))
                            .foregroundStyle(selectedAgent == i ? Color.primary : Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                selectedAgent == i
                                    ? Color.primary.opacity(0.07)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Steps
            let agent = agentConfigs[selectedAgent]
            VStack(alignment: .leading, spacing: 12) {
                StepRow(n: "1", text: "Add this snippet to")
                    + StepRow(n: "", text: agent.configFile)

                // Snippet block
                ZStack(alignment: .topTrailing) {
                    Text(agent.snippet)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(agent.snippet, forType: .string)
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

                StepRow(n: "2", text: agent.step2)
                StepRow(n: "3", text: "It registers itself and appears here with a .localhost URL")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            // Manual register hint
            Text("Already have apps running? Track them above, or run devkit register … manually.")
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

    static func + (lhs: StepRow, rhs: StepRow) -> some View {
        VStack(alignment: .leading, spacing: 2) { lhs; rhs }
    }
}
