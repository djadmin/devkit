import Foundation

enum PortScanner {
    // Common local dev ports worth scanning.
    // Covers Node (3000–3003), Vite (5173+), Django/Flask (5000+),
    // Rails (3000), Go/Java (8080+), and the 7xxx range used by devkit-proxied apps.
    static let candidates = [
        3000, 3001, 3002, 3003,
        4000, 4200, 4321,
        5000, 5001, 5173, 5174, 5175,
        7700, 7701, 7702, 7703, 7704, 7705,
        7710, 7720, 7730, 7734, 7740, 7750,
        7760, 7770, 7777, 7780, 7788, 7790, 7795,
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
