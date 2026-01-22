import SwiftUI

struct NginxConfigurationView: View {
    @ObservedObject var viewModel: NginxDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Global Configuration")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("These settings apply to the global nginx.conf file.")
                .font(.caption)
                .foregroundStyle(.gray)
            
            if viewModel.isLoadingConfig {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.configValues.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.gray)
                    Text("No editable configurations found.")
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(viewModel.configValues) { config in
                            EditableConfigRow(
                                title: config.displayName,
                                description: config.description,
                                value: config.value,
                                onSave: { newValue in
                                    Task {
                                        await viewModel.updateConfigValue(config.key, to: newValue)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.bottom)
                }
            }
        }
    }
}

// Reusing EditableConfigRow concept but specialized if needed, or inline
struct EditableConfigRow: View {
    let title: String
    let description: String
    let value: String
    let onSave: (String) -> Void
    
    @State private var isEditing = false
    @State private var editValue = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                if isEditing {
                    HStack(spacing: 8) {
                        TextField("Value", text: $editValue)
                            .textFieldStyle(.plain)
                            .padding(6)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(4)
                            .frame(width: 120)
                            .onSubmit {
                                onSave(editValue)
                                isEditing = false
                            }
                        
                        Button {
                            onSave(editValue)
                            isEditing = false
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            isEditing = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button {
                        editValue = value
                        isEditing = true
                    } label: {
                        Text(value)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }
}
