import SwiftUI

struct AgentSetupView: View {
    @EnvironmentObject var agentManager: AgentConfigManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Agent setup")
                        .font(.title2).fontWeight(.semibold)
                    Text("Add one snippet per agent. Every app it builds will auto-register in devkit — you just visit the URL.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let err = agentManager.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(err).font(.callout).foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }

                // Cards
                VStack(spacing: 10) {
                    ForEach(agentManager.agents) { agent in
                        AgentCard(agent: agent)
                            .environmentObject(agentManager)
                    }
                }

                Divider()

                // Snippet preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("What gets added")
                        .font(.callout).fontWeight(.medium)
                    Text(AgentConfigManager.snippet.trimmingCharacters(in: .newlines))
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
        }
        .navigationTitle("Agent setup")
        .toolbar {
            ToolbarItem {
                Button { agentManager.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Re-check agent configs")
            }
        }
    }
}

// MARK: – Agent card

private struct AgentCard: View {
    @EnvironmentObject var agentManager: AgentConfigManager
    let agent: AgentInfo
    @State private var showSnippet = false
    @State private var isWriting = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon
            Image(systemName: agent.icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(agent.name).font(.system(size: 14, weight: .medium))
                    statusBadge
                }
                Text(subtitleText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Action
            actionButton
        }
        .padding(14)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
        )
        .sheet(isPresented: $showSnippet) {
            ManualSnippetSheet(agent: agent)
        }
    }

    // MARK: – Computed

    private var iconColor: Color {
        if agent.configured { return Color(hex: "22c55e") }
        if !agent.installed  { return .secondary }
        return Color(hex: "6366f1")
    }

    private var statusBadge: some View {
        Group {
            if agent.configured {
                Badge(text: "Configured", style: .success)
            } else if !agent.installed {
                Badge(text: "Not found", style: .neutral)
            } else if agent.manualOnly {
                Badge(text: "Manual setup", style: .info)
            } else if agent.fileExists {
                Badge(text: "File exists, not configured", style: .warning)
            } else {
                Badge(text: "Not configured", style: .neutral)
            }
        }
    }

    private var subtitleText: String {
        if agent.configured  { return agent.configPath.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
        if !agent.installed  { return "Agent not detected on this machine" }
        if agent.manualOnly  { return "Paste snippet manually into agent settings" }
        if agent.fileExists  { return agent.configPath.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
        return "Will create \(agent.configPath.replacingOccurrences(of: NSHomeDirectory(), with: "~"))"
    }

    @ViewBuilder
    private var actionButton: some View {
        if agent.configured {
            Button {
                agentManager.openFile(agentId: agent.id)
            } label: {
                Text("View file")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else if !agent.installed {
            EmptyView()
        } else if agent.manualOnly {
            Button { showSnippet = true } label: {
                Text("Copy snippet")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else {
            Button {
                isWriting = true
                agentManager.install(agentId: agent.id)
                isWriting = false
            } label: {
                HStack(spacing: 4) {
                    if isWriting { ProgressView().controlSize(.mini) }
                    Text("Add snippet")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isWriting)
        }
    }
}

// MARK: – Manual snippet sheet (Cursor / Windsurf)

private struct ManualSnippetSheet: View {
    let agent: AgentInfo
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var snippet: String { AgentConfigManager.snippet.trimmingCharacters(in: .newlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Snippet for \(agent.name)")
                    .font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Done") { dismiss() }
            }

            Text("Paste this into **\(agent.name) Settings → Rules** (global), or into a project-level rules file.")
                .font(.callout)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topTrailing) {
                ScrollView {
                    Text(snippet)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                .frame(maxHeight: 200)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snippet, forType: .string)
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { copied = false } }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copied ? Color(hex: "22c55e") : .secondary)
                        .frame(width: 28, height: 28)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(6)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

// MARK: – Badge

private struct Badge: View {
    enum Style { case success, warning, info, neutral }
    let text: String
    let style: Style

    private var fg: Color {
        switch style {
        case .success: return Color(hex: "16a34a")
        case .warning: return Color(hex: "d97706")
        case .info:    return Color(hex: "2563eb")
        case .neutral: return .secondary
        }
    }
    private var bg: Color { fg.opacity(0.1) }

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(fg)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(bg, in: Capsule())
    }
}
