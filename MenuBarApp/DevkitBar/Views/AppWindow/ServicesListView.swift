import SwiftUI

struct ServicesListView: View {
    @EnvironmentObject var registry: AppRegistry
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var hoveredApp: String? = nil

    private var filtered: [AppEntry] {
        guard !searchText.isEmpty else { return registry.apps }
        let q = searchText.lowercased()
        return registry.apps.filter {
            $0.name.lowercased().contains(q) || $0.hostname.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            statsBar
            Divider()
            if registry.apps.isEmpty {
                emptyState
            } else {
                serviceList
            }
        }
        .searchable(text: $searchText, prompt: "Filter services…")
        .navigationTitle("Services")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                }
                .help("Register a new service")
            }
            ToolbarItem {
                Button { registry.reload() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Reload registry  ⌘R")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddServiceSheet()
                .environmentObject(registry)
        }
    }

    // MARK: – Stats bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            StatCell(value: registry.runningCount, label: "Running",   color: Color(hex: "22c55e"))
            Divider().frame(height: 32)
            StatCell(value: stoppedCount,          label: "Stopped",   color: Color(hex: "ef4444"))
            Divider().frame(height: 32)
            StatCell(value: registry.apps.count,   label: "Registered", color: .secondary)
            Spacer()
            if !registry.apps.filter({ !$0.isExternallyManaged }).isEmpty {
                HStack(spacing: 8) {
                    Button("Start All") { registry.apps.filter { !$0.isExternallyManaged }.forEach { registry.start($0) } }
                        .buttonStyle(.link)
                        .foregroundStyle(Color(hex: "22c55e"))
                    Button("Stop All")  { registry.apps.filter { !$0.isExternallyManaged }.forEach { registry.stop($0) } }
                        .buttonStyle(.link)
                        .foregroundStyle(Color(hex: "ef4444"))
                }
                .font(.system(size: 12))
                .padding(.trailing, 16)
            }
        }
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var stoppedCount: Int {
        registry.apps.filter { registry.status(for: $0) == .stopped }.count
    }

    // MARK: – List

    private var serviceList: some View {
        List {
            ForEach(filtered) { app in
                ServiceRow(app: app, isHovered: hoveredApp == app.id)
                    .onHover { hoveredApp = $0 ? app.id : nil }
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
        }
        .listStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: filtered.map(\.id))
    }

    // MARK: – Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No services registered")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Register your first app or use **Discover** to import running services.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            Button("Register a service") { showAddSheet = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: – Stat cell

private struct StatCell: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .center, spacing: 1) {
            Text("\(value)")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(width: 80)
    }
}

// MARK: – Service row

private struct ServiceRow: View {
    @EnvironmentObject var registry: AppRegistry
    let app: AppEntry
    let isHovered: Bool

    private var status: AppStatus { registry.status(for: app) }

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            AppIcon(name: app.name, status: status)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 14, weight: .medium))
                    statusBadge
                }
                HStack(spacing: 4) {
                    Text(app.hostname)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if app.port != 80, app.port != 443, app.port > 0 {
                        Text(verbatim: ":\(app.port)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                if let desc = appDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 4) {
                ActionBtn(icon: "doc.on.doc", help: "Copy URL") { copyURL() }
                ActionBtn(icon: "arrow.up.right.square", help: "Open in browser") { open() }
                if !app.isExternallyManaged {
                    toggleButton
                }
            }
            .opacity(isHovered ? 1 : 0.4)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { open() }
    }

    private var appDescription: String? { app.description.isEmpty ? nil : app.description }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.dotColor)
                .frame(width: 6, height: 6)
                .shadow(color: status == .running ? status.dotColor.opacity(0.6) : .clear, radius: 3)
            Text(statusLabel)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var statusLabel: String {
        switch status {
        case .running:  return "running"
        case .stopped:  return "stopped"
        case .external: return "external"
        case .checking: return "checking…"
        }
    }

    @ViewBuilder
    private var toggleButton: some View {
        switch status {
        case .checking:
            ProgressView().controlSize(.mini).frame(width: 28, height: 28)
        case .running:
            ActionBtn(icon: "stop.circle.fill", tint: Color(hex: "ef4444"), help: "Stop") {
                registry.stop(app)
            }
        default:
            ActionBtn(icon: "play.circle.fill", tint: Color(hex: "22c55e"), help: "Start") {
                registry.start(app)
            }
        }
    }

    private func open() {
        NSWorkspace.shared.open(registry.url(for: app))
    }

    private func copyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(registry.url(for: app).absoluteString, forType: .string)
    }
}

