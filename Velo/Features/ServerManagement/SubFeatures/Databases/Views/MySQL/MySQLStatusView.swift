import SwiftUI

struct MySQLStatusView: View {
    @ObservedObject var viewModel: MySQLDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            // Header with Refresh
            HStack {
                Text("Performance Metrics")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    Task { await viewModel.loadStatusInfo() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            
            if viewModel.isLoadingStatus {
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
                .padding(40)
            } else {
                // Metrics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    MetricCard(title: "Uptime", value: viewModel.statusInfo.uptime, icon: "clock.fill", color: .green)
                    MetricCard(title: "Connections", value: viewModel.statusInfo.threadsConnected, icon: "person.2.fill", color: .blue)
                    MetricCard(title: "Questions", value: viewModel.statusInfo.questions, icon: "questionmark.circle.fill", color: .purple)
                    MetricCard(title: "Slow Queries", value: viewModel.statusInfo.slowQueries, icon: "tortoise.fill", color: .orange)
                    MetricCard(title: "Open Tables", value: viewModel.statusInfo.openTables, icon: "tablecells.fill", color: .cyan)
                    MetricCard(title: "Queries / sec", value: viewModel.statusInfo.qps, icon: "bolt.fill", color: .yellow)
                }
            }
        }
        .task {
            await viewModel.loadStatusInfo()
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 16))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
