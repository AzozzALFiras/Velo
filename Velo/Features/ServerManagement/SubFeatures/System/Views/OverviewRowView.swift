//
//  OverviewRowView.swift
//  Velo
//
//  Component: Overview Counts (Site, FTP, DB, Security)
//  Horizontal layout.
//

import SwiftUI

struct OverviewRowView: View {
    
    let counts: OverviewCounts
    
    var body: some View {
        HStack(spacing: 16) {
            StatChip(icon: "network", label: "Sites", value: "\(counts.sites)", color: .blue)
            StatChip(icon: "server.rack", label: "Databases", value: "\(counts.databases)", color: .purple)
            StatChip(icon: "arrow.down.circle", label: "FTP", value: "\(counts.ftp)", color: .orange)
            StatChip(icon: "shield.lefthalf.filled", label: "Security", value: "\(counts.security)", color: .red)
        }
    }
}

private struct StatChip: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [color.opacity(0.2), color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            Color.black.opacity(0.4)
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
