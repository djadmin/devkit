import SwiftUI

struct DiscoveredPort: Identifiable {
    let id = UUID()
    let port: Int
    var processName: String
    var proposedName: String
    var isImporting = false
    var imported = false
}

struct DiscoverView: View {
    @EnvironmentObject var registry: AppRegistry
    @State private var discovered: [DiscoveredPort] = []
    @State private var isScanning = false
    @State private var hasScanned = false

    private var unregisteredPorts: [DiscoveredPort] {
        let registered = Set(registry.apps.map(\.port))
        return discovered.filter { !registered.contains($0.port) && !$0.imported }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header area
            VStack(alignment: .leading, spacing: 6) {
                Text("Discover running services")
                    .font(.title2).fontWeight(.semibold)
                Text("Scan for local processes listening on TCP ports that aren't yet registered in devkit.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .padding(.bottom, 4)

            Divider()

            if isScanning {
                scanningState
            } else if !hasScanned {
                notYetScanned
            } else if unregisteredPorts.isEmpty {
                allCoveredState
            } else {
                portList
            }
        }
        .navigationTitle("Discover")
    }

    // MARK: – States

    private var notYetScanned: some View {
        VStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Scan for running services")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("devkit will check common development ports and show any running process not yet registered.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button("Scan now") { Task { await scan() } }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanningState: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Scanning ports…")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var allCoveredState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: "22c55e"))
            Text("All running services are registered")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("Scan again") { Task { await scan() } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var portList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(unregisteredPorts.count) service\(unregisteredPorts.count == 1 ? "" : "s") found")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { Task { await scan() } } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                        Text("Scan again")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            List($discovered) { $port in
                if !port.imported && !registry.apps.map(\.port).contains(port.port) {
                    PortImportRow(port: $port)
                        .environmentObject(registry)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .listStyle(.plain)

            Divider()

            Text("\(registry.apps.count) already registered · excluded from scan")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
        }
    }

    // MARK: – Scan

    private func scan() async {
        isScanning = true
        hasScanned = false
        let registered = Set(registry.apps.map(\.port))
        let found = await PortScanner.scan(excluding: registered)

        var ports: [DiscoveredPort] = []
        for port in found {
            let procName = await processName(for: port) ?? "unknown"
            let proposed = suggestName(processName: procName, port: port)
            ports.append(DiscoveredPort(port: port, processName: procName, proposedName: proposed))
        }

        await MainActor.run {
            discovered = ports
            isScanning = false
            hasScanned = true
        }
    }

    private func processName(for port: Int) async -> String? {
        await withCheckedContinuation { cont in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            task.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-F", "cn"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError  = Pipe()
            task.terminationHandler = { _ in
                let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                // lsof -F cn outputs lines like "c<name>" and "n<addr>:<port>"
                let name = raw.components(separatedBy: "\n")
                    .first(where: { $0.hasPrefix("c") })
                    .map { String($0.dropFirst()) }
                cont.resume(returning: name)
            }
            try? task.run()
        }
    }

    private func suggestName(processName: String, port: Int) -> String {
        let lc = processName.lowercased()
        if lc.contains("node")  { return "node-\(port)" }
        if lc.contains("python") { return "python-\(port)" }
        if lc.contains("ruby")  { return "ruby-\(port)" }
        if lc.contains("java")  { return "java-\(port)" }
        if lc.contains("go")    { return "go-\(port)" }
        if lc.contains("cargo") { return "rust-\(port)" }
        if lc.contains("php")   { return "php-\(port)" }
        return "\(processName.lowercased().replacingOccurrences(of: " ", with: "-"))-\(port)"
    }
}

// MARK: – Port import row

private struct PortImportRow: View {
    @EnvironmentObject var registry: AppRegistry
    @Binding var port: DiscoveredPort

    var body: some View {
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(Color(hex: "22c55e"))
                .frame(width: 7, height: 7)
                .shadow(color: Color(hex: "22c55e").opacity(0.5), radius: 4)

            // Port badge
            Text(verbatim: ":\(port.port)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            // Process name
            Text(port.processName)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .frame(width: 90, alignment: .leading)
                .lineLimit(1)

            // Name field
            TextField("name this service…", text: $port.proposedName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            // Import button
            Button {
                Task { await importPort() }
            } label: {
                if port.isImporting {
                    ProgressView().controlSize(.mini).frame(width: 60)
                } else {
                    Text("Import")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 60)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(port.proposedName.trimmingCharacters(in: .whitespaces).isEmpty || port.isImporting)
        }
    }

    private func importPort() async {
        let name = port.proposedName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        port.isImporting = true
        let result = await DevkitCLI.run([
            "register", name,
            "--port", "\(port.port)",
            "--managed-by", "external"
        ])

        await MainActor.run {
            port.isImporting = false
            if result.exitCode == 0 {
                port.imported = true
                registry.reload()
            }
        }
    }
}
