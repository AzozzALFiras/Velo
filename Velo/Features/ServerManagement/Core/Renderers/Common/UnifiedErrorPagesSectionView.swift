
import SwiftUI

struct UnifiedErrorPagesSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    // Common error codes
    let commonCodes = ["404", "500", "502", "503"]
    
    // Editor State
    @State private var showingEditor = false
    @State private var editingCode = ""
    @State private var editingPath = ""
    @State private var editingContent = ""
    @State private var isLoadingContent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            Text("Custom Error Pages")
                .font(.headline)
                .foregroundStyle(.white)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(commonCodes, id: \.self) { code in
                    errorPageCard(code: code)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showingEditor) {
            ErrorPageEditorSheet(
                code: editingCode,
                content: $editingContent,
                isLoading: isLoadingContent,
                onSave: {
                    Task {
                        let success = await viewModel.saveErrorPageContent(path: editingPath, content: editingContent)
                        if success {
                            showingEditor = false
                        }
                    }
                },
                onReset: {
                    Task {
                        if let path = await viewModel.createDefaultErrorPage(code: editingCode) {
                            editingPath = path
                            editingContent = await viewModel.getErrorPageContent(path: path)
                        }
                    }
                },
                onDismiss: { showingEditor = false }
            )
        }
    }

    private func errorPageCard(code: String) -> some View {
        let currentPath = state.errorPages[code] ?? ""
        let isConfigured = !currentPath.isEmpty
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(code)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if isConfigured {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            
            Text(description(for: code))
                .font(.caption)
                .foregroundStyle(.gray)
            
            // Path Input
            TextField("Path or URL (e.g. /404.html)", text: Binding(
                get: { currentPath },
                set: { _ in } // Read-only via this field effectively, use Save to update
            ))
            .textFieldStyle(.plain)
            .padding(8)
            .background(Color.black.opacity(0.3))
            .cornerRadius(6)
            .foregroundStyle(.white)
            .disabled(true) // Disable manual typing for now to encourage Design flow, or enable if needed
            
            HStack(spacing: 8) {
                // Design / Create Button
                Button {
                    openEditor(for: code, path: currentPath)
                } label: {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                        Text(isConfigured ? "Edit Design" : "Create & Design")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.2))
                    .foregroundStyle(.purple)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                // Unset/Clear Button (if configured)
                if isConfigured {
                    Button {
                        Task {
                            await viewModel.updateErrorPage(code: code, path: "")
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func openEditor(for code: String, path: String) {
        editingCode = code
        editingPath = path
        showingEditor = true
        isLoadingContent = true
        
        Task {
            if path.isEmpty {
                // Create default first
                if let newPath = await viewModel.createDefaultErrorPage(code: code) {
                    editingPath = newPath
                    editingContent = await viewModel.getErrorPageContent(path: newPath)
                }
            } else {
                // Load existing
                editingContent = await viewModel.getErrorPageContent(path: path)
            }
            isLoadingContent = false
        }
    }
    
    private func description(for code: String) -> String {
        switch code {
        case "404": return "Not Found"
        case "500": return "Internal Server Error"
        case "502": return "Bad Gateway"
        case "503": return "Service Unavailable"
        default: return "Error"
        }
    }
}

// MARK: - Editor Sheet

struct ErrorPageEditorSheet: View {
    let code: String
    @Binding var content: String
    let isLoading: Bool
    let onSave: () -> Void
    let onReset: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit \(code) Page")
                    .font(.headline)
                
                Spacer()
                
                Button("Close") { onDismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            // Toolbar
            HStack {
                Button {
                    onReset()
                } label: {
                    Label("Reset to Premium Default", systemImage: "arrow.counterclockwise")
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                }
                
                Button {
                    onSave()
                } label: {
                    Label("Save Changes", systemImage: "checkmark")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(isLoading)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Editor
            if isLoading && content.isEmpty {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else {
                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}
