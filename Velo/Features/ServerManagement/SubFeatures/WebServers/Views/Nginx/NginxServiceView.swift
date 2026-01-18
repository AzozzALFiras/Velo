import SwiftUI

struct NginxServiceView: View {
    @ObservedObject var viewModel: NginxDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            // Status Header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nginx Web Server")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text(viewModel.version.isEmpty ? "Checking version..." : viewModel.version)
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                statusBadge(isRunning: viewModel.isRunning)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            // Actions
            HStack(spacing: 16) {
                if viewModel.isRunning {
                    actionButton(title: "Restart", icon: "arrow.clockwise", color: .orange) {
                        Task { await viewModel.restartService() }
                    }
                    
                    actionButton(title: "Reload", icon: "arrow.triangle.2.circlepath", color: .blue) {
                        Task { await viewModel.reloadService() }
                    }
                    
                    actionButton(title: "Stop", icon: "stop.fill", color: .red) {
                        Task { await viewModel.stopService() }
                    }
                } else {
                    actionButton(title: "Start Service", icon: "play.fill", color: .green) {
                        Task { await viewModel.startService() }
                    }
                }
            }
            .disabled(viewModel.isPerformingAction)
            
            if viewModel.isPerformingAction {
                ProgressView()
                    .padding(.top)
            }
            
            
            // Available Versions
            if !viewModel.availableVersions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Versions")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    ForEach(viewModel.availableVersions) { version in
                        NginxVersionRow(version: version, viewModel: viewModel)
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Spacer()
            
            // Process Info (Placeholder mostly, or could list PID)
            VStack(alignment: .leading, spacing: 16) {
                Text("Process Information")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                NginxInfoRow(label: "Binary Path", value: viewModel.binaryPath)
                NginxInfoRow(label: "Config Path", value: viewModel.configPath)
            }
            .padding()
            .background(Color.white.opacity(0.02))
            .cornerRadius(12)
        }
    }
    
    func statusBadge(isRunning: Bool) -> some View {
        HStack {
            Circle()
                .fill(isRunning ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isRunning ? "Running" : "Stopped")
                .font(.headline)
                .foregroundStyle(isRunning ? .green : .red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isRunning ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .clipShape(Capsule())
    }
    
    func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct NginxVersionRow: View {
    let version: CapabilityVersion
    @ObservedObject var viewModel: NginxDetailViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Nginx \(version.version)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    
                    Text(version.stability)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(version.stability == "Stable" ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                        .foregroundStyle(version.stability == "Stable" ? .green : .blue)
                        .clipShape(Capsule())
                    
                    if version.isDefault {
                        Text("Recommended")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
            }
            
            Spacer()
            
            // Heuristic check for installed version
            if viewModel.version.contains(version.version) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Installed")
                        .font(.caption)
                }
                .foregroundStyle(.green)
            } else if viewModel.isInstallingVersion && viewModel.installingVersionName == version.version {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(viewModel.installStatus.isEmpty ? "Installing..." : viewModel.installStatus)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } else {
                Button {
                    Task {
                        await viewModel.installVersion(version)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                        .font(.system(size: 10))
                        Text("Install")
                        .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.8))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isInstallingVersion || viewModel.isPerformingAction)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

private struct NginxInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.gray)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
    }
}
