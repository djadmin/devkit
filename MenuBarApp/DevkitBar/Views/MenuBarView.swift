import SwiftUI
import Combine

struct MenuBarView: View {
    @EnvironmentObject var registry: AppRegistry
    @State private var searchText    = ""
    @State private var debouncedQuery = ""
    @FocusState private var searchFocused: Bool

    // Debounce search input so filtering doesn't fire on every keystroke
    private let searchPublisher = PassthroughSubject<String, Never>()

    // MARK: – Derived lists

    private var runningApps: [AppEntry] {
        registry.apps.filter { registry.status(for: $0) == .running }.sorted { $0.name < $1.name }
    }
    private var stoppedApps: [AppEntry] {
        registry.apps.filter { registry.status(for: $0) == .stopped }.sorted { $0.name < $1.name }
    }
    private var externalApps: [AppEntry] {
        registry.apps.filter { $0.isExternallyManaged }.sorted { $0.name < $1.name }
    }

    private var sortedApps: [AppEntry] {
        let source: [AppEntry] = debouncedQuery.isEmpty ? registry.apps : registry.apps.filter {
            let q = debouncedQuery.lowercased()
            return $0.name.lowercased().contains(q) || $0.hostname.lowercased().contains(q)
        }
        return source.sorted { a, b in
            let ra = statusRank(registry.status(for: a)), rb = statusRank(registry.status(for: b))
            return ra != rb ? ra < rb : a.name < b.name
        }
    }

    private func statusRank(_ s: AppStatus) -> Int {
        switch s {
        case .running:  return 0
        case .external: return 1
        case .checking: return 2
        case .stopped:  return 3
        }
    }

    private var showSections: Bool {
        debouncedQuery.isEmpty && !runningApps.isEmpty && !stoppedApps.isEmpty
    }

    // MARK: – Body

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            Divider()
            searchBar
            content
            FooterView()
        }
        .frame(width: 360)
        .background(.ultraThinMaterial)
        .onAppear {
            // Slight delay so the window is fully presented before grabbing focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
            }
        }
        .onReceive(
            searchPublisher.debounce(for: .milliseconds(120), scheduler: RunLoop.main)
        ) { debouncedQuery = $0 }
    }

    // MARK: – Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .imageScale(.small)
                .foregroundStyle(.tertiary)
                .frame(width: 14)

            TextField("Filter apps…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($searchFocused)
                .onChange(of: searchText) { _, newValue in searchPublisher.send(newValue) }
                .onExitCommand { searchText = ""; debouncedQuery = ""; searchFocused = false }

            if !searchText.isEmpty {
                Button {
                    searchText = ""; debouncedQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.small)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.75)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.primary.opacity(searchFocused ? 0.09 : 0.06))
                .animation(.easeOut(duration: 0.15), value: searchFocused)
        )
        .padding(.horizontal, 12)
        .padding(.top, 9)
        .padding(.bottom, 8)
        .animation(.easeOut(duration: 0.15), value: searchText.isEmpty)
    }

    // MARK: – Content

    @ViewBuilder
    private var content: some View {
        if !registry.isReady {
            emptyState(icon: nil, title: "Starting up…", subtitle: nil, showSpinner: true)
        } else if let msg = registry.errorMessage {
            emptyState(icon: "exclamationmark.triangle.fill", title: msg, subtitle: nil)
        } else if registry.apps.isEmpty {
            OnboardingView()
        } else if !debouncedQuery.isEmpty && sortedApps.isEmpty {
            emptyState(icon: "magnifyingglass", title: "No results for \"\(debouncedQuery)\"", subtitle: nil)
        } else {
            appList
        }
    }

    // MARK: – App list

    private var listHeight: CGFloat {
        let count         = CGFloat(registry.apps.count)
        let rowH: CGFloat    = 52
        let divH: CGFloat    = 1
        let secH: CGFloat    = 26
        let groupGap: CGFloat = 9

        var h = count * rowH + max(count - 1, 0) * divH
        if showSections {
            let sectionCount: CGFloat = !externalApps.isEmpty ? 3 : 2
            h += sectionCount * secH + (sectionCount - 1) * groupGap
        }
        return min(h, 460)
    }

    private var appList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                if showSections { groupedSections }
                else            { rows(for: sortedApps) }
            }
        }
        .frame(height: listHeight)
    }

    // MARK: – Sections

    @ViewBuilder
    private var groupedSections: some View {
        if !runningApps.isEmpty {
            SectionHeader(title: "Running", count: runningApps.count,
                          actionLabel: "Stop All", actionColor: Color(hex: "ef4444")) {
                runningApps.forEach { registry.stop($0) }
            }
            rows(for: runningApps)
        }
        if !stoppedApps.isEmpty {
            if !runningApps.isEmpty { Divider().padding(.vertical, 4) }
            SectionHeader(title: "Stopped", count: stoppedApps.count,
                          actionLabel: "Start All", actionColor: Color(hex: "22c55e")) {
                stoppedApps.forEach { registry.start($0) }
            }
            rows(for: stoppedApps)
        }
        if !externalApps.isEmpty {
            Divider().padding(.vertical, 4)
            SectionHeader(title: "External", count: externalApps.count,
                          actionLabel: nil, actionColor: .clear, action: nil)
            rows(for: externalApps)
        }
    }

    @ViewBuilder
    private func rows(for apps: [AppEntry]) -> some View {
        ForEach(Array(apps.enumerated()), id: \.element.id) { idx, app in
            AppRowView(app: app)
            if idx < apps.count - 1 {
                Divider().padding(.leading, 44)
            }
        }
    }

    // MARK: – Empty state

    private func emptyState(
        icon: String?,
        title: String,
        subtitle: String?,
        showSpinner: Bool = false
    ) -> some View {
        VStack(spacing: 8) {
            if showSpinner {
                ProgressView().controlSize(.small)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
            }
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

// MARK: – Section header

private struct SectionHeader: View {
    let title: String
    let count: Int
    let actionLabel: String?
    let actionColor: Color
    let action: (() -> Void)?

    @State private var hovered = false

    var body: some View {
        HStack(spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
                .tracking(0.5)
            Text("· \(count)")
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.18))
            Spacer()
            if let label = actionLabel, let action {
                Button(action: action) {
                    Text(label)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(hovered ? actionColor : actionColor.opacity(0.5))
                }
                .buttonStyle(.plain)
                .onHover { h in withAnimation(.easeOut(duration: 0.1)) { hovered = h } }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.03))
    }
}
