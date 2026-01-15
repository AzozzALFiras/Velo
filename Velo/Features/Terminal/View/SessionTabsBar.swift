//
//  SessionTabsBar.swift
//  Velo
//
//  Terminal Session Tabs Bar
//  Clean tabs for navigating between terminal sessions
//

import SwiftUI

// MARK: - Session Tabs Bar

/// A clean tab bar for navigating between terminal sessions
struct SessionTabsBar: View {
    
    let sessions: [TerminalViewModel]
    let activeSessionId: UUID?
    var onSelectSession: (UUID) -> Void
    var onCloseSession: (UUID) -> Void
    var onNewSession: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Sessions tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(sessions) { session in
                        SessionTab(
                            session: session,
                            isActive: session.id == activeSessionId,
                            onSelect: { onSelectSession(session.id) },
                            onClose: { onCloseSession(session.id) }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
            
            Spacer()
            
            // New session button
            Button(action: onNewSession) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(ColorTokens.layer2)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            .help("workspace.newSession".localized)
        }
        .frame(height: 32)
        .background(ColorTokens.layer1)
        .overlay(alignment: .bottom) {
            Divider()
                .background(ColorTokens.borderSubtle)
        }
    }
}

// MARK: - Session Tab

/// Individual session tab
private struct SessionTab: View {
    
    @ObservedObject var session: TerminalViewModel
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Session type icon
                Image(systemName: session.isSSHActive ? "network" : "terminal")
                    .font(.system(size: 10))
                    .foregroundStyle(isActive ? ColorTokens.accentPrimary : ColorTokens.textTertiary)
                
                // Session name
                Text(sessionDisplayName)
                    .font(.system(size: 11, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: 120)
                
                // Close button (on hover)
                if isHovered || isActive {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tabBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
    
    private var sessionDisplayName: String {
        if session.isSSHActive {
            return "session.tab.ssh".localized
        }
        // Show last directory component for local sessions
        return session.currentDirectory.components(separatedBy: "/").last ?? "session.tab.local".localized
    }
    
    private var tabBackground: some View {
        Group {
            if isActive {
                ColorTokens.layer2
            } else if isHovered {
                ColorTokens.layer2.opacity(0.5)
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SessionTabsBar(
        sessions: [],
        activeSessionId: nil,
        onSelectSession: { _ in },
        onCloseSession: { _ in },
        onNewSession: { }
    )
    .frame(width: 600)
    .background(ColorTokens.layer0)
}

