import SwiftUI

struct LogsView: View {
    @EnvironmentObject var registry: AppRegistry
    @State private var selectedApp: AppEntry? = nil
    @State private var logContent = ""
    @State private var isLoading = false
    @State private var timer: Timer? = nil

    private var loggableApps: [AppEntry] {
        registry.apps.filter { !$0.isExternallyManaged }
    }

    var body: some View {
        HSplitView {
            // App picker
            List(loggableApps, selection: $selectedApp) { app in
                HStack(spacing: 8) {
                    Circle()
                        .fill(registry.status(for: app).dotColor)
                        .frame(width: 7, height: 7)
                    Text(app.name)
                        .font(.system(size: 13))
                    Spacer()
                }
                .tag(app)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 140, idealWidth: 160, maxWidth: 200)

            // Log content
            VStack(spacing: 0) {
                if let app = selectedApp {
                    logHeader(for: app)
                    Divider()
                    logText
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("Select a service to view its logs")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("Logs")
        .onChange(of: selectedApp) { app in
            loadLogs(for: app)
        }
        .onDisappear { timer?.invalidate() }
    }

    private func logHeader(for app: AppEntry) -> some View {
        HStack {
            Text(app.name).font(.system(size: 13, weight: .medium))
            Spacer()
            Button { loadLogs(for: app) } label: {
                Image(systemName: "arrow.clockwise").imageScale(.small)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private var logText: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(logContent.isEmpty ? "No logs yet." : logContent)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(logContent.isEmpty ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .id("bottom")
            }
            .onChange(of: logContent) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func loadLogs(for app: AppEntry?) {
        timer?.invalidate()
        guard let app else { logContent = ""; return }

        let home = NSHomeDirectory()
        let logPath = "\(home)/devkit/logs/\(app.name).log"

        func read() {
            logContent = (try? String(contentsOfFile: logPath, encoding: .utf8)) ?? "No log file found at \(logPath)"
        }

        read()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in read() }
    }
}
