//
//  TrafficChartView.swift
//  Velo
//
//  Component: Network Traffic Chart
//  Matches design with Line/Area chart for Up/Down traffic.
//

import SwiftUI
import Charts

struct TrafficChartView: View {
    
    let history: [TrafficPoint]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network Traffic")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.orange).frame(width: 6, height: 6)
                            Text("5.52 Gbps In")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        HStack(spacing: 4) {
                            Circle().fill(Color.purple).frame(width: 6, height: 6)
                            Text("2.11 Gbps Out")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                Spacer()
                
                // Action Menu
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())
            }
            .padding(24)
            
            // Chart
            Chart(history) { point in
                // Downstream (Orange)
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("KB", point.downstreamKB)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.6), Color.orange.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("KB", point.downstreamKB)
                )
                .foregroundStyle(Color.orange)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
                
                // Upstream (Purple)
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("KB", point.upstreamKB)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.6), Color.purple.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("KB", point.upstreamKB)
                )
                .foregroundStyle(Color.purple)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(height: 180)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(
            Color.black.opacity(0.6)
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.02)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
        )
    }
}
