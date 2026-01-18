import SwiftUI

struct MySQLServiceView: View {
    @ObservedObject var viewModel: MySQLDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            // Status Card
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Service Status")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    HStack(spacing: 12) {
                        Circle()
                            .fill(viewModel.isRunning ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                            .shadow(color: (viewModel.isRunning ? Color.green : Color.red).opacity(0.3), radius: 4)
                        
                        Text(viewModel.isRunning ? "Active (running)" : "Inactive (dead)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 12) {
                    serviceActionButton(
                        title: viewModel.isRunning ? "Restart" : "Start",
                        icon: viewModel.isRunning ? "arrow.clockwise" : "play.fill",
                        color: .blue
                    ) {
                        if viewModel.isRunning {
                            await viewModel.restartService()
                        } else {
                            await viewModel.startService()
                        }
                    }
                    
                    if viewModel.isRunning {
                        serviceActionButton(title: "Stop", icon: "stop.fill", color: .red) {
                            await viewModel.stopService()
                        }
                    }
                }
            }
            .padding(24)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Service Info
            VStack(alignment: .leading, spacing: 16) {
                Text("Service Information")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                VStack(spacing: 1) {
                    MySQLInfoRow(label: "Version", value: viewModel.version)
                    MySQLInfoRow(label: "Main Config", value: viewModel.configPath)
                    MySQLInfoRow(label: "Process Name", value: "mysqld")
                    MySQLInfoRow(label: "Uptime", value: viewModel.statusInfo.uptime)
                }
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private func serviceActionButton(title: String, icon: String, color: Color, action: @escaping () async -> Void) -> some View {
        Button {
            Task {
                await action()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct MySQLInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.01))
    }
}
