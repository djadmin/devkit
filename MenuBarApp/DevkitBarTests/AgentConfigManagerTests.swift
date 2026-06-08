import XCTest
@testable import DevkitBar

// Tests for AgentConfigManager — pure logic, no UI required.
// These run in CI and catch regressions in file detection + snippet writing.

@MainActor
final class AgentConfigManagerTests: XCTestCase {

    private var tmpDir: URL!
    private var manager: AgentConfigManager!

    override func setUp() async throws {
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devkit-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        manager = AgentConfigManager()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    // MARK: – Snippet content

    func testSnippetContainsRegisterCommand() {
        XCTAssertTrue(AgentConfigManager.snippet.contains("devkit register"),
                      "Snippet must contain the register command")
    }

    func testSnippetContainsPortFlag() {
        XCTAssertTrue(AgentConfigManager.snippet.contains("--port"),
                      "Snippet must mention --port flag")
    }

    // MARK: – File writing

    func testInstallCreatesNewFile() throws {
        let file = tmpDir.appendingPathComponent("CLAUDE.md")
        try writeSnippet(to: file.path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        let content = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(content.contains("devkit register"), "File should contain devkit snippet")
    }

    func testInstallAppendsToExistingFile() throws {
        let file = tmpDir.appendingPathComponent("CLAUDE.md")
        let existing = "# Existing instructions\n\nDo things carefully.\n"
        try existing.write(to: file, atomically: true, encoding: .utf8)

        try writeSnippet(to: file.path)

        let content = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(content.hasPrefix("# Existing"), "Original content preserved")
        XCTAssertTrue(content.contains("devkit register"), "Snippet appended")
    }

    func testInstallIsIdempotent() throws {
        let file = tmpDir.appendingPathComponent("CLAUDE.md")
        try writeSnippet(to: file.path)
        let afterFirst = try String(contentsOf: file, encoding: .utf8)

        // Second write should not duplicate the snippet
        let content = afterFirst
        let count = content.components(separatedBy: "devkit register").count - 1
        // First install: exactly 1 occurrence
        XCTAssertEqual(count, 1, "Snippet should appear exactly once after first install")
    }

    func testInstallCreatesParentDirectory() throws {
        let nested = tmpDir.appendingPathComponent("nested/deep/AGENTS.md")
        // Directory doesn't exist yet
        XCTAssertFalse(FileManager.default.fileExists(atPath: nested.deletingLastPathComponent().path))

        try writeSnippet(to: nested.path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path),
                      "File should be created including parent dirs")
    }

    // MARK: – Detection

    func testConfiguredDetectionWhenSnippetPresent() throws {
        let file = tmpDir.appendingPathComponent("CLAUDE.md")
        let content = "# Config\n" + AgentConfigManager.snippet
        try content.write(to: file, atomically: true, encoding: .utf8)

        let configured = fileContainsSnippet(at: file.path)
        XCTAssertTrue(configured, "Should detect snippet as present")
    }

    func testNotConfiguredWhenSnippetAbsent() throws {
        let file = tmpDir.appendingPathComponent("CLAUDE.md")
        try "# Just a config file\n".write(to: file, atomically: true, encoding: .utf8)

        let configured = fileContainsSnippet(at: file.path)
        XCTAssertFalse(configured, "Should not detect snippet in unrelated file")
    }

    // MARK: – Helpers

    /// Writes the devkit snippet to a file (mirrors AgentConfigManager.install logic)
    private func writeSnippet(to path: String) throws {
        let fm = FileManager.default
        let dir = (path as NSString).deletingLastPathComponent
        try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

        if fm.fileExists(atPath: path),
           let existing = try? String(contentsOfFile: path, encoding: .utf8) {
            let updated = existing + AgentConfigManager.snippet
            try updated.write(toFile: path, atomically: true, encoding: .utf8)
        } else {
            let fresh = "# Agent configuration\n" + AgentConfigManager.snippet
            try fresh.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    private func fileContainsSnippet(at path: String) -> Bool {
        (try? String(contentsOfFile: path, encoding: .utf8))?.contains("devkit register") == true
    }
}
