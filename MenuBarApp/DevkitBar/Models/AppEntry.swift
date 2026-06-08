import Foundation

struct AppEntry: Codable, Identifiable, Equatable, Hashable {
    let name: String
    let hostname: String
    let port: Int
    let path: String?
    let repo: String?
    let claudeMd: String?
    let startCmd: String?
    let description: String
    let managedBy: String

    var id: String { name }
    var isExternallyManaged: Bool { managedBy == "external" }

    var displayPath: String? {
        guard let path else { return nil }
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}

struct RegistryJSON: Codable {
    let version: Int
    let proxyPort: Int?
    let tld: String?
    let dashboardHost: String?
    let apps: [AppEntry]
}
