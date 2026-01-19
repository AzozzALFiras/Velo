import SwiftUI

struct PostgreSQLDetailView: View {
    @ObservedObject var viewModel: PostgresDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        HStack(spacing: 0) {
            // Reusing MySQLSidebarView approach or creating generic Sidebar
            // For now, simple list
            VStack {
                Text("PostgreSQL")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                List {
                    Button("Service") { viewModel.selectedSection = .service }
                    Button("Configuration") { viewModel.selectedSection = .configuration }
                    Button("Users") { viewModel.selectedSection = .users }
                    Button("Logs") { viewModel.selectedSection = .logs }
                }
                .listStyle(.sidebar)
            }
            .frame(width: 250)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            VStack {
                switch viewModel.selectedSection {
                case .service:
                    Text("Service Status: \(viewModel.isRunning ? "Running" : "Stopped")")
                        .font(.largeTitle)
                case .configuration:
                    if viewModel.isLoadingConfig {
                        ProgressView()
                    } else {
                        List(viewModel.configValues) { config in
                            HStack {
                                Text(config.displayName)
                                Spacer()
                                Text(config.value).foregroundStyle(.secondary)
                            }
                        }
                    }
                case .users:
                    List(viewModel.users) { user in
                        Text(user.username)
                    }
                case .logs:
                    ScrollView {
                        Text(viewModel.logContent)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                default:
                    Text("Section not implemented")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            Task { await viewModel.loadData() }
        }
    }
}
