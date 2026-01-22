//
//  FileEditorView.swift
//  Velo
//
//  File content editor for text-based files.
//  Supports PHP, JS, JSON, ENV, TXT, and other text formats.
//

import SwiftUI

struct FileEditorView: View {
    let file: ServerFileItem
    @ObservedObject var viewModel: FilesDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var content: String = ""
    @State private var originalContent: String = ""
    @State private var isLoading: Bool = true
    @State private var isSaving: Bool = false
    @State private var error: String?
    @State private var hasUnsavedChanges: Bool = false
    @State private var showDiscardAlert: Bool = false

    private var fileType: FileTypeCategory {
        FileTypeCategory.from(fileName: file.name, isDirectory: file.isDirectory)
    }

    private var languageHint: String {
        switch file.fileExtension {
        case "php": return "PHP"
        case "js", "jsx": return "JavaScript"
        case "ts", "tsx": return "TypeScript"
        case "py": return "Python"
        case "rb": return "Ruby"
        case "go": return "Go"
        case "rs": return "Rust"
        case "swift": return "Swift"
        case "json": return "JSON"
        case "yaml", "yml": return "YAML"
        case "xml": return "XML"
        case "html", "htm": return "HTML"
        case "css", "scss", "sass": return "CSS"
        case "md": return "Markdown"
        case "sh", "bash", "zsh": return "Shell"
        case "sql": return "SQL"
        case "env": return "Environment"
        case "conf", "cfg", "ini": return "Config"
        default: return "Text"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            editorHeader

            Divider()
                .background(ColorTokens.borderSubtle)

            // Content
            if isLoading {
                loadingView
            } else if let error = error {
                errorView(error)
            } else {
                editorContent
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(ColorTokens.layer0)
        .task {
            await loadFileContent()
        }
        .onChange(of: content) { _, newValue in
            hasUnsavedChanges = newValue != originalContent
        }
        .alert("files.editor.unsavedChanges".localized, isPresented: $showDiscardAlert) {
            Button("files.editor.discard".localized, role: .destructive) {
                dismiss()
            }
            Button("common.cancel".localized, role: .cancel) {}
        } message: {
            Text("files.editor.unsavedChangesMessage".localized)
        }
    }

    // MARK: - Header

    private var editorHeader: some View {
        HStack(spacing: 12) {
            // File icon and name
            HStack(spacing: 8) {
                Image(systemName: fileType.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: fileType.color))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(file.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ColorTokens.textPrimary)

                        if hasUnsavedChanges {
                            Circle()
                                .fill(ColorTokens.warning)
                                .frame(width: 6, height: 6)
                        }
                    }

                    Text(file.path)
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            // Language indicator
            Text(languageHint)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(ColorTokens.layer2)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // File size
            Text(file.sizeString)
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)

            Divider()
                .frame(height: 20)
                .background(ColorTokens.borderSubtle)

            // Actions
            HStack(spacing: 8) {
                // Reload
                Button(action: {
                    Task { await loadFileContent() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.textSecondary)
                .help("files.editor.reload".localized)

                // Cancel
                Button("common.cancel".localized) {
                    if hasUnsavedChanges {
                        showDiscardAlert = true
                    } else {
                        dismiss()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)

                // Save
                Button(action: {
                    Task { await saveFileContent() }
                }) {
                    HStack(spacing: 4) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        Text("common.save".localized)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(hasUnsavedChanges ? ColorTokens.accentPrimary : ColorTokens.textDisabled)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!hasUnsavedChanges || isSaving)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ColorTokens.layer1.opacity(0.5))
    }

    // MARK: - Editor Content

    private var editorContent: some View {
        VStack(spacing: 0) {
            // Line numbers + Editor
            HStack(spacing: 0) {
                // Line numbers
                lineNumbersView

                Divider()
                    .background(ColorTokens.borderSubtle)

                // Text editor
                ScrollView {
                    TextEditor(text: $content)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .background(ColorTokens.layer0)
            }

            Divider()
                .background(ColorTokens.borderSubtle)

            // Status bar
            statusBar
        }
    }

    private var lineNumbersView: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 0) {
                let lines = content.components(separatedBy: "\n")
                ForEach(1...max(lines.count, 1), id: \.self) { lineNumber in
                    Text("\(lineNumber)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(height: 18)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(width: 50)
        .background(ColorTokens.layer1.opacity(0.3))
    }

    private var statusBar: some View {
        HStack(spacing: 16) {
            // Line count
            let lineCount = content.components(separatedBy: "\n").count
            Text("files.editor.lines".localized(lineCount))
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)

            // Character count
            Text("files.editor.characters".localized(content.count))
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)

            Spacer()

            // Encoding
            Text("UTF-8")
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)

            // Language
            Text(languageHint)
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ColorTokens.layer1.opacity(0.3))
    }

    // MARK: - Loading & Error States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("files.editor.loading".localized)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(ColorTokens.error)

            Text("files.editor.loadError".localized)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ColorTokens.textPrimary)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button(action: {
                Task { await loadFileContent() }
            }) {
                Text("files.editor.retry".localized)
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(ColorTokens.accentPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadFileContent() async {
        guard let session = viewModel.session else {
            error = "No active session"
            return
        }

        isLoading = true
        error = nil

        let result = await viewModel.fileService.readFile(at: file.path, maxBytes: Int(ServerFileItem.maxEditableSize), via: session)

        switch result {
        case .success(let fileContent):
            content = fileContent
            originalContent = fileContent
            hasUnsavedChanges = false
        case .failure(let fileError):
            error = fileError.localizedDescription
        }

        isLoading = false
    }

    private func saveFileContent() async {
        guard let session = viewModel.session else { return }

        isSaving = true

        let result = await viewModel.fileService.writeFile(at: file.path, content: content, via: session)

        switch result {
        case .success:
            originalContent = content
            hasUnsavedChanges = false
            viewModel.showSuccess("files.editor.saved".localized(file.name))
        case .failure(let error):
            viewModel.showError(error.localizedDescription)
        }

        isSaving = false
    }
}
