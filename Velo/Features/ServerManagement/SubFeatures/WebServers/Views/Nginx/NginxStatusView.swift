import SwiftUI

struct NginxStatusView: View {
    @ObservedObject var viewModel: NginxDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Nginx Status")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    Task {
                        await viewModel.loadStatusMetrics()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoadingStatus)
            }
            
            if viewModel.isLoadingStatus {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let status = viewModel.statusInfo {
                ScrollView {
                    VStack(spacing: 16) {
                        // Main metric: Active Connections
                        VStack(spacing: 8) {
                            Text("\(status.activeConnections)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                            Text("Active Connections")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                        
                        // Detailed metrics grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            StatusCard(title: "Accepts", value: "\(status.accepts)")
                            StatusCard(title: "Handled", value: "\(status.handled)")
                            StatusCard(title: "Requests", value: "\(status.requests)")
                            
                            StatusCard(title: "Reading", value: "\(status.reading)")
                            StatusCard(title: "Writing", value: "\(status.writing)")
                            StatusCard(title: "Waiting", value: "\(status.waiting)")
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.largeTitle)
                        .foregroundStyle(.gray)
                    Text("Status metrics not available.")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Ensure 'stub_status' module is enabled and configured on 127.0.0.1.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.blue)
            Text(title)
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
}
