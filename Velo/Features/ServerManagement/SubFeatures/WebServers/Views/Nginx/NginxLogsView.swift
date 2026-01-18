import SwiftUI

struct NginxLogsView: View {
    @ObservedObject var viewModel: NginxDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Error Logs")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    Task {
                        await viewModel.loadLogs()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoadingLogs)
            }
            
            if viewModel.isLoadingLogs {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(viewModel.logContent.isEmpty ? "No logs available." : viewModel.logContent)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                }
            }
        }
    }
}
