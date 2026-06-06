import SwiftUI

struct AppRowView: View {
    @EnvironmentObject var registry: AppRegistry
    let app: AppEntry

    @State private var hovered = false
    @State private var copied  = false

    private var status: AppStatus { registry.status(for: app) }

    var body: some View {
        HStack(spacing: 0) {

            // ── Left tappable zone (dot + name + host) ──────────────────
            HStack(spacing: 0) {
                StatusDot(status: status)
                    .padding(.leading, 16)
                    .padding(.trailing, 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.9))
                        .lineLimit(1)

                    HStack(spacing: 0) {
                        Text(app.hostname)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let port = portLabel {
                            // Use verbatim: to avoid LocalizedStringKey adding comma separators
                            Text(verbatim: ":\(port)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { open() }

            // ── Right action buttons ─────────────────────────────────────
            HStack(spacing: 1) {
                copyButton
                openButton
                if !app.isExternallyManaged {
                    toggleButton
                }
            }
            .padding(.trailing, 10)
            .opacity(hovered ? 1 : 0.45)
        }
        .frame(height: 52)
        .background(hovered ? Color.primary.opacity(0.055) : Color.clear)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.13)) { hovered = h }
        }
    }

    // MARK: – Port

    private var portLabel: Int? {
        guard app.port > 0, app.port != 80, app.port != 443 else { return nil }
        return app.port
    }

    // MARK: – Actions

    private var copyButton: some View {
        RowButton(
            icon: copied ? "checkmark" : "doc.on.doc",
            tint: copied ? Color(hex: "22c55e") : .secondary,
            help: "Copy URL"
        ) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(registry.url(for: app).absoluteString, forType: .string)
            withAnimation(.spring(duration: 0.2)) { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeOut(duration: 0.2)) { copied = false }
            }
        }
    }

    private var openButton: some View {
        RowButton(icon: "arrow.up.right.square", tint: .secondary, help: "Open in browser") {
            open()
        }
    }

    @ViewBuilder
    private var toggleButton: some View {
        switch status {
        case .checking:
            ProgressView()
                .controlSize(.mini)
                .frame(width: 28, height: 28)
        case .running:
            RowButton(icon: "stop.circle.fill", tint: Color(hex: "ef4444"), help: "Stop \(app.name)") {
                registry.stop(app)
            }
        default:
            RowButton(icon: "play.circle.fill", tint: Color(hex: "22c55e"), help: "Start \(app.name)") {
                registry.start(app)
            }
        }
    }

    private func open() {
        NSWorkspace.shared.open(registry.url(for: app))
        // @Environment(\.dismiss) is a no-op inside MenuBarExtra(.window).
        // Closing the key window is the reliable way to dismiss the panel.
        NSApp.keyWindow?.close()
    }
}

// MARK: – StatusDot with pulse

private struct StatusDot: View {
    let status: AppStatus
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Outer pulse ring for running apps
            if status == .running {
                Circle()
                    .fill(Color(hex: "22c55e").opacity(pulse ? 0 : 0.35))
                    .frame(width: 16, height: 16)
                    .scaleEffect(pulse ? 1.6 : 0.8)
                    .animation(
                        .easeOut(duration: 1.6).repeatForever(autoreverses: false),
                        value: pulse
                    )
            }

            // Core dot
            Circle()
                .fill(status.dotColor)
                .frame(width: 8, height: 8)
                .shadow(color: status.dotColor.opacity(status == .running ? 0.6 : 0), radius: 4)
        }
        .frame(width: 16, height: 16)
        .onAppear {
            if status == .running { pulse = true }
        }
        .onChange(of: status) { new in
            pulse = (new == .running)
        }
        .animation(.easeInOut(duration: 0.3), value: status)
    }
}

// MARK: – Row button

private struct RowButton: View {
    let icon: String
    let tint: Color
    let help: String
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .imageScale(.medium)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(hovered ? tint.opacity(0.12) : Color.clear)
                )
                .scaleEffect(hovered ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { h in
            withAnimation(.spring(duration: 0.15)) { hovered = h }
        }
    }
}
