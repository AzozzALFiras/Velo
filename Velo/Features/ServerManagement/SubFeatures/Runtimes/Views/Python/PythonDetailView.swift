import SwiftUI

struct PythonDetailView: View {
    @StateObject var viewModel: PythonDetailViewModel
    
    init(session: TerminalViewModel?) {
        _viewModel = StateObject(wrappedValue: PythonDetailViewModel(session: session))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "terminal") // Placeholder icon
                    .font(.system(size: 32))
                    .foregroundStyle(.yellow)
                
                VStack(alignment: .leading) {
                    Text("Python")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(viewModel.version)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            if viewModel.installedEnvironments.isEmpty {
                VStack {
                    Text("No Python environments active")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.installedEnvironments) { env in
                        Section("Global Environment (\(env.path))") {
                            ForEach(env.packages) { pkg in
                                HStack {
                                    Text(pkg.name)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(pkg.version)
                                        .foregroundStyle(.secondary)
                                        .font(.monospacedDigit(.body)())
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            Task { await viewModel.loadData() }
        }
    }
}
