//
//  WorkspaceSidebar.swift
//  Velo
//
//  Workspace - Left Sidebar Navigation
//  Contains Sessions, Servers, Files, AI Actions, Commands
//

import SwiftUI

// MARK: - Sidebar Section

/// Represents a collapsible section in the sidebar
enum SidebarSection: String, CaseIterable, Identifiable {
    case sessions = "Sessions"
    case servers = "SSH Servers"
    case files = "Files"
    case aiActions = "AI Actions"
    case git = "Git"
    case docker = "Docker"
    case commands = "Commands"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .sessions: return "terminal"
        case .servers: return "server.rack"
        case .files: return "folder"
        case .aiActions: return "sparkles"
        case .git: return "arrow.branch"
        case .docker: return "shippingbox"
        case .commands: return "text.alignleft"
        default: return "circle"
        }
    }
    
    var label: String {
        switch self {
        case .sessions: return "sidebar.sessions".localized
        case .servers: return "workspace.sshServers".localized
        case .files: return "intelligence.files".localized
        case .aiActions: return "sidebar.ai".localized
        case .git: return "sidebar.git".localized
        case .docker: return "sidebar.docker".localized
        case .commands: return "commandBar.commands".localized
        }
    }
}

// MARK: - Workspace Sidebar

/// Left sidebar navigation for the workspace
struct WorkspaceSidebar: View {
    
    // State
    @Binding var selectedSection: SidebarSection?
    var sessions: [TerminalViewModel]
    var activeSessionId: UUID?
    var sshConnections: [SSHConnection]
    
    // Actions
    var onNewSession: (() -> Void)?
    var onSelectSession: ((UUID) -> Void)?
    var onConnectSSH: ((SSHConnection) -> Void)?
    var onNewSSH: (() -> Void)?
    var onAIAction: ((AIQuickAction) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenShortcuts: (() -> Void)?
    
    // Collapsed sections
    @State private var collapsedSections: Set<SidebarSection> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            sidebarHeader
            
            Divider()
                .background(ColorTokens.border)
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 4) {
                    // Quick Actions
                    quickActionsSection
                    
                    Divider()
                        .background(ColorTokens.borderSubtle)
                        .padding(.vertical, 8)
                    
                    // Sessions
                    sessionsSection
                    
                    Divider()
                        .background(ColorTokens.borderSubtle)
                        .padding(.vertical, 8)
                    
                    // SSH Servers
                    sshSection
                    
                    Divider()
                        .background(ColorTokens.borderSubtle)
                        .padding(.vertical, 8)
                    
                    // AI Actions
                    aiActionsSection
                    
                    Divider()
                        .background(ColorTokens.borderSubtle)
                        .padding(.vertical, 8)
                    
                    // Command Shortcuts
                    shortcutsSection
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            Spacer()
            
            // Footer - Theme toggle
            sidebarFooter
        }
        .background(ColorTokens.layer1)
    }
    
    // MARK: - Header
    
    private var sidebarHeader: some View {
        HStack {
            Text("workspace.title".localized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ColorTokens.textPrimary)
            
            Spacer()
            
            Button {
                onNewSession?()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(ColorTokens.layer2)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .help("workspace.newSession".localized)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(spacing: 4) {
            SidebarButton(
                icon: "plus.rectangle",
                label: "workspace.newSession".localized,
                shortcut: "⌘N"
            ) {
                onNewSession?()
            }
            
            SidebarButton(
                icon: "network",
                label: "workspace.newSSH".localized,
                shortcut: "⌘⇧N"
            ) {
                onNewSSH?()
            }
            
            SidebarButton(
                icon: "arrow.branch",
                label: "sidebar.git".localized,
                isActive: selectedSection == .git
            ) {
                selectedSection = .git
            }
            
            SidebarButton(
                icon: "shippingbox",
                label: "sidebar.docker".localized,
                isActive: selectedSection == .docker
            ) {
                selectedSection = .docker
            }
        }
    }
    
    // MARK: - Sessions Section
    
    private var sessionsSection: some View {
        SidebarSectionView(
            title: SidebarSection.sessions.label,
            icon: "terminal",
            isCollapsed: collapsedSections.contains(.sessions),
            onToggle: { toggleSection(.sessions) }
        ) {
            ForEach(sessions) { session in
                SessionRow(
                    session: session,
                    isActive: session.id == activeSessionId
                ) {
                    onSelectSession?(session.id)
                }
            }
        }
    }
    
    // MARK: - SSH Section
    
    private var sshSection: some View {
        SidebarSectionView(
            title: SidebarSection.servers.label,
            icon: "server.rack",
            badge: sshConnections.count,
            isCollapsed: collapsedSections.contains(.servers),
            onToggle: { toggleSection(.servers) }
        ) {
            if sshConnections.isEmpty {
                Text("workspace.connections.none".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.vertical, 8)
                    .padding(.leading, 8)
            } else {
                ForEach(sshConnections) { connection in
                    SSHServerRow(connection: connection) {
                        onConnectSSH?(connection)
                    }
                }
            }
            
            // Add server button
            SidebarButton(
                icon: "plus",
                label: "ssh.addServer".localized,
                style: .subtle
            ) {
                onNewSSH?()
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - AI Actions Section
    
    private var aiActionsSection: some View {
        SidebarSectionView(
            title: SidebarSection.aiActions.label,
            icon: "sparkles",
            isCollapsed: collapsedSections.contains(.aiActions),
            onToggle: { toggleSection(.aiActions) }
        ) {
            ForEach(AIQuickAction.allCases) { action in
                SidebarButton(
                    icon: action.icon,
                    label: action.label,
                    color: action.color
                ) {
                    onAIAction?(action)
                }
            }
        }
    }
    
    // MARK: - Shortcuts Section
    
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Section header
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.warning)
                
                Text("sidebar.shortcuts".localized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            // Shortcuts button
            SidebarButton(
                icon: "command",
                label: "sidebar.shortcuts".localized,
                style: .subtle
            ) {
                onOpenShortcuts?()
            }
            
            // Quick info
            Text("sidebar.shortcuts.desc".localized)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(ColorTokens.textTertiary)
                .padding(.horizontal, 8)
                .padding(.top, 2)
        }
    }
    
    // MARK: - Footer
    
    private var sidebarFooter: some View {
        HStack(spacing: 12) {
            // Theme indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(ColorTokens.accentPrimary)
                    .frame(width: 8, height: 8)
                
                Text("settings.theme".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            Spacer()
            
            // Settings button - larger and more prominent
            Button {
                onOpenSettings?()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12))
                    Text("sidebar.settings".localized)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(ColorTokens.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ColorTokens.layer2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ColorTokens.layer0)
    }
    
    // MARK: - Helpers
    
    private func toggleSection(_ section: SidebarSection) {
        withAnimation(.easeOut(duration: 0.2)) {
            if collapsedSections.contains(section) {
                collapsedSections.remove(section)
            } else {
                collapsedSections.insert(section)
            }
        }
    }
}

// MARK: - Sidebar Section View

/// Collapsible section container
struct SidebarSectionView<Content: View>: View {
    
    let title: String
    let icon: String
    var badge: Int? = nil
    let isCollapsed: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(width: 16)
                    
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                    
                    if let badge = badge, badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(ColorTokens.layer2)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            
            // Content
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 2) {
                    content()
                }
                .padding(.leading, 8)
            }
        }
    }
}

