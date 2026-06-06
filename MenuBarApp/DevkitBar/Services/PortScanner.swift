import Foundation

enum PortScanner {
    // Common local dev ports worth scanning
    static let candidates = [
        3000, 3001, 3002, 3003,
        4000, 4200,
        5000, 5001, 5173, 5174, 5175,
        8000, 8001, 8080, 8081, 8888,
        9000, 9001
    ]

    /// Returns all responding ports, excluding any already registered in the registry.
    static func scan(excluding registered: Set<Int> = []) async -> [Int] {
        await withTaskGroup(of: (Int, Bool).self) { group in
            for port in candidates where !registered.contains(port) {
                group.addTask { (port, await PortChecker.isReachable(port: port)) }
            }
            var found: [Int] = []
            for await (port, up) in group where up { found.append(port) }
            return found.sorted()
        }
    }
}
