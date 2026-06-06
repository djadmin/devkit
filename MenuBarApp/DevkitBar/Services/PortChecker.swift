import Foundation
import Network

// Thread-safe exactly-once gate used by PortChecker to ensure the continuation
// is resumed exactly once across concurrent NWConnection and timeout callbacks.
private final class OnceToken: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false

    /// Returns true the first time it's called; false every subsequent time.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !fired else { return false }
        fired = true
        return true
    }
}

enum PortChecker {
    static func isReachable(port: Int) async -> Bool {
        guard port > 0, port < 65536 else { return false }

        return await withCheckedContinuation { cont in
            let conn  = NWConnection(
                host: "127.0.0.1",
                port: NWEndpoint.Port(integerLiteral: UInt16(clamping: port)),
                using: .tcp
            )
            let queue = DispatchQueue(label: "devkit.portcheck.\(port)")
            let once  = OnceToken()

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:  if once.claim() { conn.cancel(); cont.resume(returning: true) }
                case .failed: if once.claim() { conn.cancel(); cont.resume(returning: false) }
                default: break
                }
            }
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 1.5) {
                if once.claim() { conn.cancel(); cont.resume(returning: false) }
            }
        }
    }
}