// MARK: - Sidebar Button

/// Standard sidebar button
struct SidebarButton: View {
    
    enum Style {
        case standard
        case subtle
    }
    
    let icon: String
    let label: String
    var shortcut: String? = nil
    var color: Color = ColorTokens.textSecondary
    var style: Style = .standard
    var isActive: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle((isActive || isHovered) ? color : ColorTokens.textTertiary)
                    .frame(width: 16)
                
                Text(label)
                    .font(.system(size: 12, weight: (style == .subtle && !isActive) ? .regular : .medium))
                    .foregroundStyle((isActive || isHovered) ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                
                Spacer()
                
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isActive ? ColorTokens.accentPrimary.opacity(0.15) : (isHovered ? ColorTokens.layer2 : .clear))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isActive ? ColorTokens.accentPrimary.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Session Row

/// Row for a terminal session
struct SessionRow: View {
    
    let session: TerminalViewModel
    let isActive: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Status indicator
                Circle()
                    .fill(session.isSSHActive ? ColorTokens.success : ColorTokens.accentPrimary)
                    .frame(width: 6, height: 6)
                
                // Title
                Text(session.title)
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                    .lineLimit(1)
                
                Spacer()
                
                // SSH indicator
                if session.isSSHActive {
                    Image(systemName: "network")
                        .font(.system(size: 9))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                isActive ? ColorTokens.accentPrimary.opacity(0.15) :
                    (isHovered ? ColorTokens.layer2 : .clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isActive ? ColorTokens.accentPrimary.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - AI Quick Action

/// Quick AI actions available in sidebar
enum AIQuickAction: String, CaseIterable, Identifiable {
    case quickFix = "Quick Fix"
    case explain = "Explain"
    case generate = "Generate Script"
    case debug = "Debug Mode"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .quickFix: return "sidebar.quickFix".localized
        case .explain: return "sidebar.explain".localized
        case .generate: return "sidebar.generate".localized
        case .debug: return "sidebar.debug".localized
        }
    }
    
    var icon: String {
        switch self {
        case .quickFix: return "wand.and.stars"
        case .explain: return "questionmark.circle"
        case .generate: return "doc.badge.plus"
        case .debug: return "ladybug"
        }
    }
    
    var color: Color {
        switch self {
        case .quickFix: return ColorTokens.success
        case .explain: return ColorTokens.accentSecondary
        case .generate: return ColorTokens.accentPrimary
        case .debug: return ColorTokens.warning
        }
    }
}

// MARK: - Preview

#Preview {
    WorkspaceSidebar(
        selectedSection: .constant(.sessions),
        sessions: [],
        activeSessionId: nil,
        sshConnections: []
    )
    .frame(width: 260, height: 600)
}
