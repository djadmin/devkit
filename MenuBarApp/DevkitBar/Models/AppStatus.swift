import SwiftUI

enum AppStatus: Equatable {
    case running
    case stopped
    case external
    case checking

    var dotColor: Color {
        switch self {
        case .running:  return Color(hex: "22c55e")
        case .stopped:  return Color(hex: "ef4444")
        case .external: return Color(hex: "a78bfa")
        case .checking: return Color.secondary.opacity(0.35)
        }
    }

    var glows: Bool { self == .running }
}

extension Color {
    init(hex: String) {
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double( int        & 0xFF) / 255
        )
    }
}
