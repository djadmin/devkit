import Foundation
import SwiftUI

@MainActor
final class AppRegistry: ObservableObject {
    @Published var apps: [AppEntry] = []
    @Published var statuses: [String: AppStatus] = [:]
    @Published var proxyPort: Int = 80
    @Published var dashboardHost: String = "dash"
    @Published var tld: String = "localhost"
    @Published var isReady = false
    @Published var errorMessage: String?

    // Apps currently being stopped or started.
    // Background polling skips these so it can't flip the status mid-operation.
    private var pendingOps: Set<String> = []

    private(set) var appsJSONPath: String = ""
    private var pollingTask: Task<Void, Never>?
    private var fileWatcher: DispatchSourceFileSystemObject?

    init() {
        Task { await bootstrap() }
    }

    deinit {
        pollingTask?.cancel()
        fileWatcher?.cancel()
    }

    // MARK: – Bootstrap

    func bootstrap() async {
        if let path = await DevkitCLI.appsJSONPath() {
            appsJSONPath = path
        } else {
            let fallback = NSHomeDirectory() + "/devkit/apps.json"
            if FileManager.default.fileExists(atPath: fallback) {
                appsJSONPath = fallback
            } else {
                errorMessage = "devkit not found — run: brew install devkit"
                isReady = true
                return
            }
        }
        await loadRegistry()
        isReady = true
        startPolling()
        watchFile()
    }

    // MARK: – Registry

    func loadRegistry() async {
        guard !appsJSONPath.isEmpty,
              let data = try? Data(contentsOf: URL(fileURLWithPath: appsJSONPath)),
              let reg  = try? JSONDecoder().decode(RegistryJSON.self, from: data)
        else { return }

        apps          = reg.apps
        proxyPort     = reg.proxyPort ?? 80
        dashboardHost = reg.dashboardHost ?? "dash"
        tld           = reg.tld ?? "localhost"
    }

    // MARK: – Status checks

    func checkAllStatuses() async {
        await withTaskGroup(of: (String, AppStatus).self) { group in
            for app in apps {
                // Don't let polling override an in-flight stop or start
                guard !pendingOps.contains(app.id) else { continue }

                group.addTask {
                    let status: AppStatus
                    if app.isExternallyManaged {
                        status = .external
                    } else {
                        status = await PortChecker.isReachable(port: app.port) ? .running : .stopped
                    }
                    return (app.id, status)
                }
            }
            for await (id, status) in group {
                statuses[id] = status
            }
        }
    }

    // MARK: – Polling

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.checkAllStatuses()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { break }
                await self.checkAllStatuses()
            }
        }
    }

    // MARK: – File watching

    private func watchFile() {
        fileWatcher?.cancel()
        guard !appsJSONPath.isEmpty else { return }

        let fd = open(appsJSONPath, O_EVTONLY)
        guard fd != -1 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(150))
                await self?.loadRegistry()
                self?.watchFile()
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileWatcher = source
    }

    // MARK: – Actions

    func reload() {
        Task {
            await loadRegistry()
            await checkAllStatuses()
        }
    }

    func start(_ app: AppEntry) {
        guard !pendingOps.contains(app.id) else { return }
        pendingOps.insert(app.id)
        statuses[app.id] = .checking
        errorMessage = nil

        Task {
            defer { pendingOps.remove(app.id) }

            let result = await DevkitCLI.start(app.name)
            guard result.exitCode == 0 else {
                statuses[app.id] = .stopped
                errorMessage = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                return
            }

            // Poll until the port responds (up to 6s)
            for _ in 0..<10 {
                try? await Task.sleep(for: .milliseconds(600))
                if await PortChecker.isReachable(port: app.port) {
                    statuses[app.id] = .running
                    return
                }
            }
            statuses[app.id] = .stopped
        }
    }

    func stop(_ app: AppEntry) {
        guard !pendingOps.contains(app.id) else { return }
        pendingOps.insert(app.id)
        statuses[app.id] = .checking
        errorMessage = nil

        Task {
            defer { pendingOps.remove(app.id) }

            let result = await DevkitCLI.stop(app.name)
            guard result.exitCode == 0 else {
                let stillUp = await PortChecker.isReachable(port: app.port)
                statuses[app.id] = stillUp ? .running : .stopped
                errorMessage = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                return
            }

            // Verify: poll until port is actually closed (up to 6s)
            for _ in 0..<12 {
                try? await Task.sleep(for: .milliseconds(500))
                if !(await PortChecker.isReachable(port: app.port)) {
                    statuses[app.id] = .stopped
                    return
                }
            }

            // Port is still open after 6s — let polling decide the real status.
            let stillUp = await PortChecker.isReachable(port: app.port)
            statuses[app.id] = stillUp ? .running : .stopped
        }
    }

    // MARK: – Derived

    func status(for app: AppEntry) -> AppStatus { statuses[app.id] ?? .checking }

    func url(for app: AppEntry) -> URL {
        let suffix = proxyPort == 80 ? "" : ":\(proxyPort)"
        return URL(string: "http://\(app.hostname)\(suffix)")!
    }

    var dashboardURL: URL {
        let suffix = proxyPort == 80 ? "" : ":\(proxyPort)"
        return URL(string: "http://\(dashboardHost).\(tld)\(suffix)")!
    }

    var runningCount: Int { apps.filter { status(for: $0) == .running }.count }
}
