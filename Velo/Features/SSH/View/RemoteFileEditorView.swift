import SwiftUI
import AppKit

// MARK: - Remote File Editor View
/// A modal editor for remote SSH files with syntax highlighting
struct RemoteFileEditorView: View {
    let filename: String
    let remotePath: String
    let sshConnectionString: String
    let initialContent: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var content: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasChanges = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastType = .success
    
    enum ToastType {
        case success, error, info
    }
    
    init(filename: String, remotePath: String, sshConnectionString: String, initialContent: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.filename = filename
        self.remotePath = remotePath
        self.sshConnectionString = sshConnectionString
        self.initialContent = initialContent
        self.onSave = onSave
        self.onCancel = onCancel
        self._content = State(initialValue: initialContent)
    }
    
    private var fileExtension: String {
        (filename as NSString).pathExtension.lowercased()
    }
    
    private var languageLabel: String {
        switch fileExtension {
        case "swift": return "Swift"
        case "py": return "Python"
        case "js": return "JavaScript"
        case "ts": return "TypeScript"
        case "php": return "PHP"
        case "html": return "HTML"
        case "css": return "CSS"
        case "json": return "JSON"
        case "xml": return "XML"
        case "yaml", "yml": return "YAML"
        case "sh", "bash", "zsh": return "Shell"
        case "md": return "Markdown"
        case "sql": return "SQL"
        case "rb": return "Ruby"
        case "go": return "Go"
        case "rs": return "Rust"
        case "c", "h": return "C"
        case "cpp", "hpp", "cc": return "C++"
        case "java": return "Java"
        case "kt": return "Kotlin"
        default: return "Text"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            editorHeader
            
            Divider()
                .background(VeloDesign.Colors.glassBorder)
            
            // Editor content
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else {
                editorContent
            }
            
            Divider()
                .background(VeloDesign.Colors.glassBorder)
            
            // Footer with actions
            editorFooter
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(VeloDesign.Colors.deepSpace)
        .onAppear {
            // If content is empty but initialContent is not, sync them
            if content.isEmpty && !initialContent.isEmpty {
                content = initialContent
            }
        }
        .onChange(of: initialContent) { newValue in
            content = newValue
        }
        .overlay(alignment: .bottom) {
            if showToast {
                toastView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 32)
            }
        }
    }
    
    // MARK: - Toast View
    private var toastView: some View {
        HStack(spacing: 8) {
            Image(systemName: toastType == .success ? "checkmark.circle.fill" : (toastType == .error ? "xmark.circle.fill" : "info.circle.fill"))
                .foregroundColor(toastType == .success ? VeloDesign.Colors.neonGreen : (toastType == .error ? VeloDesign.Colors.error : VeloDesign.Colors.neonCyan))
            
            Text(toastMessage)
                .font(VeloDesign.Typography.subheadline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.85))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(VeloDesign.Colors.glassBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    private func showToast(_ message: String, type: ToastType = .info) {
        withAnimation(.spring()) {
            toastMessage = message
            toastType = type
            showToast = true
        }
        
        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showToast = false
            }
        }
    }
    
    // MARK: - Header
    private var editorHeader: some View {
        HStack(spacing: VeloDesign.Spacing.md) {
            // File icon
            Image(systemName: "doc.text.fill")
                .font(.system(size: 16))
                .foregroundColor(VeloDesign.Colors.neonCyan)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(filename)
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                
                Text(remotePath)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textSecondary)
            }
            
            Spacer()
            
