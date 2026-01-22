import SwiftUI

struct NodeDetailView: View {
    @StateObject var viewModel: NodeDetailViewModel
    
    init(session: TerminalViewModel?) {
        _viewModel = StateObject(wrappedValue: NodeDetailViewModel(session: session))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "hexagon.fill") // Placeholder icon
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading) {
                    Text("Node.js")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("\(viewModel.version) (npm: \(viewModel.npmVersion))")
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
            if viewModel.globalPackages.isEmpty {
                VStack {
                    Text("No global NPM packages found")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Global Packages") {
                        ForEach(viewModel.globalPackages) { pkg in
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
        .onAppear {
            Task { await viewModel.loadData() }
        }
    }
}
