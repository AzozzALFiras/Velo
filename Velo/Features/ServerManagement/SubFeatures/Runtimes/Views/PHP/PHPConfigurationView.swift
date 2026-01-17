import SwiftUI

struct PHPConfigurationView: View {
    @ObservedObject var viewModel: PHPDetailViewModel
    
    // We handle .configuration, .uploadLimits, .timeouts here
    // Based on viewModel.selectedSection
    
    @State private var editingConfigKey: String? = nil
    @State private var editingConfigValue: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            if viewModel.selectedSection == .configuration {
                headerWithEditHint("PHP Configuration")
                if viewModel.isLoadingConfig {
                    loadingView
                } else {
                    ForEach(viewModel.configValues) { config in
                        editableConfigRow(config)
                    }
                }
            } else if viewModel.selectedSection == .uploadLimits {
                // Filter upload limits
                let uploadConfigs = viewModel.configValues.filter { config in
                    ["upload_max_filesize", "post_max_size", "max_file_uploads"].contains(config.key)
                }
                
                headerWithEditHint("Upload Limits")
                
                if viewModel.isLoadingConfig {
                    loadingView
                } else if uploadConfigs.isEmpty {
                    emptyState("No upload limit configurations found.")
                } else {
                    ForEach(uploadConfigs) { config in
                        editableConfigRow(config)
                    }
                }
            } else if viewModel.selectedSection == .timeouts {
                // Filter timeouts
                let timeoutConfigs = viewModel.configValues.filter { config in
                    ["max_execution_time", "max_input_time"].contains(config.key)
                }
                
                headerWithEditHint("Timeouts")
                
                if viewModel.isLoadingConfig {
                    loadingView
                } else if timeoutConfigs.isEmpty {
                    emptyState("No timeout configurations found.")
                } else {
                    ForEach(timeoutConfigs) { config in
                        editableConfigRow(config)
                    }
                }
            }
        }
    }
    
    // MARK: - Components
    
    private func headerWithEditHint(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.gray)
            
            Spacer()
            
            Text("Click value to edit")
                .font(.caption)
                .foregroundStyle(.orange.opacity(0.8))
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func emptyState(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(.gray)
    }
    
    private func editableConfigRow(_ config: PHPConfigValue) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(config.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                
                Text(config.description)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            if editingConfigKey == config.key {
                // Editing mode
                HStack(spacing: 8) {
                    TextField("Value", text: $editingConfigValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(width: 120)
                        .background(Color.purple.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.purple, lineWidth: 1)
                        )
                    
                    Button {
                        Task {
                            _ = await viewModel.updateConfigValue(config.key, to: editingConfigValue)
                            editingConfigKey = nil
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isPerformingAction)
                    
                    Button {
                        editingConfigKey = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Display mode - clickable to edit
                Button {
                    editingConfigKey = config.key
                    editingConfigValue = config.value
                } label: {
                    HStack(spacing: 6) {
                        Text(config.value)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.purple)
                        
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(.purple.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
