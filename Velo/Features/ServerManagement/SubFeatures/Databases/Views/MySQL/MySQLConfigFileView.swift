import SwiftUI

struct MySQLConfigFileView: View {
    @ObservedObject var viewModel: MySQLDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Editing my.cnf")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(viewModel.configPath)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.gray)
                .padding(.trailing, 12)
                
                Button {
                    Task {
                        let success = await viewModel.saveConfigFile()
                        if success { dismiss() }
                    }
                } label: {
                    if viewModel.isSavingConfigFile {
                        ProgressView().scaleEffect(0.6).tint(.white)
                    } else {
                        Text("Save")
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSavingConfigFile)
            }
            .padding(20)
            .background(Color.white.opacity(0.05))
            
            Divider().background(Color.white.opacity(0.1))
            
            // Editor
            ZStack {
                if viewModel.isLoadingConfigFile {
                    ProgressView("Loading config...").tint(.white)
                } else {
                    TextEditor(text: $viewModel.configFileContent)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(Color(red: 0.08, green: 0.08, blue: 0.1))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        .task {
            await viewModel.loadConfigFile()
        }
    }
}
