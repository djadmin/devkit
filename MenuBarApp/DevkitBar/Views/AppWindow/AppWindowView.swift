import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case services = "services"
    case agents   = "agents"
    case discover = "discover"
    case logs     = "logs"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .services: return "Services"
        case .agents:   return "Agent setup"
        case .discover: return "Discover"
        case .logs:     return "Logs"
        }
    }

    var icon: String {
        switch self {
        case .services: return "square.grid.2x2"
        case .agents:   return "sparkles"
        case .discover: return "dot.radiowaves.left.and.right"
        case .logs:     return "doc.text"
        }
    }
}

struct AppWindowView: View {
    @EnvironmentObject var registry: AppRegistry
    @StateObject private var agentManager = AgentConfigManager()
    @State private var selection: SidebarItem? = .services

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear { agentManager.refresh() }
        .frame(minWidth: 720, minHeight: 480)
    }

    // MARK: – Sidebar

    private var sidebar: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            Label(item.label, systemImage: item.icon)
                .tag(item)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 200)
    }

    // MARK: – Detail

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .services {
        case .services: ServicesListView()
        case .agents:   AgentSetupView().environmentObject(agentManager)
        case .discover: DiscoverView()
        case .logs:     LogsView()
        }
    }
}
