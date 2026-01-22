import SwiftUI

struct NginxConfigFileView: View {
    @ObservedObject var viewModel: NginxDetailViewModel
    @State private var isEditing = false
    @State private var editedContent = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("nginx.conf")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text(viewModel.configPath)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                Button {
                    isEditing = true
                    editedContent = viewModel.configFileContent
                } label: {
                    Label("Edit File", systemImage: "pencil")
                }
                .buttonStyle(NginxPrimaryButtonStyle())
                .disabled(viewModel.isLoadingConfigFile)
            }
            .padding(.bottom)
            
            if viewModel.isLoadingConfigFile {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(viewModel.configFileContent)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") {
                        isEditing = false
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    
                    Spacer()
                    
                    Text("Editing nginx.conf")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button("Save") {
                        viewModel.configFileContent = editedContent
                        Task {
                            let success = await viewModel.saveConfigFile()
                            if success {
                                isEditing = false
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .disabled(viewModel.isSavingConfig)
                }
                .padding()
                .background(Color(red: 0.1, green: 0.1, blue: 0.15))
                
                if viewModel.isSavingConfig {
                    ProgressView().padding()
                }
                
                TextEditor(text: $editedContent)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white) // Ensure text is visible
                    .scrollContentBackground(.hidden)
                    .background(Color(red: 0.05, green: 0.05, blue: 0.08))
                    .padding()
            }
            #if os(macOS)
            .frame(minWidth: 600, minHeight: 400)
            #endif
        }
    }
}

struct NginxPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
