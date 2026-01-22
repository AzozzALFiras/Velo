import SwiftUI

struct PHPFPMProfileView: View {
    @ObservedObject var viewModel: PHPDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PHP-FPM Instances")
                .font(.subheadline)
                .foregroundStyle(.gray)
            
            if viewModel.isLoadingFPM {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if viewModel.fpmStatus.isEmpty {
                Text("No PHP-FPM instances found.")
                    .foregroundStyle(.gray)
            } else {
                ForEach(Array(viewModel.fpmStatus.keys.sorted()), id: \.self) { serviceName in
                    let isActive = viewModel.fpmStatus[serviceName] ?? false
                    
                    HStack {
                        Circle()
                            .fill(isActive ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        
                        Text(serviceName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text(isActive ? "Running" : "Stopped")
                            .font(.caption)
                            .foregroundStyle(isActive ? .green : .red)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}
