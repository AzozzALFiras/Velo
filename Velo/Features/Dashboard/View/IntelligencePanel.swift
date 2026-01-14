//
//  IntelligencePanel.swift
//  Velo
//
//  Dashboard Redesign - Right Intelligence Panel
//  AI Chat, Errors, Suggestions, Auto-Scripts
//

import SwiftUI

// MARK: - Intelligence Tab

/// Tabs in the intelligence panel
enum IntelligenceTab: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case history = "History"
    case files = "Files"
    case errors = "Errors"
    case suggestions = "Suggestions"
    case scripts = "Scripts"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .history: return "clock.arrow.circlepath"
        case .files: return "folder"
        case .errors: return "exclamationmark.triangle"
        case .suggestions: return "lightbulb"
        case .scripts: return "scroll"
        }
    }
}

// MARK: - Intelligence Panel

/// Right panel for AI chat, errors, suggestions, and auto-scripts
struct IntelligencePanel: View {
    
    // State
    @Binding var selectedTab: IntelligenceTab
    @State private var chatInput: String = ""
    @State private var isExpanded: Bool = false
    @State private var historySearchText: String = ""
    
    // Data
    @ObservedObject var historyManager: CommandHistoryManager
    var aiMessages: [AIMessage] = []
    var recentErrors: [ErrorItem] = []
    var suggestions: [SuggestionItem] = []
    var scripts: [AutoScript] = []
    var currentDirectory: String = ""
    
    // Actions
    var onSendMessage: ((String) -> Void)?
    var onRunCommand: ((String) -> Void)?
    var onExplainError: ((ErrorItem) -> Void)?
    var onFixError: ((ErrorItem) -> Void)?
    var onRunScript: ((AutoScript) -> Void)?
    var onOpenSettings: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs
            panelHeader
            
            Divider()
                .background(ColorTokens.border)
            
            // Content based on selected tab - manual switching (no TabView indicators)
            Group {
                switch selectedTab {
                case .chat:
                    chatTab
                case .history:
                    historyTab
                case .files:
                    filesTab
                case .errors:
                    errorsTab
                case .suggestions:
                    suggestionsTab
                case .scripts:
                    scriptsTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ColorTokens.layer1)
    }
    
    // MARK: - Header
    
    private var panelHeader: some View {
        VStack(spacing: 0) {
            // Title row
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.accentSecondary)
                    
                    Text("Intelligence")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                
                Spacer()
                
                // Expand button
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            // Tab bar - icon-only for compact display
            HStack(spacing: 2) {
                ForEach(IntelligenceTab.allCases) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        hasNotification: tabHasNotification(tab)
                    ) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }
    
    private func tabHasNotification(_ tab: IntelligenceTab) -> Bool {
        switch tab {
        case .errors: return !recentErrors.isEmpty
        case .suggestions: return !suggestions.isEmpty
        default: return false
        }
    }
    
    // MARK: - Chat Tab
    
    private var chatTab: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollView {
                LazyVStack(spacing: 12) {
                    if aiMessages.isEmpty {
                        chatEmptyState
                    } else {
                        ForEach(aiMessages) { message in
                            ChatMessageView(
                                message: message,
                                onRunCommand: onRunCommand
                            )
                        }
                    }
                }
                .padding(12)
            }
            
            Divider()
                .background(ColorTokens.borderSubtle)
            
