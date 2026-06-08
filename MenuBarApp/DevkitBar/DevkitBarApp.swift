import SwiftUI

@main
struct DevkitBarApp: App {
    @StateObject private var registry = AppRegistry()
    @Environment(\.openWindow) private var openWindow
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false

    var body: some Scene {

        // ── Full app window ────────────────────────────────────────────
        Window("devkit", id: "main") {
            AppWindowView()
                .environmentObject(registry)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 860, height: 560)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About devkit") { NSApp.orderFrontStandardAboutPanel(nil) }
            }
            CommandGroup(after: .appInfo) {
                Button("Open devkit") { openAndActivate() }
                    .keyboardShortcut("0", modifiers: [.command, .shift])
            }
        }

        // ── Menu bar popover ───────────────────────────────────────────
        MenuBarExtra {
            MenuBarView()
                .environmentObject(registry)
                .onAppear {
                    if !hasLaunchedBefore {
                        hasLaunchedBefore = true
                        // Slight delay so the menu bar window can fully appear first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            openAndActivate()
                        }
                    }
                }
        } label: {
            MenuBarLabel(runningCount: registry.runningCount, isReady: registry.isReady)
        }
        .menuBarExtraStyle(.window)
    }

    private func openAndActivate() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: – Menu bar icon

struct MenuBarLabel: View {
    let runningCount: Int
    let isReady: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "square.grid.2x2.fill")
                .imageScale(.medium)
            if isReady && runningCount > 0 {
                Text("\(runningCount)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .monospacedDigit()
            }
        }
    }
}
