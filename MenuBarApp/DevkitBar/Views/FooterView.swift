import SwiftUI

struct FooterView: View {
    @EnvironmentObject var registry: AppRegistry

    var body: some View {
        Divider()

        HStack {
            FooterButton(icon: "square.grid.2x2", label: "Dashboard") {
                NSWorkspace.shared.open(registry.dashboardURL)
                NSApp.keyWindow?.close()
            }

            Spacer()

            FooterButton(icon: "power", label: "Quit", destructive: true) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct FooterButton: View {
    let icon: String
    let label: String
    var destructive: Bool = false
    let action: () -> Void

    @State private var hovered = false

    private var baseColor: Color { destructive ? Color(hex: "ef4444") : .secondary }
    private var activeColor: Color { destructive ? Color(hex: "ef4444") : Color.primary.opacity(0.85) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .imageScale(.small)
                Text(label)
                    .fontWeight(hovered ? .medium : .regular)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(hovered ? activeColor : baseColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovered ? Color.primary.opacity(destructive ? 0 : 0.07) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.12), value: hovered)
    }
}
