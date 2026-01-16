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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
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
                    SoftwareGridView(softwareList: viewModel.installedSoftware)
                        .frame(width: 340)
                    
                    TrafficChartView(history: viewModel.trafficHistory)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(32)
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
