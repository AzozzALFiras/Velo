import SwiftUI

struct MySQLConfigurationView: View {
    @ObservedObject var viewModel: MySQLDetailViewModel
    @State private var showingFileEditor = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            // Edit Full Config Button
            Button {
                showingFileEditor = true
            } label: {
                HStack {
                    Image(systemName: "doc.text.fill")
                    Text("Edit my.cnf File")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            
            // Common Settings
            VStack(alignment: .leading, spacing: 16) {
                Text("Common Settings")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                if viewModel.isLoadingConfig {
                    HStack {
                        Spacer()
                        ProgressView().tint(.white)
                        Spacer()
                    }
                    .padding()
                } else if viewModel.configValues.isEmpty {
                    Text("No common settings detected automatically.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .padding()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.configValues) { config in
                            MySQLConfigRow(config: config)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingFileEditor) {
            MySQLConfigFileView(viewModel: viewModel)
        }
    }
}

private struct MySQLConfigRow: View {
    let config: SharedConfigValue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Text(config.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                Text(config.value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
