import SwiftUI

struct PHPInfoView: View {
    @ObservedObject var viewModel: PHPDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if viewModel.isLoadingPHPInfo {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading PHP Information...")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 60)
            } else if viewModel.phpInfoData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray.opacity(0.5))
                    Text("No PHP information available.")
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 60)
            } else {
                // System Info Card
                phpInfoCard(title: "System Information", icon: "desktopcomputer", items: [
                    ("PHP Version", viewModel.phpInfoData["PHP Version"] ?? viewModel.activeVersion),
                    ("System", viewModel.phpInfoData["System"] ?? "Unknown"),
                    ("Server API", viewModel.phpInfoData["Server API"] ?? "CLI"),
                    ("PHP API", viewModel.phpInfoData["PHP API"] ?? "-"),
                ])
                
                // Build Info Card
                phpInfoCard(title: "Build Information", icon: "hammer", items: [
                    ("Build Date", viewModel.phpInfoData["Build Date"] ?? "-"),
                    ("Build System", viewModel.phpInfoData["Build System"] ?? "-"),
                    ("Build Provider", viewModel.phpInfoData["Build Provider"] ?? "-"),
                    ("Configure Command", viewModel.phpInfoData["Configure Command"]?.prefix(50).description ?? "-"),
                ])
                
                // Configuration Card
                phpInfoCard(title: "Configuration Paths", icon: "folder", items: [
                    ("Configuration File (php.ini) Path", viewModel.phpInfoData["Configuration File (php.ini) Path"] ?? "-"),
                    ("Loaded Configuration File", viewModel.phpInfoData["Loaded Configuration File"] ?? viewModel.configPath),
                    ("Scan this dir for .ini files", viewModel.phpInfoData["Scan this dir for additional .ini files"] ?? "-"),
                ])
                
                // Virtual Directory Support
                phpInfoCard(title: "Features", icon: "checkmark.seal", items: [
                    ("Virtual Directory Support", viewModel.phpInfoData["Virtual Directory Support"] ?? "disabled"),
                    ("Zend Memory Manager", viewModel.phpInfoData["Zend Memory Manager"] ?? "enabled"),
                    ("Thread Safety", viewModel.phpInfoData["Thread Safety"] ?? "-"),
                    ("Debug Build", viewModel.phpInfoData["Debug Build"] ?? "no"),
                ])
                
                // Show Raw Output Toggle
                DisclosureGroup("Raw Output") {
                    ScrollView {
                        Text(viewModel.phpInfoHTML)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 200)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
            }
        }
    }
    
    // MARK: - Components
    
    private func phpInfoCard(title: String, icon: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            // Items
            VStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    HStack(alignment: .top) {
                        Text(item.0)
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)
                            .frame(width: 180, alignment: .leading)
                        
                        Text(item.1)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .textSelection(.enabled)
                        
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
