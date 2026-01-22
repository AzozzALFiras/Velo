import SwiftUI

struct NginxServiceView: View {
    @ObservedObject var viewModel: NginxDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            // Status Card
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Status")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(viewModel.isRunning ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                            .shadow(color: viewModel.isRunning ? .green : .red, radius: 4)
                        
                        Text(viewModel.isRunning ? "Running" : "Stopped")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 12) {
                    if viewModel.isRunning {
                        actionButton(title: "Stop", icon: "stop.fill", color: .red) {
                            await viewModel.stopService()
                        }
                    } else {
                        actionButton(title: "Start", icon: "play.fill", color: .green) {
                            await viewModel.startService()
                        }
                    }
                    
                    actionButton(title: "Restart", icon: "arrow.clockwise", color: .orange) {
                        await viewModel.restartService()
                    }
                    
                    actionButton(title: "Reload", icon: "arrow.triangle.2.circlepath", color: .blue) {
                        await viewModel.reloadService()
                    }
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            
            // Info Cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                infoCard(title: "Version", value: viewModel.version.isEmpty ? "Checking..." : viewModel.version, icon: "number")
                infoCard(title: "Binary Path", value: viewModel.binaryPath, icon: "terminal")
                infoCard(title: "Config Path", value: viewModel.configPath, icon: "doc.text")
                infoCard(title: "Available Versions", value: "\(viewModel.availableVersions.count)", icon: "square.stack.3d.up")
            }
            
            // Available Versions Section
            if !viewModel.availableVersions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Available Versions")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Spacer()
                    }
                    
                    ForEach(viewModel.availableVersions) { version in
                        versionRow(version: version)
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Components
    
    private func versionRow(version: CapabilityVersion) -> some View {
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
                        .background(stabilityColor(version.stability).opacity(0.2))
                        .foregroundStyle(stabilityColor(version.stability))
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
            
            let isInstalled = viewModel.version.contains(version.version)
            let isInstalling = viewModel.isInstallingVersion && viewModel.installingVersionName == version.version
            
            if isInstalled {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Installed")
                        .font(.caption)
                }
                .foregroundStyle(.green)
            } else if isInstalling {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text(viewModel.installStatus.isEmpty ? "Installing..." : viewModel.installStatus)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
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
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.8))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isInstallingVersion)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func stabilityColor(_ stability: String) -> Color {
        switch stability.lowercased() {
        case "stable": return .green
        case "mainline": return .blue
        case "legacy": return .orange
        default: return .gray
        }
    }
    
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () async -> Void) -> some View {
        Button {
            Task {
                await action()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isPerformingAction)
    }
    
    private func infoCard(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.green)
                .frame(width: 36, height: 36)
                .background(Color.green.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.gray)
                
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

