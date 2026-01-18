import SwiftUI

struct NginxSidebarView: View {
    @ObservedObject var viewModel: NginxDetailViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "server.rack") // Or use an nginx icon if available
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nginx")
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
            }
            .padding(20)
            .background(Color.white.opacity(0.03))
            
            Divider().background(Color.white.opacity(0.1))
            
            // Menu
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(NginxDetailSection.allCases) { section in
                        Button {
                            viewModel.selectedSection = section
                            Task {
                                await viewModel.loadSectionData()
                            }
                        } label: {
                            HStack {
                                Image(systemName: section.icon)
                                    .frame(width: 24)
                                
                                Text(section.rawValue)
                                    .font(.system(size: 14))
                                
                                Spacer()
                                
                                if viewModel.selectedSection == section {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .foregroundStyle(viewModel.selectedSection == section ? Color.white : Color.gray)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(viewModel.selectedSection == section ? Color.green.opacity(0.15) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }
}
