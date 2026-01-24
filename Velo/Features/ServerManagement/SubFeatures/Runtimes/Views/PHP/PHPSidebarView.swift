import SwiftUI

struct PHPSidebarView: View {
    @ObservedObject var viewModel: PHPDetailViewModel
    var onDismiss: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // PHP Icon
                SoftwareIconView(
                    iconURL: viewModel.capabilityIcon ?? "",
                    slug: "php",
                    color: .purple,
                    size: 32
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("php.version".localized(viewModel.activeVersion))
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isRunning ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(viewModel.isRunning ? "php.status.running".localized : "php.status.stopped".localized)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                
                Spacer()
                
                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.black.opacity(0.3))
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Navigation Items
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(PHPDetailSection.allCases) { section in
                        sidebarButton(for: section)
                    }
                }
                .padding(12)
            }
            
            Spacer()
            
            // Version Switcher
            versionSwitcherView
        }
        .frame(width: 220)
        .background(Color.black.opacity(0.4))
    }
    
    private func sidebarButton(for section: PHPDetailSection) -> some View {
        Button {
            viewModel.selectedSection = section
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(viewModel.selectedSection == section ? .white : .gray)
                    .frame(width: 20)
                
                Text(section.rawValue)
                    .font(.system(size: 13, weight: viewModel.selectedSection == section ? .semibold : .regular))
                    .foregroundStyle(viewModel.selectedSection == section ? .white : .gray)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                viewModel.selectedSection == section
                    ? Color.purple.opacity(0.3)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Version Switcher
    
    private var versionSwitcherView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Installed Versions")
                .font(.caption)
                .foregroundStyle(.gray)
            
            ForEach(viewModel.installedVersions, id: \.self) { version in
                HStack {
                    Text("PHP \(version)")
                        .font(.system(size: 12, weight: version == viewModel.activeVersion ? .bold : .regular))
                        .foregroundStyle(version == viewModel.activeVersion ? .green : .white)
                    
                    Spacer()
                    
                    if version == viewModel.activeVersion {
                        Text("Active")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    } else {
                        Button("php.version.switch".localized) {
                            Task {
                                await viewModel.switchVersion(to: version)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
    }
}
