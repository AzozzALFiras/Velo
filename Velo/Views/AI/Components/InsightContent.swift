//
//  InsightContent.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

// MARK: - Suggestions Content
struct SuggestionsContent: View {
    @ObservedObject var viewModel: TerminalViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
            // Quick actions
            InsightSection(title: "Quick Actions") {
                VStack(spacing: VeloDesign.Spacing.sm) {
                    QuickActionCard(
                        icon: "arrow.clockwise",
                        title: "Repeat Last",
                        subtitle: "Run previous command again",
                        color: VeloDesign.Colors.info
                    ) {
                        if let last = viewModel.historyManager.recentCommands.first {
                            viewModel.rerunCommand(last)
                        }
                    }
                    
                    QuickActionCard(
                        icon: "trash",
                        title: "Clear Screen",
                        subtitle: "Clear all output",
                        color: VeloDesign.Colors.warning
                    ) {
                        viewModel.clearScreen()
                    }
                }
            }
            
            // AI Recommendations
            InsightSection(title: "Recommended") {
                if viewModel.predictionEngine.suggestions.isEmpty {
                    EmptyInsightView(message: "Start typing to get suggestions")
                } else {
                    VStack(spacing: VeloDesign.Spacing.xs) {
                        ForEach(viewModel.predictionEngine.suggestions.prefix(5)) { suggestion in
                            RecommendationRow(
                                suggestion: suggestion,
                                onSelect: { viewModel.acceptSuggestion(suggestion) }
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Context Content
struct ContextContent: View {
    @ObservedObject var viewModel: TerminalViewModel
    @ObservedObject var historyViewModel: HistoryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
            // Current context
            InsightSection(title: "Current Context") {
                VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                    ContextRow(
                        icon: "folder",
                        label: "Directory",
                        value: (viewModel.currentDirectory as NSString).lastPathComponent
                    )
                    
                    ContextRow(
                        icon: "terminal",
                        label: "Commands Today",
                        value: "\(historyViewModel.todayCommandCount)"
                    )
                    
                    ContextRow(
                        icon: "checkmark.circle",
                        label: "Last Exit Code", 
                        value: "\(viewModel.lastExitCode)"
                    )
                }
            }
            
            // Active patterns
            InsightSection(title: "Active Patterns") {
                VStack(spacing: VeloDesign.Spacing.xs) {
                    PatternRow(pattern: "git workflow", frequency: 15)
                    PatternRow(pattern: "npm development", frequency: 8)
                    PatternRow(pattern: "file operations", frequency: 5)
                }
            }
        }
    }
}

// MARK: - Chat Content
struct ChatContent: View {
    @ObservedObject var service: CloudAIService
    @ObservedObject var terminalVM: TerminalViewModel
    
    @State private var inputText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
            // Chat History
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                        if service.messages.isEmpty {
                            EmptyInsightView(message: "Ask AI for help or code explanations...")
                                .frame(height: 200)
                        } else {
                            ForEach(service.messages) { msg in
                                ChatMessageRow(message: msg, terminalVM: terminalVM)
                                    .id(msg.id)
                            }
                        }
                        
                        if service.isThinking {
                            ThinkingIndicator()
                                .padding(.leading, 12)
                                .id("thinking")
                        }
                        
                        if let error = service.errorMessage {
                            Text("Error: \(error)")
                                .font(VeloDesign.Typography.caption)
                                .foregroundColor(VeloDesign.Colors.error)
                                .padding()
                                .id("error")
                        }
                        
                        Color.clear.frame(height: 1).id("bottom")
                    }
                }
                .onChange(of: service.messages) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: service.isThinking) { thinking in
                    if thinking {
                        withAnimation {
                            proxy.scrollTo("thinking", anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input Area
            HStack(spacing: 8) {
                TextField("Ask...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(VeloDesign.Typography.monoSmall)
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(VeloDesign.Colors.glassBorder, lineWidth: 1)
                    )
                    .focused($isFocused)
                    .onSubmit(sendMessage)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(inputText.isEmpty ? VeloDesign.Colors.textMuted : VeloDesign.Colors.neonPurple)
                }
                .disabled(inputText.isEmpty || service.isThinking)
                .buttonStyle(.plain)
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let text = inputText
        inputText = ""
        Task {
            await service.sendMessage(text)
        }
    }
}

struct ChatMessageRow: View {
    let message: AIChatMessage
    var terminalVM: TerminalViewModel?
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: message.role == .user ? "person.circle.fill" : "sparkles.rectangle.stack.fill")
                .foregroundColor(message.role == .user ? VeloDesign.Colors.textSecondary : VeloDesign.Colors.neonPurple)
                .font(.system(size: 16))
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "Velo AI")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(VeloDesign.Colors.textMuted)
                
                if message.role == .user {
                    Text(message.content)
                        .font(VeloDesign.Typography.monoSmall)
                        .foregroundColor(VeloDesign.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ParsedMessageView(content: message.content, terminalVM: terminalVM)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Message Parsing

struct ParsedMessageView: View {
    let content: String
    var terminalVM: TerminalViewModel?
    
    var blocks: [MessageBlock] {
        parseMarkdown(content)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let text):
                    Text(LocalizedStringKey(text))
                        .font(VeloDesign.Typography.monoSmall)
                        .foregroundColor(VeloDesign.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                case .code(let lang, let code):
                    CodeBlockView(language: lang, code: code, terminalVM: terminalVM)
                }
            }
        }
    }
    
    enum MessageBlock {
        case text(String)
        case code(String, String)
    }
    
    func parseMarkdown(_ input: String) -> [MessageBlock] {
        var blocks: [MessageBlock] = []
        let components = input.components(separatedBy: "```")
        
        for (index, component) in components.enumerated() {
            if index % 2 == 0 {
                // Regular text
                if !component.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(.text(component))
                }
            } else {
                // Code block
                let lines = component.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                let lang = lines.first.map(String.init) ?? "text"
                let code = lines.count > 1 ? String(lines[1]) : ""
                blocks.append(.code(lang.trimmingCharacters(in: .whitespaces), code.trimmingCharacters(in: .newlines)))
            }
        }
        return blocks
    }
}

