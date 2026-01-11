//
//  TabBarView.swift
//  Velo
//
//  AI-Powered Terminal - Tab Bar Configuration
//
//

import SwiftUI

struct TabBarView: View {
    @ObservedObject var tabManager: TabManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(tabManager.sessions) { session in
                    TabItemView(
                        title: session.title,
                        isActive: session.id == tabManager.activeSessionId,
                        onSelect: { tabManager.switchToSession(id: session.id) },
                        onClose: { tabManager.closeSession(id: session.id) }
                    )
                }
                
                // Add Tab Button
                Button(action: {
                    tabManager.addSession()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(VeloDesign.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(height: 38)
        .background(VeloDesign.Colors.deepSpace.opacity(0.8))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.1)),
            alignment: .bottom
        )
    }
}

struct TabItemView: View {
    let title: String
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .font(.caption2)
                    .foregroundColor(isActive ? VeloDesign.Colors.neonCyan : VeloDesign.Colors.textMuted)
                
                Text(title)
                    .font(.system(size: 12, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? VeloDesign.Colors.textPrimary : VeloDesign.Colors.textSecondary)
                    .lineLimit(1)
                
                // Close button (only show on hover or active)
                if isHovered || isActive {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(VeloDesign.Colors.textMuted)
                            .frame(width: 16, height: 16)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.white.opacity(0.1) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
            )
            .overlay(
                // Active indicator line
                Rectangle()
                    .fill(VeloDesign.Colors.neonCyan)
                    .frame(height: 2)
                    .opacity(isActive ? 1 : 0)
                    .padding(.horizontal, 4),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
