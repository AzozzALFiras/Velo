//
//  SysStatusView.swift
//  Velo
//
//  Component: System Status (CPU, Load, RAM)
//  Matches specific dashboard design with circular gauges.
//

import SwiftUI

struct SysStatusView: View {
    
    let stats: ServerStats
    
    // Mock "Load" for visual parity with design
    let loadValue: Double = 0.1
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Sys Status")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
            
            HStack(spacing: 0) {
                // CPU Ring
                StatusRing(
                    value: stats.cpuUsage,
                    label: "CPU Load",
                    valueText: String(format: "%.0f%%", stats.cpuUsage * 100),
                    color: .cyan
                )
                
                Spacer()
                
                StatusRing(
                    value: stats.ramUsage, // Mock value usage
                    label: "RAM Usage",
                    valueText: String(format: "%.1f GB", 16.0 * stats.ramUsage), // Mock
                    subText: "/ 16 GB",
                    color: .blue
                )
                
                Spacer()
                
                StatusRing(
                    value: 0.25, // Mock Load
                    label: "System Load",
                    valueText: "0.25",
                    subText: "/ 0.45",
                    color: .indigo
                )
            }
            .padding(.top, 10)
        }
        .padding(24)
        .background(
            ZStack {
                Color.black.opacity(0.6)
                // Subtle gradient glow behind
                RadialGradient(colors: [Color.blue.opacity(0.15), Color.clear], center: .center, startRadius: 0, endRadius: 200)
            }
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
    }
}

private struct StatusRing: View {
    let value: Double
    let label: String
    let valueText: String
    var subText: String? = nil
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(color.opacity(0.1), lineWidth: 8)
                    .frame(width: 90, height: 90)
                
                // Progress
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(
                        AngularGradient(colors: [color.opacity(0.5), color], center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 90, height: 90)
                    .shadow(color: color.opacity(0.5), radius: 10, x: 0, y: 0) // Neon Glow
                
                VStack(spacing: 2) {
                    Text(valueText)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    
                    if let sub = subText {
                        Text(sub)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}
