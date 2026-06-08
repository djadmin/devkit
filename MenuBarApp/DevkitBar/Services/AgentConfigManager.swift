import AppKit
import Foundation
import Combine

// MARK: – Model

struct AgentInfo: Identifiable {
    let id: String
    let name: String
    let icon: String          // SF Symbol
    let configPath: String    // absolute path to the config file (or empty if manual-only)
    let installed: Bool       // agent directory / app detected
    let configured: Bool      // devkit snippet already present
    let fileExists: Bool      // config file exists
    let manualOnly: Bool      // no file to patch (e.g. Cursor global settings)
}

// MARK: – Manager

@MainActor
final class AgentConfigManager: ObservableObject {
    @Published var agents: [AgentInfo] = []
    @Published var errorMessage: String?

    static let snippet = """


    ## devkit — App Registration

    After creating any web application or local service, register it with devkit:

    ```bash
    devkit register <app-name> --port <port> --cmd "<start-command>"
    ```

    - Use lowercase-hyphenated names (e.g. my-api, auth-service)
    - Run after the project structure exists, not before
    - Skip if devkit is not installed: `which devkit`
    """

    private let fm = FileManager.default
    private let home = NSHomeDirectory()

    // MARK: – Detect

    func refresh() {
        agents = [
            claudeInfo(),
            codexInfo(),
            cursorInfo(),
            windsurfInfo(),
        ]
    }

    private func claudeInfo() -> AgentInfo {
        let dir  = "\(home)/.claude"
        let file = "\(dir)/CLAUDE.md"
        let installed   = fm.fileExists(atPath: dir)
        let fileExists  = fm.fileExists(atPath: file)
        let configured  = fileExists && contains(file: file, text: "devkit register")
        return AgentInfo(id: "claude", name: "Claude Code", icon: "sparkle",
                         configPath: file, installed: installed,
                         configured: configured, fileExists: fileExists, manualOnly: false)
    }

    private func codexInfo() -> AgentInfo {
        let dir  = "\(home)/.codex"
        let file = "\(dir)/AGENTS.md"
        let installed   = fm.fileExists(atPath: dir)
        let fileExists  = fm.fileExists(atPath: file)
        let configured  = fileExists && contains(file: file, text: "devkit register")
        return AgentInfo(id: "codex", name: "OpenAI Codex", icon: "brain",
                         configPath: file, installed: installed,
                         configured: configured, fileExists: fileExists, manualOnly: false)
    }

    private func cursorInfo() -> AgentInfo {
        // Cursor has no writable global config file — user pastes into Settings → Rules.
        let installed = fm.fileExists(atPath: "/Applications/Cursor.app") ||
                        runSync("/usr/bin/which", args: ["cursor"]) != nil
        return AgentInfo(id: "cursor", name: "Cursor", icon: "cursorarrow",
                         configPath: "", installed: installed,
                         configured: false, fileExists: false, manualOnly: true)
    }

    private func windsurfInfo() -> AgentInfo {
        let installed = fm.fileExists(atPath: "/Applications/Windsurf.app")
        return AgentInfo(id: "windsurf", name: "Windsurf", icon: "wind",
                         configPath: "", installed: installed,
                         configured: false, fileExists: false, manualOnly: true)
    }

    // MARK: – Install

    /// Appends the devkit snippet to the agent's config file.
    /// Creates the file (and parent directory) if needed.
    /// Idempotent — skips if already configured.
    func install(agentId: String) {
        guard let agent = agents.first(where: { $0.id == agentId }),
              !agent.manualOnly, !agent.configured else { return }

        errorMessage = nil
        let dir = (agent.configPath as NSString).deletingLastPathComponent

        do {
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

            if agent.fileExists,
               let existing = try? String(contentsOfFile: agent.configPath, encoding: .utf8) {
                let updated = existing + Self.snippet
                try updated.write(toFile: agent.configPath, atomically: true, encoding: .utf8)
            } else {
                let fresh = "# Agent configuration\n" + Self.snippet
                try fresh.write(toFile: agent.configPath, atomically: true, encoding: .utf8)
            }
            refresh()
        } catch {
            errorMessage = "Could not write \(agent.configPath): \(error.localizedDescription)"
        }
    }

    /// Opens the config file in the default text editor.
    func openFile(agentId: String) {
        guard let agent = agents.first(where: { $0.id == agentId }),
              !agent.configPath.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: agent.configPath))
    }

    // MARK: – Helpers

    private func contains(file: String, text: String) -> Bool {
        (try? String(contentsOfFile: file, encoding: .utf8))?.contains(text) == true
    }

    @discardableResult
    private func runSync(_ path: String, args: [String]) -> String? {
        let t = Process()
        t.executableURL = URL(fileURLWithPath: path)
        t.arguments = args
        let pipe = Pipe()
        t.standardOutput = pipe
        t.standardError  = Pipe()
        try? t.run()
        t.waitUntilExit()
        guard t.terminationStatus == 0 else { return nil }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
