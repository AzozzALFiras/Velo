import SwiftUI

struct MySQLLogsView: View {
    @ObservedObject var viewModel: MySQLDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Header
            HStack {
                Text("Error Logs")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    Task { await viewModel.loadLogs() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
            }
            
            // Log Content
            ZStack {
                if viewModel.isLoadingLogs {
                    ProgressView().tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if viewModel.logContent.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.gray.opacity(0.3))
                        Text("No logs found.")
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    ScrollView {
                        Text(viewModel.logContent)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxHeight: 500)
                }
            }
        }
        .task {
            await viewModel.loadLogs()
        }
    }
}
