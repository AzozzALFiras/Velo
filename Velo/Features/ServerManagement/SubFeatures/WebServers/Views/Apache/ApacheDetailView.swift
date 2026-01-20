
import SwiftUI

struct ApacheDetailView: View {
    @StateObject private var viewModel: ApacheDetailViewModel
    var onDismiss: () -> Void
    
    init(session: TerminalViewModel?, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: ApacheDetailViewModel(session: session))
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Dark overlay to close
            Color.black.opacity(0.4)
                .onTapGesture {
                    onDismiss()
                }
            
            // Sidebar Content
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "server.rack")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .frame(width: 32, height: 32)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Text("Apache")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Service Control
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Service Status")
                                .font(.headline)
                            
                            HStack {
                                StatusIndicator(isRunning: viewModel.isRunning)
                                
                                Spacer()
                                
                                Button("Start") {
                                    Task { await viewModel.startService() }
                                }
                                .disabled(viewModel.isRunning || viewModel.isPerformingAction)
                                
                                Button("Stop") {
                                    Task { await viewModel.stopService() }
                                }
                                .disabled(!viewModel.isRunning || viewModel.isPerformingAction)
                                
                                Button("Restart") {
                                    Task { await viewModel.restartService() }
                                }
                                .disabled(viewModel.isPerformingAction)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                        }
                        
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        if let success = viewModel.successMessage {
                            Text(success)
                                .foregroundStyle(.green)
                                .font(.caption)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
            .frame(width: 400)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .task {
            await viewModel.loadStatus()
        }
    }
}

struct StatusIndicator: View {
    let isRunning: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(isRunning ? Color.green : Color.red)
                .frame(width: 10, height: 10)
             Text(isRunning ? "Running" : "Stopped")
                .foregroundStyle(isRunning ? .green : .red)
        }
    }
}
