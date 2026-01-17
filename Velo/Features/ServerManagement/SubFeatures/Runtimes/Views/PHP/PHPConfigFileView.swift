import SwiftUI

struct PHPConfigFileView: View {
    @ObservedObject var viewModel: PHPDetailViewModel
    
    @State private var showConfigEditor = false
    @State private var editableConfigContent = ""
    @State private var showingFullFile = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.configPath)
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    if !viewModel.configFileContent.isEmpty {
                        let lineCount = viewModel.configFileContent.components(separatedBy: "\n").count
                        HStack(spacing: 8) {
                            Text("\(lineCount) active directives")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            
                            if !showingFullFile {
                                Text("(comments hidden)")
                                    .font(.caption2)
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Toggle full file
                    Button {
                        Task {
                            showingFullFile.toggle()
                            if showingFullFile {
                                await viewModel.loadFullConfigFile()
                            } else {
                                await viewModel.loadConfigFile()
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showingFullFile ? "eye.slash" : "eye")
                            Text(showingFullFile ? "Hide Comments" : "Show Full")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    
                    if !viewModel.configFileContent.isEmpty {
                        Button {
                            editableConfigContent = viewModel.configFileContent
                            showConfigEditor = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil.and.outline")
                                Text("Edit")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            if viewModel.isLoadingConfigFile {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(showingFullFile ? "Loading full config file..." : "Loading active directives...")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 60)
            } else if viewModel.configFileContent.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray.opacity(0.5))
                    Text("No active configuration found.")
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 60)
            } else {
                // Use ScrollView + Text for the filtered content
                ScrollView {
                    Text(viewModel.configFileContent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.9))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(height: 400)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .sheet(isPresented: $showConfigEditor) {
            configEditorSheet
        }
    }
    
    // MARK: - Components
    
    private var configEditorSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Edit php.ini")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(viewModel.configPath)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showConfigEditor = false
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.gray)
                    
                    Button {
                        Task {
                            viewModel.configFileContent = editableConfigContent
                            let success = await viewModel.saveConfigFile()
                            if success {
                                showConfigEditor = false
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isSavingConfigFile {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text("Save & Reload")
                        }
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSavingConfigFile)
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            
            // Editor
            NativeEditableTextView(text: $editableConfigContent)
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(red: 0.08, green: 0.08, blue: 0.1))
    }
}
