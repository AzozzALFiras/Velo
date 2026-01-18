//
//  ServerDashboardView.swift
//  Velo
//
//  Dashboard Tab for Server Management
//  Displays visuals for CPU, RAM, Disk usage and system info.
//

import SwiftUI
import Charts

struct ServerHomeView: View {
    
    @ObservedObject var viewModel: ServerManagementViewModel
    var onNavigateToApps: () -> Void
    
    // State for navigation
    @State private var showPHPDetail = false
    @State private var showNginxDetail = false
    @State private var showMySQLDetail = false
    @State private var selectedSoftware: InstalledSoftware? = nil
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header with Refresh Button
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.serverHostname)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text(viewModel.serverIP)
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        
                        Spacer()
                        
                        Button {
                            viewModel.refreshData()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.horizontal, 8)
                    
                    // Top Row: Stats
                    HStack(alignment: .top, spacing: 24) {
                        SysStatusView(stats: viewModel.stats)
                            .frame(maxWidth: .infinity)
                        
                        DiskView(stats: viewModel.stats)
                            .frame(width: 320)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    
                    // Overview
                    OverviewRowView(counts: viewModel.overviewCounts)
                    
                    // Bottom
                    HStack(alignment: .top, spacing: 24) {
                        SoftwareGridView(
                            softwareList: viewModel.installedSoftware,
                            onAddTap: onNavigateToApps,
                            onSoftwareTap: { software in
                                handleSoftwareTap(software)
                            }
                        )
                        .frame(width: 340)
                        
                        TrafficChartView(history: viewModel.trafficHistory)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(32)
            }
            
            // Loading Overlay
            if viewModel.isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Loading server data...")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    )
            }
        }
        // Deep modern background
        .background(
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08) // Deep dark blue-black
                
                // Ambient Blurs
                GeometryReader { geo in
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 600, height: 600)
                        .blur(radius: 120)
                        .position(x: 0, y: 0)
                    
                    Circle()
                        .fill(Color.purple.opacity(0.08))
                        .frame(width: 500, height: 500)
                        .blur(radius: 100)
                        .position(x: geo.size.width, y: geo.size.height)
                }
            }
            .ignoresSafeArea()
        )
        .overlay {
            if showPHPDetail {
                PHPDetailView(session: viewModel.session, onDismiss: {
                    showPHPDetail = false
                })
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(100)
            }
            
            if showNginxDetail {
                NginxDetailView(session: viewModel.session, onDismiss: {
                    showNginxDetail = false
                })
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(101)
            }
            
            if showMySQLDetail {
                MySQLDetailView(session: viewModel.session, onDismiss: {
                    showMySQLDetail = false
                })
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(102)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showPHPDetail)
        .animation(.easeInOut(duration: 0.25), value: showNginxDetail)
        .animation(.easeInOut(duration: 0.25), value: showMySQLDetail)
    }
    
    // MARK: - Helpers
    
    private func handleSoftwareTap(_ software: InstalledSoftware) {
        selectedSoftware = software
        
        // Determine which detail view to show based on software name
        switch software.name.lowercased() {
        case "php":
            showPHPDetail = true
        case "nginx":
            showNginxDetail = true
        case "mysql", "mariadb":
            showMySQLDetail = true
        default:
            // No detail view found
            print("No detail view for \(software.name)")
        }
    }
}



// MARK: - Legacy / Unused
// Deleted SystemInfoHeader and UsageCard as they are replaced by new components.

private struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            Spacer()
        }
        .padding()
        .background(ColorTokens.layer1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(ColorTokens.borderSubtle, lineWidth: 1)
        )
    }
}
