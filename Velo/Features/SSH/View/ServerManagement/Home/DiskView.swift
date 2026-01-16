//
//  DiskView.swift
//  Velo
//
//  Component: Disk Usage
//  Linear bars for root/tmp and radial chart.
//

import SwiftUI

struct DiskView: View {
    
    let stats: ServerStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Disk Usage", systemImage: "internaldrive")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
            }
            
            VStack(spacing: 20) {
                StorageRow(
                    label: "Main Drive (/)",
                    percentage: stats.diskUsage,
                    used: "1.16 TB",
                    total: "6.85 TB",
                    color: .green
                )
                
                StorageRow(
                    label: "Temp (/tmp)",
                    percentage: 0.01,
                    used: "51.2 GB",
                    total: "54.0 GB",
                    color: .purple
                )
            }
            
            Spacer(minLength: 0)
        }
        .padding(24)
        .background(
            Color.black.opacity(0.6)
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.15), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
        )
    }
}

private struct StorageRow: View {
    let label: String
    let percentage: Double
    let used: String
    let total: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("\(Int(percentage * 100))%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(
                            LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * percentage, height: 6)
                        .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 6)
            
            HStack {
                Text(used)
                    .foregroundStyle(.white.opacity(0.7))
                Text("/")
                    .foregroundStyle(.white.opacity(0.3))
                Text(total)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .font(.system(size: 11))
        }
    }
}