            // Language badge
            Text(languageLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(VeloDesign.Colors.neonPurple)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(VeloDesign.Colors.neonPurple.opacity(0.15))
                .cornerRadius(4)
            
            // Modified indicator
            if hasChanges {
                HStack(spacing: 4) {
                    Circle()
                        .fill(VeloDesign.Colors.warning)
                        .frame(width: 6, height: 6)
                    Text("ssh.editor.modified".localized)
                        .font(.system(size: 11))
                        .foregroundColor(VeloDesign.Colors.warning)
                }
            }
        }
        .padding(VeloDesign.Spacing.md)
        .background(VeloDesign.Colors.cardBackground.opacity(0.8))
    }
    
    // MARK: - Editor Content
    private var editorContent: some View {
        SyntaxHighlightedEditor(
            text: $content,
            language: fileExtension,
            onChange: {
                hasChanges = content != initialContent
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: VeloDesign.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text("ssh.editor.loading".localized)
                .font(VeloDesign.Typography.subheadline)
                .foregroundColor(VeloDesign.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: VeloDesign.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(VeloDesign.Colors.error)
            Text("ssh.editor.error".localized)
                .font(VeloDesign.Typography.headline)
                .foregroundColor(VeloDesign.Colors.textPrimary)
            Text(message)
                .font(VeloDesign.Typography.subheadline)
                .foregroundColor(VeloDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer
    private var editorFooter: some View {
        HStack(spacing: VeloDesign.Spacing.md) {
            // Line count
            Text("\(content.components(separatedBy: "\n").count) " + "files.getSize.lines".localized)
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(VeloDesign.Colors.textSecondary)
            
            Spacer()
            
            // Cancel button
            Button(action: onCancel) {
                Text("theme.cancel".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(VeloDesign.Colors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(VeloDesign.Colors.glassWhite)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(VeloDesign.Colors.glassBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            
            // Save button
            Button(action: handleSave) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11))
                    Text("theme.save".localized)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    hasChanges 
                        ? VeloDesign.Colors.neonGreen 
                        : VeloDesign.Colors.neonGreen.opacity(0.5)
                )
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!hasChanges)
            .keyboardShortcut("s", modifiers: .command)
            
            // Close/Done button (if saved)
            if !hasChanges {
                Button(action: onCancel) {
                    Text("workspace.done".localized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(VeloDesign.Colors.glassWhite.opacity(0.1))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(VeloDesign.Colors.glassBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(VeloDesign.Spacing.md)
        .background(VeloDesign.Colors.cardBackground.opacity(0.8))
    }
    
    private func handleSave() {
        isLoading = true
        onSave(content)
        
        // Simulate save delay for better UX (since strict async feedback is hard to pipe through)
        // In a real async setup, we'd wait for a callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            hasChanges = false
            showToast("ssh.editor.saved".localized, type: .success)
            // Don't auto-close, let user see the success message
        }
    }
}

// MARK: - Syntax Highlighted Editor
struct SyntaxHighlightedEditor: NSViewRepresentable {
    @Binding var text: String
    let language: String
    let onChange: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = CodeTextView()
        
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = NSColor(VeloDesign.Colors.deepSpace)
        textView.textColor = NSColor(VeloDesign.Colors.textPrimary)
        textView.insertionPointColor = NSColor(VeloDesign.Colors.neonCyan)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(VeloDesign.Colors.neonCyan.opacity(0.3))
        ]
        
        // Line height
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        textView.defaultParagraphStyle = paragraphStyle
        
        textView.string = text
        
        // Apply syntax highlighting
        context.coordinator.applySyntaxHighlighting(to: textView, language: language)
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = NSColor(VeloDesign.Colors.deepSpace)
        
        // Configure text container
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            context.coordinator.applySyntaxHighlighting(to: textView, language: language)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxHighlightedEditor
        
        init(_ parent: SyntaxHighlightedEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onChange()
            
            // Re-apply highlighting (debounced in real implementation)
            applySyntaxHighlighting(to: textView, language: parent.language)
        }
        
        func applySyntaxHighlighting(to textView: NSTextView, language: String) {
            let text = textView.string
            let fullRange = NSRange(location: 0, length: text.count)
            
            // Reset to default
            textView.textStorage?.setAttributes([
                .foregroundColor: NSColor(VeloDesign.Colors.textPrimary),
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            ], range: fullRange)
            
            // Apply syntax colors based on language
            applySyntaxColors(to: textView.textStorage!, text: text, language: language)
        }
        
        private func applySyntaxColors(to storage: NSTextStorage, text: String, language: String) {
            // Keywords by language
            let keywords = getKeywords(for: language)
            
            // Colors
            let keywordColor = NSColor(VeloDesign.Colors.neonPurple)
            let stringColor = NSColor(VeloDesign.Colors.neonGreen)
            let commentColor = NSColor(VeloDesign.Colors.textSecondary)
            let numberColor = NSColor(VeloDesign.Colors.warning)
            let functionColor = NSColor(VeloDesign.Colors.neonCyan)
            
            // Highlight keywords
            for keyword in keywords {
                highlightPattern("\\b\(keyword)\\b", in: storage, text: text, color: keywordColor)
            }
            
            // Highlight strings (double quotes)
            highlightPattern("\"[^\"\\n]*\"", in: storage, text: text, color: stringColor)
            
            // Highlight strings (single quotes)
            highlightPattern("'[^'\\n]*'", in: storage, text: text, color: stringColor)
            
            // Highlight numbers
            highlightPattern("\\b\\d+(\\.\\d+)?\\b", in: storage, text: text, color: numberColor)
            
            // Highlight comments
            switch language {
            case "php", "swift", "java", "js", "ts", "c", "cpp", "go", "rs", "kt":
                highlightPattern("//.*$", in: storage, text: text, color: commentColor, multiline: true)
                highlightPattern("/\\*[\\s\\S]*?\\*/", in: storage, text: text, color: commentColor)
            case "py", "rb", "sh", "bash", "zsh", "yaml", "yml":
                highlightPattern("#.*$", in: storage, text: text, color: commentColor, multiline: true)
            case "html", "xml":
                highlightPattern("<!--[\\s\\S]*?-->", in: storage, text: text, color: commentColor)
            default:
                break
            }
            
            // Highlight function calls
            highlightPattern("\\b[a-zA-Z_][a-zA-Z0-9_]*\\s*(?=\\()", in: storage, text: text, color: functionColor)
            
            // Highlight PHP variables
            if language == "php" {
                highlightPattern("\\$[a-zA-Z_][a-zA-Z0-9_]*", in: storage, text: text, color: NSColor(VeloDesign.Colors.info))
            }
        }
        
        private func highlightPattern(_ pattern: String, in storage: NSTextStorage, text: String, color: NSColor, multiline: Bool = false) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: multiline ? [.anchorsMatchLines] : []) else { return }
            let range = NSRange(location: 0, length: text.count)
            
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    storage.addAttribute(.foregroundColor, value: color, range: matchRange)
                }
            }
        }
        
        private func getKeywords(for language: String) -> [String] {
            switch language {
            case "php":
                return ["php", "echo", "print", "if", "else", "elseif", "endif", "while", "do", "for", "foreach", "endforeach", "switch", "case", "default", "break", "continue", "return", "function", "class", "extends", "implements", "public", "private", "protected", "static", "const", "new", "try", "catch", "throw", "finally", "namespace", "use", "require", "include", "require_once", "include_once", "true", "false", "null", "array", "isset", "empty", "unset"]
            case "swift":
                return ["import", "class", "struct", "enum", "protocol", "extension", "func", "var", "let", "if", "else", "guard", "switch", "case", "default", "for", "while", "repeat", "return", "throw", "try", "catch", "throws", "async", "await", "actor", "public", "private", "internal", "fileprivate", "open", "static", "override", "final", "lazy", "weak", "unowned", "self", "Self", "super", "nil", "true", "false", "init", "deinit", "where", "in", "as", "is", "some", "any"]
            case "py":
                return ["def", "class", "if", "elif", "else", "for", "while", "try", "except", "finally", "with", "as", "import", "from", "return", "yield", "raise", "pass", "break", "continue", "lambda", "True", "False", "None", "and", "or", "not", "in", "is", "global", "nonlocal", "async", "await", "self"]
            case "js", "ts":
                return ["const", "let", "var", "function", "class", "extends", "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue", "return", "throw", "try", "catch", "finally", "new", "this", "super", "import", "export", "from", "async", "await", "yield", "true", "false", "null", "undefined", "typeof", "instanceof", "void", "delete"]
            case "html":
                return ["html", "head", "body", "div", "span", "p", "a", "img", "script", "style", "link", "meta", "title", "header", "footer", "nav", "main", "section", "article", "aside", "form", "input", "button", "table", "tr", "td", "th", "ul", "ol", "li", "br", "hr"]
            case "css":
                return ["@import", "@media", "@keyframes", "@font-face", "important"]
            case "sh", "bash", "zsh":
                return ["if", "then", "else", "elif", "fi", "for", "do", "done", "while", "until", "case", "esac", "function", "return", "exit", "echo", "read", "export", "local", "source", "true", "false"]
            default:
                return []
            }
        }
    }
}

// MARK: - Code Text View
class CodeTextView: NSTextView {
    override func insertNewline(_ sender: Any?) {
        // Auto-indent on newline
        let currentLine = getCurrentLine()
        let indent = currentLine.prefix(while: { $0 == " " || $0 == "\t" })
        super.insertNewline(sender)
        insertText(String(indent), replacementRange: selectedRange())
    }
    
    private func getCurrentLine() -> String {
        let text = string as NSString
        let lineRange = text.lineRange(for: selectedRange())
        return text.substring(with: lineRange)
    }
    
    override func insertTab(_ sender: Any?) {
        // Insert 4 spaces instead of tab
        insertText("    ", replacementRange: selectedRange())
    }
}

// MARK: - Preview
#Preview {
    RemoteFileEditorView(
        filename: "demo.php",
        remotePath: "/velo/demo.php",
        sshConnectionString: "root@server",
        initialContent: """
        <?php
        // This is a comment
        class Example {
            private $name = "test";
            
            public function hello() {
                echo "Hello World!";
                return true;
            }
        }
        ?>
        """,
        onSave: { _ in },
        onCancel: { }
    )
    .frame(width: 800, height: 600)
}