            // Input
            chatInputArea
        }
    }
    
    private var chatEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(ColorTokens.accentSecondary.opacity(0.5))
            
            Text("Ask me anything")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
            
            Text("Get help with commands, errors, or scripts")
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var chatInputArea: some View {
        HStack(spacing: 8) {
            TextField("Ask AI...", text: $chatInput)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ColorTokens.layer2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit {
                    sendMessage()
                }
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(chatInput.isEmpty ? ColorTokens.textTertiary : ColorTokens.accentPrimary)
            }
            .buttonStyle(.plain)
            .disabled(chatInput.isEmpty)
        }
        .padding(12)
    }
    
    private func sendMessage() {
        guard !chatInput.isEmpty else { return }
        onSendMessage?(chatInput)
        chatInput = ""
    }
    
    // MARK: - Errors Tab
    
    private var errorsTab: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if recentErrors.isEmpty {
                    emptyState(
                        icon: "checkmark.circle",
                        title: "No Errors",
                        subtitle: "All commands ran successfully"
                    )
                } else {
                    ForEach(recentErrors) { error in
                        ErrorCard(
                            error: error,
                            onExplain: { onExplainError?(error) },
                            onFix: { onFixError?(error) }
                        )
                    }
                }
            }
            .padding(12)
        }
    }
    
    // MARK: - Suggestions Tab
    
    private var suggestionsTab: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if suggestions.isEmpty {
                    emptyState(
                        icon: "lightbulb",
                        title: "No Suggestions",
                        subtitle: "Run some commands to get suggestions"
                    )
                } else {
                    Text("Based on your workflow:")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(suggestions) { suggestion in
                        SuggestionCard(suggestion: suggestion) {
                            onRunCommand?(suggestion.command)
                        }
                    }
                }
            }
            .padding(12)
        }
    }
    
    // MARK: - Scripts Tab
    
    private var scriptsTab: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if scripts.isEmpty {
                    emptyState(
                        icon: "scroll",
                        title: "No Scripts",
                        subtitle: "Velo will detect patterns and suggest scripts"
                    )
                } else {
                    ForEach(scripts) { script in
                        ScriptCard(script: script) {
                            onRunScript?(script)
                        }
                    }
                }
            }
            .padding(12)
        }
    }
    
    // MARK: - History Tab
    
    private var historyTab: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                
                TextField("Search history...", text: $historySearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ColorTokens.layer2)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(12)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // Favorites Section
                    if !historyManager.favoriteCommands.isEmpty && historySearchText.isEmpty {
                        IntelligenceSectionHeader(title: "Favorites", icon: "star.fill", color: ColorTokens.warning)
                        
                        ForEach(historyManager.favoriteCommands) { command in
                            HistoryRow(command: command, historyManager: historyManager) {
                                onRunCommand?(command.command)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                    }
                    
                    // Recent Section
                    IntelligenceSectionHeader(title: "Recent", icon: "clock", color: ColorTokens.accentPrimary)
                    
                    let commands = historySearchText.isEmpty ? historyManager.recentCommands : historyManager.search(query: historySearchText)
                    
                    if commands.isEmpty {
                        Text("No commands found")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(commands) { command in
                            HistoryRow(command: command, historyManager: historyManager) {
                                onRunCommand?(command.command)
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
    }
    
    // MARK: - Files Tab
    
    private var filesTab: some View {
        VStack(spacing: 0) {
            // Path header
            HStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.accentPrimary)
                
                Text(currentDirectory.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(12)
            .background(ColorTokens.layer1)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 0) {
                    // This is a placeholder for actual file tracking
                    // In a real implementation, we would list files from the current directory
                    FileListPlaceholder(directory: currentDirectory)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(ColorTokens.textTertiary)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
            
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Tab Button

private struct TabButton: View {
    
    let tab: IntelligenceTab
    let isSelected: Bool
    let hasNotification: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 14, weight: .medium))
                    
                    if hasNotification {
                        Circle()
                            .fill(ColorTokens.error)
                            .frame(width: 6, height: 6)
                            .offset(x: 4, y: -2)
                    }
                }
                
                Text(tab.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? ColorTokens.accentPrimary : ColorTokens.textTertiary)
            .frame(width: 60, height: 44)
            .background(isSelected ? ColorTokens.layer2 : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help(tab.rawValue)
    }
}

// MARK: - Chat Message View

struct ChatMessageView: View {
    
    let message: AIMessage
    var onRunCommand: ((String) -> Void)?
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
            // Sender label
            HStack(spacing: 4) {
                if !message.isUser {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundStyle(ColorTokens.accentSecondary)
                }
                
                Text(message.isUser ? "You" : "Velo AI")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            
            // Message content
            VStack(alignment: .leading, spacing: 8) {
                Text(message.content)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                // Code blocks
                ForEach(message.codeBlocks, id: \.self) { code in
                    InlineCodeBlock(code: code) {
                        onRunCommand?(code)
                    }
                }
            }
            .padding(10)
            .background(message.isUser ? ColorTokens.accentPrimary.opacity(0.15) : ColorTokens.layer2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

// MARK: - Inline Code Block

private struct InlineCodeBlock: View {
    
    let code: String
    let onRun: () -> Void
    
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(code)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ColorTokens.textPrimary)
            
            HStack(spacing: 8) {
                Button {
                    onRun()
                } label: {
                    Label("Run", systemImage: "play.fill")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.success)
                
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                } label: {
                    Label(isCopied ? "Copied" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .padding(8)
        .background(ColorTokens.layer0)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Error Card

private struct ErrorCard: View {
    
    let error: ErrorItem
    let onExplain: () -> Void
    let onFix: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Error text
            Text(error.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ColorTokens.error)
                .lineLimit(3)
            
            // Metadata
            HStack {
                Text(error.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Explain", action: onExplain)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.accentSecondary)
                    
                    Button("Fix", action: onFix)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.accentPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(ColorTokens.error.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(ColorTokens.error.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Suggestion Card

private struct SuggestionCard: View {
    
    let suggestion: SuggestionItem
    let onRun: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onRun) {
            HStack(spacing: 10) {
                Text(suggestion.command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "play.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(ColorTokens.success)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(10)
            .background(isHovered ? ColorTokens.layer2 : ColorTokens.layer1)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(ColorTokens.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Script Card

private struct ScriptCard: View {
    
    let script: AutoScript
    let onRun: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "scroll")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.accentSecondary)
                
                Text(script.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Spacer()
                
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
            
            // Commands preview
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(script.commands, id: \.self) { command in
                        Text(command)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                .padding(8)
                .background(ColorTokens.layer0)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Actions
            HStack(spacing: 8) {
                Button(action: onRun) {
                    Label("Run", systemImage: "play.fill")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(ColorTokens.success)
                
                Button {} label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(ColorTokens.textSecondary)
                
                Spacer()
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(ColorTokens.layer2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Data Models

struct AIMessage: Identifiable {
    let id: UUID = UUID()
    let content: String
    let isUser: Bool
    let codeBlocks: [String]
    let timestamp: Date = Date()
    
    init(content: String, isUser: Bool, codeBlocks: [String] = []) {
        self.content = content
        self.isUser = isUser
        self.codeBlocks = codeBlocks
    }
}

struct ErrorItem: Identifiable {
    let id: UUID = UUID()
    let message: String
    let command: String
    let timestamp: Date
}

struct SuggestionItem: Identifiable {
    let id: UUID = UUID()
    let command: String
    let reason: String
}

struct AutoScript: Identifiable {
    let id: UUID = UUID()
    let name: String
    let commands: [String]
}

// MARK: - Helper Views

private struct IntelligenceSectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ColorTokens.textSecondary)
            
            Spacer()
        }
    }
}

private struct HistoryRow: View {
    let command: CommandModel
    @ObservedObject var historyManager: CommandHistoryManager
    let onRun: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Execution icon
            Image(systemName: command.isSuccess ? "terminal" : "exclamationmark.circle")
                .font(.system(size: 10))
                .foregroundStyle(command.isSuccess ? ColorTokens.textTertiary : ColorTokens.error)
                .frame(width: 16)
            
            // Command
            VStack(alignment: .leading, spacing: 2) {
                Text(command.command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)
                
                if !command.workingDirectory.isEmpty {
                    Text(command.workingDirectory.components(separatedBy: "/").last ?? "")
                        .font(.system(size: 9))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .onTapGesture(perform: onRun)
            
            Spacer()
            
            // Actions
            HStack(spacing: 4) {
                Button {
                    historyManager.toggleFavorite(for: command.id)
                } label: {
                    Image(systemName: command.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundStyle(command.isFavorite ? ColorTokens.warning : ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
                
                if isHovered {
                    Button(action: onRun) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.accentPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .background(isHovered ? ColorTokens.layer2 : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

private struct FileListPlaceholder: View {
    let directory: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Simulated file list for UI demonstration
            FileItemView(name: "app", type: IntelligenceFileType.folder)
            FileItemView(name: "config", type: IntelligenceFileType.folder)
            FileItemView(name: "database", type: IntelligenceFileType.folder)
            FileItemView(name: "public", type: IntelligenceFileType.folder)
            FileItemView(name: "resources", type: IntelligenceFileType.folder)
            FileItemView(name: "routes", type: IntelligenceFileType.folder)
            FileItemView(name: "storage", type: IntelligenceFileType.folder)
            FileItemView(name: "tests", type: IntelligenceFileType.folder)
            FileItemView(name: "artisan", type: IntelligenceFileType.file)
            FileItemView(name: "composer.json", type: IntelligenceFileType.file)
            FileItemView(name: "package.json", type: IntelligenceFileType.file)
            FileItemView(name: "README.md", type: IntelligenceFileType.file)
            FileItemView(name: "webpack.mix.js", type: IntelligenceFileType.file)
            FileItemView(name: ".env", type: IntelligenceFileType.file)
        }
    }
}

private enum IntelligenceFileType {
    case file, folder
}

private struct FileItemView: View {
    let name: String
    let type: IntelligenceFileType
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: type == IntelligenceFileType.folder ? "folder.fill" : "doc.fill")
                .font(.system(size: 11))
                .foregroundStyle(type == IntelligenceFileType.folder ? ColorTokens.accentPrimary : ColorTokens.textTertiary)
                .frame(width: 16)
            
            Text(name)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textSecondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? ColorTokens.layer2 : .clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview {
    IntelligencePanel(
        selectedTab: .constant(.chat),
        historyManager: CommandHistoryManager(),
        aiMessages: [
            AIMessage(content: "How do I revert the last commit?", isUser: true),
            AIMessage(
                content: "To revert the last commit, you can use:",
                isUser: false,
                codeBlocks: ["git reset --soft HEAD~1"]
            )
        ],
        recentErrors: [
            ErrorItem(message: "npm ERR! ENOENT", command: "npm install", timestamp: Date().addingTimeInterval(-120))
        ],
        suggestions: [
            SuggestionItem(command: "git push origin main", reason: "You have 1 commit ahead")
        ],
        scripts: [
            AutoScript(name: "Deploy Script", commands: ["git pull", "npm install", "npm run build"])
        ]
    )
    .frame(width: 300, height: 600)
}
