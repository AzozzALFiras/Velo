import SwiftUI

struct PHPLogsView: View {
    @ObservedObject var viewModel: PHPDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PHP Error Logs")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                
                Spacer()
                
                Button {
                    Task {
                        await viewModel.loadSectionData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            
            if viewModel.isLoadingLogs {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    Text(viewModel.logContent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(minHeight: 300)
            }
        }
    }
}
