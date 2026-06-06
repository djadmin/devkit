import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var registry: AppRegistry
    @State private var spinning = false
    @State private var reloadHovered = false

    private var subtitle: String {
        guard registry.isReady else { return "loading…" }
        let total = registry.apps.count
        guard total > 0 else { return "no apps registered" }
        let n = registry.runningCount
        if n == total { return "all \(total) running" }
        if n == 0     { return "all stopped" }
        return "\(n) of \(total) running"
    }

    private var runningDotColor: Color {
        guard registry.isReady, registry.apps.count > 0 else { return .clear }
        if registry.runningCount == registry.apps.count { return Color(hex: "22c55e") }
        if registry.runningCount == 0 { return Color(hex: "ef4444") }
        return Color(hex: "f59e0b")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Logo + status
            HStack(spacing: 8) {
                // Small accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.85))
                    .frame(width: 3, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text("devkit")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    HStack(spacing: 4) {
                        Circle()
                            .fill(runningDotColor)
                            .frame(width: 5, height: 5)
                            .opacity(registry.isReady ? 1 : 0)
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.2), value: subtitle)
                    }
                }
            }

            Spacer()

            // Reload button
            Button {
                guard !spinning else { return }
                spinning = true
                registry.reload()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    spinning = false
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .imageScale(.medium)
                    .foregroundStyle(reloadHovered ? Color.primary.opacity(0.75) : Color.secondary.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(reloadHovered ? Color.primary.opacity(0.08) : Color.clear)
                    )
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                    .animation(
                        spinning
                            ? .linear(duration: 0.55).repeatForever(autoreverses: false)
                            : .default,
                        value: spinning
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("r", modifiers: .command)
            .onHover { reloadHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: reloadHovered)
            .help("Reload registry and recheck all statuses  ⌘R")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
