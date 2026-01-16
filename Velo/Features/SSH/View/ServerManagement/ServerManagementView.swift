//
//  ServerManagementView.swift
//  Velo
//
//  Main Server Management Container View
//  Combines nav sidebar and content views.
//

import SwiftUI

struct ServerManagementView: View {

    @ObservedObject var session: TerminalViewModel
    @StateObject private var viewModel: ServerManagementViewModel
    
    // Environment dismiss to close the sheet/window
    @Environment(\.dismiss) var dismiss
    
    init(session: TerminalViewModel) {
        self.session = session
        self._viewModel = StateObject(wrappedValue: ServerManagementViewModel(session: session))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            sidebarView
            contentView
        }
        .frame(minWidth: 800, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
        .background(ColorTokens.layer0)
        .onAppear {
            // Load real data when view appears using optimized batch commands
            Task {
                await viewModel.loadAllDataOptimized()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "server.rack")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                
                Text("Server Admin")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            
            // Navigation
            VStack(spacing: 4) {
                ForEach(ServerManagementTab.allCases) { tab in
                    HStack(spacing: 12) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 15))
                            .foregroundStyle(session.activeServerManagementTab == tab ? Color.white : ColorTokens.textSecondary)
                            .frame(width: 20)
                        
                        Text(tab.title)
                            .font(.system(size: 14, weight: session.activeServerManagementTab == tab ? .semibold : .regular))
                            .foregroundStyle(session.activeServerManagementTab == tab ? Color.white : ColorTokens.textSecondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(session.activeServerManagementTab == tab ? Color.white.opacity(0.12) : Color.white.opacity(0.01))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle()) // Essential for hit testing
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            session.activeServerManagementTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            // Bottom User/Connection Info
            VStack(alignment: .leading, spacing: 6) {
                Text("Connected as")
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("root@192.168.1.42")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            .padding(20)
        }
        .frame(width: 240)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 1),
            alignment: .trailing
        )
        .zIndex(10)
    }
    
    private var contentView: some View {
        ZStack {
            ColorTokens.layer0.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Content Header
                HStack {
                    Text(session.activeServerManagementTab.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Spacer()
                    
                    // Close Button
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ColorTokens.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(ColorTokens.layer2)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Close Server Management")
                }
                .padding(20)
                .background(ColorTokens.layer0)
                .overlay(
                    Divider()
                        .background(ColorTokens.borderSubtle),
                    alignment: .bottom
                )
                
                // Main Content Area
                Group {
                    switch session.activeServerManagementTab {
                    case .home:
                        ServerHomeView(viewModel: viewModel, onNavigateToApps: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                session.activeServerManagementTab = .applications
                            }
                        })
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    case .websites:
                        WebsitesListView(viewModel: viewModel)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    case .databases:
                        DatabasesListView(viewModel: viewModel)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    case .files:
                        FilesListView(viewModel: viewModel)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    case .applications:
                        ApplicationsManagementView(viewModel: viewModel)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    case .settings:
                        ServerSettingsView(viewModel: viewModel)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .id(session.activeServerManagementTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
