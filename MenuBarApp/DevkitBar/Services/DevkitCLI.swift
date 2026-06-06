import Foundation

enum DevkitCLI {
    // Resolved once at startup; nil means devkit is not installed
    static let binaryPath: String? = {
        let candidates = [
            "/opt/homebrew/bin/devkit",
            "/usr/local/bin/devkit",
            NSHomeDirectory() + "/.local/bin/devkit",
            NSHomeDirectory() + "/djadmin/devkit/bin/devkit",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()

    // Runs a devkit subcommand via a login shell so PATH (Homebrew, nvm, etc.) is intact.
    @discardableResult
    static func run(_ subcommand: String) async -> String {
        guard let binary = binaryPath else { return "" }
        return await withCheckedContinuation { cont in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments = ["-l", "-c", "\(binary) \(subcommand)"]

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
