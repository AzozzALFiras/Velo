import SwiftUI

struct MySQLSidebarView: View {
    @ObservedObject var viewModel: MySQLDetailViewModel
    var onDismiss: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Icon
                if let iconURL = viewModel.capabilityIcon, let url = URL(string: iconURL) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "cylinder.split.1x2.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "cylinder.split.1x2.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                        .frame(width: 32, height: 32)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("MySQL \(viewModel.version)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isRunning ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(viewModel.isRunning ? "Running" : "Stopped")
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
                    ForEach(MySQLDetailSection.allCases) { section in
                        sidebarButton(for: section)
                    }
                }
                .padding(12)
            }
            
            Spacer()
            
            // Version Switcher (Installed Versions)
            versionSwitcherView
        }
        .frame(width: 220)
        .background(Color.black.opacity(0.4))
    }
    
    private func sidebarButton(for section: MySQLDetailSection) -> some View {
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
                    ? Color.blue.opacity(0.3)
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
                    Text("MySQL \(version)")
                        .font(.system(size: 12, weight: version == viewModel.version ? .bold : .regular))
                        .foregroundStyle(version == viewModel.version ? .green : .white)
                    
                    Spacer()
                    
                    if version == viewModel.version {
                        Text("Active")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
    }
}
