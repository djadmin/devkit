import SwiftUI

@main
struct DevkitBarApp: App {
    @StateObject private var registry = AppRegistry()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(registry)
        } label: {
            MenuBarLabel(runningCount: registry.runningCount, isReady: registry.isReady)
        }
        .menuBarExtraStyle(.window)
    }
}

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
