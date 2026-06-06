import Foundation

enum DevkitCLI {
    // Resolved once at startup. Checks known locations first, then falls back
    // to asking the shell (sources ~/.zshrc so custom PATH installs are found).
    static let binaryPath: String? = {
        let candidates = [
            "/opt/homebrew/bin/devkit",
            "/usr/local/bin/devkit",
            NSHomeDirectory() + "/.local/bin/devkit",
            NSHomeDirectory() + "/devkit/bin/devkit",
        ]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return found
        }
        // Shell fallback: sources .zshrc so installs via custom PATH are found.
        // Synchronous and runs once — acceptable for a static initializer.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-l", "-c", "source ~/.zshrc 2>/dev/null; which devkit"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = Pipe()
        try? task.run()
        task.waitUntilExit()
        let path = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? nil : path
    }()

    @discardableResult
    static func run(_ subcommand: String) async -> String {
        guard let binary = binaryPath else { return "" }
        return await withCheckedContinuation { cont in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments = ["-l", "-c", "source ~/.zshrc 2>/dev/null; \(binary) \(subcommand)"]

            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            task.environment = env

            let out = Pipe(), err = Pipe()
            task.standardOutput = out
            task.standardError  = err

            task.terminationHandler = { _ in
                let data = out.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do    { try task.run() }
            catch { cont.resume(returning: "") }
        }
    }

    static func appsJSONPath() async -> String? {
        let output = await run("paths")
        return output.split(separator: "\n")
            .first { $0.hasPrefix("APPS_JSON=") }
            .map { String($0.dropFirst("APPS_JSON=".count)) }
    }

    static func start(_ name: String) async { await run("start \(name)") }
    static func stop(_ name: String)  async { await run("stop \(name)") }
}
