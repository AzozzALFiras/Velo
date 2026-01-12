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
    @Binding var showSettings: Bool
    
    var body: some View {
        HStack(spacing: 0) {
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
                
                // SSH Quick Connect Button
                SSHQuickConnectButton(tabManager: tabManager)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            }
            
            Spacer()
            
            // Global Settings Button in the Tab Bar
            Button(action: {
                withAnimation(VeloDesign.Animation.smooth) {
                    showSettings.toggle()
                }
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(showSettings ? VeloDesign.Colors.neonCyan : VeloDesign.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(showSettings ? VeloDesign.Colors.neonCyan.opacity(0.15) : Color.white.opacity(0.05))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
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

// MARK: - SSH Quick Connect Button
struct SSHQuickConnectButton: View {
    @ObservedObject var tabManager: TabManager
    @EnvironmentObject var sshManager: SSHManager
    @State private var showingPopover = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { showingPopover.toggle() }) {
            Image(systemName: "network")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isHovered ? VeloDesign.Colors.neonCyan : VeloDesign.Colors.textSecondary)
                .frame(width: 28, height: 28)
                .background(isHovered ? VeloDesign.Colors.neonCyan.opacity(0.1) : Color.white.opacity(0.05))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .popover(isPresented: $showingPopover, arrowEdge: .bottom) {
            SSHQuickConnectPopover(tabManager: tabManager, isPresented: $showingPopover)
                .environmentObject(sshManager)
        }
        .help("SSH Quick Connect")
    }
}

// MARK: - SSH Quick Connect Popover
struct SSHQuickConnectPopover: View {
    @ObservedObject var tabManager: TabManager
    @EnvironmentObject var sshManager: SSHManager
    @Binding var isPresented: Bool
    
    @State private var quickHost = ""
    @State private var quickUser = NSUserName()
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
            // Quick connect
            Text("Quick Connect")
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.textMuted)
            
            HStack {
                TextField("user@host", text: $quickHost)
                    .textFieldStyle(.plain)
                    .font(VeloDesign.Typography.monoSmall)
                    .padding(6)
                    .background(VeloDesign.Colors.cardBackground)
                    .cornerRadius(4)
                
                Button(action: quickConnect) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(VeloDesign.Colors.neonCyan)
                }
                .buttonStyle(.plain)
                .disabled(quickHost.isEmpty)
            }
            
            // Recent connections
            if !sshManager.recentConnections.isEmpty {
                Divider().background(VeloDesign.Colors.glassBorder)
                
                Text("Recent")
                    .font(VeloDesign.Typography.caption)
                    .foregroundColor(VeloDesign.Colors.textMuted)
                
                ForEach(sshManager.recentConnections.prefix(3)) { conn in
                    Button(action: { connect(to: conn) }) {
                        HStack {
                            Image(systemName: conn.icon)
                                .foregroundColor(conn.color)
                                .frame(width: 16)
                            Text(conn.displayName)
                                .font(VeloDesign.Typography.monoSmall)
                                .foregroundColor(VeloDesign.Colors.textPrimary)
                            Spacer()
                            Text(conn.host)
                                .font(VeloDesign.Typography.monoSmall)
                                .foregroundColor(VeloDesign.Colors.textMuted)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Saved connections
            if !sshManager.connections.isEmpty {
                Divider().background(VeloDesign.Colors.glassBorder)
                
                Text("Saved")
                    .font(VeloDesign.Typography.caption)
                    .foregroundColor(VeloDesign.Colors.textMuted)
                
                ForEach(sshManager.connections.prefix(5)) { conn in
                    Button(action: { connect(to: conn) }) {
                        HStack {
                            Image(systemName: conn.icon)
                                .foregroundColor(conn.color)
                                .frame(width: 16)
                            Text(conn.displayName)
                                .font(VeloDesign.Typography.monoSmall)
                                .foregroundColor(VeloDesign.Colors.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .frame(width: 280)
        .background(VeloDesign.Colors.deepSpace)
    }
    
    private func quickConnect() {
        // Parse user@host format
        var user = NSUserName()
        var host = quickHost
        
        if quickHost.contains("@") {
            let parts = quickHost.split(separator: "@", maxSplits: 1)
            if parts.count == 2 {
                user = String(parts[0])
                host = String(parts[1])
            }
        }
        
        tabManager.createSSHSession(host: host, user: user, port: 22)
        isPresented = false
    }
    
    private func connect(to connection: SSHConnection) {
        sshManager.markAsConnected(connection)
        tabManager.createSSHSession(
            host: connection.host,
            user: connection.username,
            port: connection.port,
            keyPath: connection.privateKeyPath
        )
        isPresented = false
    }
}