// MARK: – App icon

private struct AppIcon: View {
    let name: String
    let status: AppStatus

    private var color: Color {
        let colors: [Color] = [
            Color(hex: "6366f1"), Color(hex: "0ea5e9"), Color(hex: "f59e0b"),
            Color(hex: "8b5cf6"), Color(hex: "22c55e"), Color(hex: "06b6d4"),
            Color(hex: "f97316"), Color(hex: "ec4899"), Color(hex: "14b8a6"),
        ]
        let idx = abs(name.hashValue) % colors.count
        return colors[idx]
    }

    private var initials: String {
        let parts = name.split(separator: "-")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))
                .frame(width: 36, height: 36)
            Text(initials)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)

            // Status dot
            if status != .checking {
                Circle()
                    .fill(status.dotColor)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                    .shadow(color: status == .running ? status.dotColor.opacity(0.5) : .clear, radius: 3)
                    .offset(x: 2, y: 2)
            }
        }
    }
}

// MARK: – Action button

private struct ActionBtn: View {
    let icon: String
    var tint: Color = .secondary
    let help: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .imageScale(.medium)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(hovered ? tint.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovered = $0 }
    }
}

// MARK: – Add service sheet

struct AddServiceSheet: View {
    @EnvironmentObject var registry: AppRegistry
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var port = ""
    @State private var cmd  = ""
    @State private var path = ""
    @State private var errorMsg = ""
    @State private var isRegistering = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(port) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Register a service")
                .font(.title2).fontWeight(.semibold)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text("Name").gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                    TextField("my-api", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .help("Lowercase, hyphenated — becomes the .localhost subdomain")
                }
                GridRow {
                    Text("Port").gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                    TextField("3000", text: $port)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                GridRow {
                    Text("Start command").gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                    TextField("npm run dev", text: $cmd)
                        .textFieldStyle(.roundedBorder)
                        .help("How to start this service (optional if external)")
                }
                GridRow {
                    Text("Path").gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                    HStack {
                        TextField("defaults to current directory", text: $path)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse…") { choosePath() }
                    }
                }
            }

            if !errorMsg.isEmpty {
                Text(errorMsg)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Register") { register() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid || isRegistering)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private func choosePath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }

    private func register() {
        guard let portNum = Int(port) else { return }
        isRegistering = true
        errorMsg = ""

        let appEntry = AppEntry(
            name: name.trimmingCharacters(in: .whitespaces),
            hostname: "\(name.trimmingCharacters(in: .whitespaces)).localhost",
            port: portNum,
            path: path.isEmpty ? nil : path,
            repo: nil, claudeMd: nil,
            startCmd: cmd.isEmpty ? nil : cmd,
            description: "",
            managedBy: cmd.isEmpty ? "external" : "devkit"
        )
        _ = appEntry  // used below via CLI

        Task {
            var args = ["register", name.trimmingCharacters(in: .whitespaces),
                        "--port", port]
            if !cmd.isEmpty  { args += ["--cmd", cmd] }
            if !path.isEmpty { args += ["--path", path] }

            let result = await DevkitCLI.run(args)
            await MainActor.run {
                isRegistering = false
                if result.exitCode == 0 {
                    registry.reload()
                    dismiss()
                } else {
                    errorMsg = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
    }
}