struct CodeBlockView: View {
    let language: String
    let code: String
    var terminalVM: TerminalViewModel?
    
    @State private var isHovered = false
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(language.isEmpty ? "Code" : language.capitalized)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(VeloDesign.Colors.textMuted)
                
                Spacer()
                
                // Run Button
                if let vm = terminalVM, !code.isEmpty {
                    Button(action: {
                        vm.inputText = code
                        // Optional: vm.executeCommand() immediately? 
                        // User requested "run commit", often implies auto-execution, 
                        // but populating input is safer. Let's populate.
                    }) {
                        Label("Use", systemImage: "terminal")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(VeloDesign.Colors.neonGreen)
                }
                
                // Copy Button
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopied = false }
                }) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(isCopied ? VeloDesign.Colors.success : VeloDesign.Colors.textMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            
            // Code
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                    .padding(10)
            }
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(VeloDesign.Colors.glassBorder, lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Views
struct InsightSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
            Text(title)
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.textMuted)
                .textCase(.uppercase)
            
            content()
        }
    }
}

struct EmptyInsightView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(VeloDesign.Typography.caption)
            .foregroundColor(VeloDesign.Colors.textMuted)
            .frame(maxWidth: .infinity)
            .padding(VeloDesign.Spacing.lg)
    }
}

// MARK: - Animations

struct ThinkingIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                PulsingDot(delay: 0)
                PulsingDot(delay: 0.2)
                PulsingDot(delay: 0.4)
            }
            
            Text("Velo AI is thinking...")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(VeloDesign.Colors.textMuted)
        }
    }
}

struct PulsingDot: View {
    let delay: Double
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(VeloDesign.Colors.neonPurple)
            .frame(width: 5, height: 5)
            .scaleEffect(isAnimating ? 1.2 : 0.8)
            .opacity(isAnimating ? 1.0 : 0.3)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    isAnimating = true
                }
            }
    }
}
