//
//  IntelligencePanel.swift
//  Velo
//
//  Dashboard Redesign - Right Intelligence Panel
//  AI Chat, Errors, Suggestions, Auto-Scripts
//

import SwiftUI
import UniformTypeIdentifiers

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
    @StateObject private var fileManager = FileExplorerManager()
    
    // Data
    @ObservedObject var historyManager: CommandHistoryManager
    var aiMessages: [AIMessage] = []
    var recentErrors: [ErrorItem] = []
    var suggestions: [SuggestionItem] = []
    var scripts: [AutoScript] = []
    var currentDirectory: String = ""
    var isSSH: Bool = false
    var sshConnectionString: String? = nil
    var parsedTerminalItems: [String] = [] // Re-added
    
    // Upload state for progress indicator
    var isUploading: Bool = false
    var uploadFileName: String = ""
    var uploadStartTime: Date? = nil
    var uploadProgress: Double = 0.0
    
    // Actions
    var onSendMessage: ((String) -> Void)?
    var onRunCommand: ((String) -> Void)?
    var onExplainError: ((ErrorItem) -> Void)?
    var onFixError: ((ErrorItem) -> Void)?
    var onRunScript: ((AutoScript) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onEditFile: ((String) -> Void)?
    var onChangeDirectory: ((String) -> Void)?
    
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
            // Upload Progress Banner
            if isUploading {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Uploading: \(uploadFileName)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 4) {
                                if uploadProgress > 0 {
                                    Text("\(Int(uploadProgress * 100))%")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(VeloDesign.Colors.neonCyan)
                                }
                                
                                if let startTime = uploadStartTime {
                                    Text(elapsedTimeString(from: startTime))
                                        .font(.system(size: 9))
                                        .foregroundColor(VeloDesign.Colors.textMuted)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(VeloDesign.Colors.neonCyan)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    
                    if uploadProgress > 0 {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .frame(height: 2)
                                    .foregroundColor(VeloDesign.Colors.neonCyan.opacity(0.1))
                                
                                Rectangle()
                                    .frame(width: geo.size.width * CGFloat(uploadProgress), height: 2)
                                    .foregroundColor(VeloDesign.Colors.neonCyan)
                            }
                        }
                        .frame(height: 2)
                    }
                }
                .background(VeloDesign.Colors.neonCyan.opacity(0.15))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(VeloDesign.Colors.neonCyan.opacity(0.3)),
                    alignment: .bottom
                )
            }
            
            // Current Directory Header / Breadcrumbs
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(VeloDesign.Colors.neonCyan)
                
                // Clickable Breadcrumbs or path
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        let pathParts = currentDirectory.components(separatedBy: "/").filter { !$0.isEmpty }
                        
                        Button {
                            onChangeDirectory?("/")
                        } label: {
                            Text(isSSH ? "/" : "根") // Root icon or /
                                .font(VeloDesign.Typography.monoSmall)
                        }
                        .buttonStyle(.plain)
                        
                        ForEach(0..<pathParts.count, id: \.self) { index in
                            Text("/")
                                .font(.system(size: 8))
                                .foregroundStyle(VeloDesign.Colors.textMuted)
                            
                            Button {
                                let targetPath = "/" + pathParts[0...index].joined(separator: "/")
                                onChangeDirectory?(targetPath)
                            } label: {
                                Text(pathParts[index])
                                    .font(VeloDesign.Typography.monoSmall)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .foregroundStyle(VeloDesign.Colors.textSecondary)
                
                Spacer()
                
                // Refresh button
                Button {
                    Task { await fileManager.loadDirectory(currentDirectory) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundStyle(VeloDesign.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(fileManager.isLoading)
            }
            .padding(12)
            .background(VeloDesign.Colors.darkSurface)
            
            Divider()
                .background(VeloDesign.Colors.glassBorder)
            
            ScrollView {
                VStack(spacing: 0) {
                    FileExplorerView(
                        manager: fileManager,
                        isSSH: isSSH,
                        sshConnectionString: sshConnectionString,
                        onEdit: { path in onEditFile?(path) },
                        onChangeDirectory: { path in onChangeDirectory?(path) },
                        onRunCommand: { cmd in onRunCommand?(cmd) }
                    )
                    .onAppear {
                        print("📂 [IntelligencePanel] Files tab appeared - loading: \(currentDirectory), isSSH: \(isSSH)")
                        syncWithTerminalItems()
                        fileManager.isSSH = isSSH
                        fileManager.sshConnectionString = sshConnectionString
                        Task { await fileManager.loadDirectory(currentDirectory) }
                    }
                    .onChange(of: currentDirectory) { oldDir, newDir in
                        print("📂 [IntelligencePanel] Directory changed: \(oldDir) -> \(newDir)")
                        fileManager.isSSH = isSSH
                        fileManager.sshConnectionString = sshConnectionString
                        Task { await fileManager.loadDirectory(newDir) }
                    }
                    .onChange(of: isSSH) { _, newValue in
                        print("📂 [IntelligencePanel] isSSH changed to: \(newValue)")
                        fileManager.isSSH = newValue
                        Task { await fileManager.loadDirectory(currentDirectory) }
                    }
                    .onChange(of: sshConnectionString) { _, newValue in
                        print("📂 [IntelligencePanel] sshConnectionString changed: \(newValue ?? "nil")")
                        fileManager.sshConnectionString = newValue
                        Task { await fileManager.loadDirectory(currentDirectory) }
                    }
                    .onChange(of: parsedTerminalItems) { _, _ in
                        syncWithTerminalItems()
                    }
                }
            }
        }
    }
    
    private func syncWithTerminalItems() {
        guard isSSH && fileManager.rootItems.isEmpty && !parsedTerminalItems.isEmpty else { return }
        print("📂 [IntelligencePanel] Syncing with terminal items: \(parsedTerminalItems.count) found")
        
        let host = sshConnectionString ?? "host"
        let items = parsedTerminalItems.map { name -> FileItem in
            let isDir = name.hasSuffix("/")
            let cleanName = isDir ? String(name.dropLast()) : name
            let separator = currentDirectory.hasSuffix("/") ? "" : "/"
            let fullPath = "\(currentDirectory)\(separator)\(cleanName)"
            
            return FileItem(
                id: "terminal-ssh:\(host):\(fullPath)",
                name: cleanName,
                path: fullPath,
                isDirectory: isDir,
                type: isDir ? .folder : FileType.detect(from: cleanName) == .code ? .file : .file,
                children: isDir ? [] : nil,
                size: nil,
                modificationDate: nil
            )
        }.sorted { (a, b) in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.lowercased() < b.name.lowercased()
        }
        
        // Update manager's items directly if empty
        if !items.isEmpty {
            fileManager.rootItems = items
        }
    }
    
    /// Format elapsed time for upload progress
    private func elapsedTimeString(from startTime: Date) -> String {
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s elapsed"
        } else {
            return "\(seconds)s elapsed"
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

private struct FileExplorerView: View {
    @ObservedObject var manager: FileExplorerManager
    let isSSH: Bool
    let sshConnectionString: String?
    let onEdit: (String) -> Void
    let onChangeDirectory: (String) -> Void
    let onRunCommand: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if manager.isLoading && manager.rootItems.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Scanning remote files...")
                        .font(VeloDesign.Typography.caption)
                        .foregroundStyle(VeloDesign.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if manager.rootItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: isSSH ? "network" : "folder.badge.questionmark")
                        .font(.system(size: 24))
                        .foregroundStyle(VeloDesign.Colors.textMuted)
                    
                    Text(isSSH ? "Unable to list remote files" : "Empty folder")
                        .font(VeloDesign.Typography.caption)
                        .foregroundStyle(VeloDesign.Colors.textSecondary)
                    
                    if isSSH {
                        Text("Verify SSH keys or run 'ls' in terminal")
                            .font(.system(size: 9))
                            .foregroundStyle(VeloDesign.Colors.textMuted)
                        
                        Button {
                            Task { await manager.loadDirectory(manager.rootItems.isEmpty ? "" : manager.rootItems[0].path) }
                        } label: {
                            Text("Retry Connection")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(VeloDesign.Colors.neonCyan.opacity(0.2))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(manager.rootItems) { item in
                    FileItemRow(
                        item: item,
                        manager: manager,
                        depth: 0,
                        isSSH: isSSH,
                        sshConnectionString: sshConnectionString,
                        onEdit: onEdit,
                        onChangeDirectory: onChangeDirectory,
                        onRunCommand: onRunCommand
                    )
                }
            }
        }
        // Drop destination for entire Files panel (drops to root/current directory)
        .dropDestination(for: URL.self) { urls, _ in
            print("📥 [DragDrop] ROOT Drop - URLs: \(urls.count)")
            for url in urls {
                print("📥 [DragDrop] ROOT - URL: \(url.path)")
            }
            handleRootDrop(urls: urls)
            return true
        }
    }
    
    /// Handle files dropped onto the Files panel root
    private func handleRootDrop(urls: [URL]) {
        print("📂 [DragDrop] handleRootDrop called")
        print("📂 [DragDrop] rootItems count: \(manager.rootItems.count)")
        
        guard let currentDir = manager.rootItems.first?.path.components(separatedBy: "/").dropLast().joined(separator: "/") else {
            print("❌ [DragDrop] Could not determine current directory from root items")
            return
        }
        
        print("📂 [DragDrop] Current directory: \(currentDir)")
        print("📂 [DragDrop] isSSH: \(isSSH)")
        
        for url in urls {
            let filename = url.lastPathComponent
            let destinationPath = (currentDir as NSString).appendingPathComponent(filename)
            print("📂 [DragDrop] Processing: \(filename) → \(destinationPath)")
            
            if isSSH {
                // SSH upload via SCP
                let escapedLocalPath = url.path.replacingOccurrences(of: "'", with: "'\\''")
                let escapedRemotePath = destinationPath.replacingOccurrences(of: "'", with: "'\\''")
                
                // Check if source is a directory (needs -r flag)
                var isDirectory: ObjCBool = false
                let isDir = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
                let recursiveFlag = isDir ? "-r " : ""
                print("📂 [DragDrop] Source is directory: \(isDir)")
                
                let scpCommand = "scp \(recursiveFlag)'\(escapedLocalPath)' \(sshConnectionString ?? "user@host"):'\(escapedRemotePath)'"
                print("📤 [DragDrop] SSH Upload command: \(scpCommand)")
                onRunCommand("__upload_scp__:\(scpCommand)")
            } else {
                // Local file copy
                print("📁 [DragDrop] Local copy: \(url.path) → \(destinationPath)")
                do {
                    let destURL = URL(fileURLWithPath: destinationPath)
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        print("📁 [DragDrop] Removing existing file")
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.copyItem(at: url, to: destURL)
                    print("✅ [DragDrop] Copy successful!")
                    // Refresh file list
                    Task {
                        await manager.loadDirectory(currentDir)
                    }
                } catch {
                    print("❌ [DragDrop] Failed to copy file: \(error)")
                }
            }
        }
    }
}

private struct FileItemRow: View {
    let item: FileItem
    @ObservedObject var manager: FileExplorerManager
    let depth: Int
    let isSSH: Bool
    let sshConnectionString: String?
    let onEdit: (String) -> Void
    let onChangeDirectory: (String) -> Void
    let onRunCommand: (String) -> Void
    
    @State private var isHovered = false
    @State private var showingRename = false
    @State private var showingInfo = false
    @State private var newName = ""
    @State private var isExpandingRemote = false
    @State private var isDropTarget = false  // For drop zone highlighting
    
    // Use FileType from FileActionView
    private var fileType: FileType {
        item.isDirectory ? .folder : FileType.detect(from: item.name)
    }
    
    private var rowContent: some View {
        HStack(spacing: 6) {
            // Indent
            if depth > 0 {
                Rectangle()
                    .fill(VeloDesign.Colors.glassBorder.opacity(0.3))
                    .frame(width: 1)
                    .padding(.leading, CGFloat(depth * 12) - 6)
                    .padding(.trailing, 5)
            }
            
            // Chevron for folders (handled separately for expansion)
            if item.isDirectory {
                ZStack {
                    if isExpandingRemote {
                        ProgressView()
                            .scaleEffect(0.4)
                    } else {
                        Image(systemName: item.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(VeloDesign.Colors.textMuted)
                    }
                }
                .frame(width: 12)
            } else {
                Spacer().frame(width: 12)
            }
            
            // Icon
            Image(systemName: fileType.icon)
                .font(.system(size: 11))
                .foregroundStyle(isHovered ? VeloDesign.Colors.textPrimary : fileType.color.opacity(0.8))
                .frame(width: 14)
            
            // Name
            if showingRename {
                TextField("Rename", text: $newName)
                    .textFieldStyle(.plain)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundStyle(VeloDesign.Colors.textPrimary)
                    .onSubmit {
                        manager.rename(item: item, to: newName)
                        showingRename = false
                    }
            } else {
                Text(item.name)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundStyle(isHovered ? VeloDesign.Colors.neonCyan : VeloDesign.Colors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Quick actions
            if isHovered && !showingRename {
                HStack(spacing: 8) {
                    if !item.isDirectory {
                        Image(systemName: "pencil")
                            .help("Edit File")
                    }
                    if isSSH {
                        Image(systemName: "arrow.down.circle")
                            .help("Download")
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(VeloDesign.Colors.textMuted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isHovered ? VeloDesign.Colors.neonCyan.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            rowView
            childrenView
        }
    }
    
    private var rowView: some View {
        rowContent
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.1)) {
                    isHovered = hovering
                }
            }
            .onTapGesture {
                if item.isDirectory {
                    toggleExpansion()
                } else {
                    onEdit(item.path)
                }
            }
            .contextMenu {
                fileContextMenu
            }
            .popover(isPresented: $showingInfo) {
                FileInfoPopover(item: item)
            }
            .modifier(DragAndDropModifier(
                item: item,
                isSSH: isSSH,
                sshConnectionString: sshConnectionString,
                onRunCommand: onRunCommand,
                handleFileDrop: handleFileDrop,
                createSSHDragItem: createSSHDragItem,
                isDropTarget: $isDropTarget,
                fileType: fileType
            ))
    }

    @ViewBuilder
    private var childrenView: some View {
        if item.isExpanded, let children = item.children {
            if children.isEmpty && isSSH {
                HStack {
                    Spacer().frame(width: CGFloat((depth + 1) * 12) + 18)
                    Text("No items found")
                        .font(.system(size: 9))
                        .foregroundStyle(VeloDesign.Colors.textMuted)
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                ForEach(children) { child in
                    FileItemRow(
                        item: child,
                        manager: manager,
                        depth: depth + 1,
                        isSSH: isSSH,
                        sshConnectionString: sshConnectionString,
                        onEdit: onEdit,
                        onChangeDirectory: onChangeDirectory,
                        onRunCommand: onRunCommand
                    )
                }
            }
        }
    }
}

// Separate modifier to help compiler with type-checking complexity
private struct DragAndDropModifier: ViewModifier {
    let item: FileItem
    let isSSH: Bool
    let sshConnectionString: String?
    let onRunCommand: (String) -> Void
    let handleFileDrop: ([URL], String) -> Void
    let createSSHDragItem: () -> NSItemProvider
    @Binding var isDropTarget: Bool
    let fileType: FileType

    func body(content: Content) -> some View {
        content
            .onDrag {
                isSSH ? createSSHDragItem() : NSItemProvider(object: URL(fileURLWithPath: item.path) as NSURL)
            }
            .dropDestination(for: URL.self) { urls, _ in
                if item.isDirectory {
                    handleFileDrop(urls, item.path)
                    return true
                }
                return false
            } isTargeted: { targeted in
                isDropTarget = targeted
            }
            .overlay {
                if isDropTarget {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(VeloDesign.Colors.neonCyan, lineWidth: 2)
                        .background(VeloDesign.Colors.neonCyan.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
    }
}

extension FileItemRow {
    
    private func toggleExpansion() {
        if isSSH && !item.isExpanded && (item.children == nil || item.children!.isEmpty) {
            isExpandingRemote = true
            Task {
                manager.toggleExpansion(path: item.path)
                // Wait for manager to finish (simulated or tracked)
                try? await Task.sleep(nanoseconds: 500_000_000)
                isExpandingRemote = false
            }
        } else {
            manager.toggleExpansion(path: item.path)
        }
    }
    
    // MARK: - SSH Drag Item Helper
    
    /// Triggers SSH file download and returns a simple item provider
    /// Note: Due to macOS limitations, SSH files are downloaded to ~/Downloads
    /// and a notification is shown when ready
    private func createSSHDragItem() -> NSItemProvider {
        let fileItem = self.item
        let sshHost = sshConnectionString ?? "user@host"
        let isDir = fileItem.isDirectory
        
        // Download destination: ~/Downloads with EXACT original filename
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destURL = downloadsURL.appendingPathComponent(fileItem.name)
        
        print("🚀 [DragOut] Triggering download for: \(fileItem.name) to ~/Downloads")
        
        // Trigger download to Downloads folder
        let flag = isDir ? "-r " : ""
        let escapedLocal = destURL.path.replacingOccurrences(of: "'", with: "'\\''")
        let escapedRemote = fileItem.path.replacingOccurrences(of: "'", with: "'\\''")
        let scpCmd = "__download_scp__:scp \(flag)\(sshHost):'\(escapedRemote)' '\(escapedLocal)'"
        
        onRunCommand(scpCmd)
        
        // Create item provider with explicit suggested name to preserve original filename
        let provider = NSItemProvider()
        provider.suggestedName = fileItem.name
        
        // Register as file URL with the exact filename
        provider.registerFileRepresentation(
            forTypeIdentifier: isDir ? "public.folder" : "public.item",
            visibility: .all
        ) { completion in
            // Return the destination URL where file will be downloaded
            completion(destURL, false, nil)
            return nil
        }
        
        return provider
    }
    
    /// Handle files dropped onto this folder
    private func handleFileDrop(urls: [URL], toFolder destinationPath: String) {
        print("📂 [DragDrop] handleFileDrop called")
        print("📂 [DragDrop] Destination: \(destinationPath)")
        print("📂 [DragDrop] isSSH: \(isSSH)")
        print("📂 [DragDrop] sshConnectionString: \(sshConnectionString ?? "nil")")
        
        for url in urls {
            let filename = url.lastPathComponent
            let destinationFullPath = (destinationPath as NSString).appendingPathComponent(filename)
            print("📂 [DragDrop] Processing: \(filename) → \(destinationFullPath)")
            
            if isSSH {
                // SSH upload via SCP
                let escapedLocalPath = url.path.replacingOccurrences(of: "'", with: "'\\''")
                let escapedRemotePath = destinationFullPath.replacingOccurrences(of: "'", with: "'\\''")
                
                // Check if source is a directory (needs -r flag)
                var isDirectory: ObjCBool = false
                let isDir = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
                let recursiveFlag = isDir ? "-r " : ""
                print("📂 [DragDrop] Source is directory: \(isDir)")
                
                let scpCommand = "scp \(recursiveFlag)'\(escapedLocalPath)' \(sshConnectionString ?? "user@host"):'\(escapedRemotePath)'"
                print("📤 [DragDrop] SSH Upload command: \(scpCommand)")
                onRunCommand("__upload_scp__:\(scpCommand)")
            } else {
                // Local file copy
                print("📁 [DragDrop] Local copy: \(url.path) → \(destinationFullPath)")
                do {
                    let destURL = URL(fileURLWithPath: destinationFullPath)
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        print("📁 [DragDrop] Removing existing file at destination")
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.copyItem(at: url, to: destURL)
                    print("✅ [DragDrop] Copy successful!")
                    // Refresh file list
                    Task {
                        await manager.loadDirectory((destinationPath as NSString).deletingLastPathComponent)
                    }
                } catch {
                    print("❌ [DragDrop] Failed to copy file: \(error)")
                }
            }
        }
    }
    
    @ViewBuilder
    private var fileContextMenu: some View {
        Group {
            // Main Action
            Button {
                if item.isDirectory {
                    toggleExpansion()
                } else {
                    onEdit(item.path)
                }
            } label: {
                Label(item.isDirectory ? (item.isExpanded ? "Collapse" : "Expand") : "Edit File", 
                      systemImage: item.isDirectory ? (item.isExpanded ? "chevron.down" : "chevron.right") : "pencil")
            }
            
            Divider()

            if !isSSH {
                Button {
                    let url = URL(fileURLWithPath: item.path)
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open with Default App", systemImage: "arrow.up.forward.square")
                }

                Button {
                    let url = URL(fileURLWithPath: item.path)
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
            }

            if item.isDirectory {
                Button {
                    onRunCommand("cd \"\(item.path)\"")
                } label: {
                    Label("cd to Folder", systemImage: "terminal")
                }
                
                Button {
                    onRunCommand("ls -la \"\(item.path)\"")
                } label: {
                    Label("List Contents", systemImage: "list.bullet")
                }
            } else {
                Button {
                    onRunCommand("cat \"\(item.path)\"")
                } label: {
                    Label("View Content (cat)", systemImage: "eye")
                }
            }
            
            Divider()
            
            // SSH Specific Actions
            if isSSH {
                Button {
                    showSSHDownloadDialog(isFolder: item.isDirectory)
                } label: {
                    Label("📥 Download...", systemImage: "arrow.down.circle")
                }
                
                Button {
                    onRunCommand("du -sh \"\(item.path)\"")
                } label: {
                    Label("Get Size", systemImage: "chart.bar")
                }

                if !item.isDirectory {
                    Button {
                        onRunCommand("ls -la \"\(item.path)\" && file \"\(item.path)\"")
                    } label: {
                        Label("Get File Info", systemImage: "info.circle")
                    }
                }

                Divider()
            }

            // MARK: - Common Actions
            Button {
                newName = item.name
                showingRename = true
            } label: {
                Label("Rename", systemImage: "pencil.line")
            }

            Button {
                onRunCommand("__copy_name__:\(item.name)")
            } label: {
                Label("Copy Name", systemImage: "textformat")
            }

            Button {
                onRunCommand("__copy_path__:\(item.path)")
            } label: {
                Label("Copy Path", systemImage: "doc.on.clipboard")
            }

            Divider()

            Button {
                onChangeDirectory(item.path)
            } label: {
                Label("Change CWD to here", systemImage: "arrow.right.circle")
            }
            .disabled(!item.isDirectory)

            Button {
                showingInfo = true
            } label: {
                Label("Get Info", systemImage: "info.circle")
            }

            Divider()

            // MARK: - Destructive Actions (with confirmation prompt)
            Button(role: .destructive) {
                onRunCommand("rm -i \"\(item.path)\"")
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    /// Type-specific actions for local files (matching FileActionView behavior)
    @ViewBuilder
    private var localFileTypeActions: some View {
        let ext = (item.name as NSString).pathExtension.lowercased()

        switch fileType {
        case .script:
            Button {
                switch ext {
                case "sh", "bash":
                    onRunCommand("bash \"\(item.path)\"")
                case "zsh":
                    onRunCommand("zsh \"\(item.path)\"")
                default:
                    onRunCommand("sh \"\(item.path)\"")
                }
            } label: {
                Label("Run Script", systemImage: "play.fill")
            }

            Button {
                onRunCommand("chmod +x \"\(item.path)\"")
            } label: {
                Label("Make Executable", systemImage: "lock.open")
            }

        case .code:
            switch ext {
            case "py":
                Button {
                    onRunCommand("python3 \"\(item.path)\"")
                } label: {
                    Label("Run Python", systemImage: "play.fill")
                }
            case "js":
                Button {
                    onRunCommand("node \"\(item.path)\"")
                } label: {
                    Label("Run Node", systemImage: "play.fill")
                }
            case "swift":
                Button {
                    onRunCommand("swift \"\(item.path)\"")
                } label: {
                    Label("Run Swift", systemImage: "play.fill")
                }
            case "go":
                Button {
                    onRunCommand("go run \"\(item.path)\"")
                } label: {
                    Label("Run Go", systemImage: "play.fill")
                }
            case "rb":
                Button {
                    onRunCommand("ruby \"\(item.path)\"")
                } label: {
                    Label("Run Ruby", systemImage: "play.fill")
                }
            case "php":
                Button {
                    onRunCommand("php \"\(item.path)\"")
                } label: {
                    Label("Run PHP", systemImage: "play.fill")
                }
            default:
                EmptyView()
            }

        case .archive:
            let baseName = (item.name as NSString).deletingPathExtension
            let parentDir = (item.path as NSString).deletingLastPathComponent

            switch ext {
            case "zip", "ipa", "apk":
                Button {
                    onRunCommand("unzip -o \"\(item.path)\" -d \"\(parentDir)\"")
                } label: {
                    Label("Extract Here", systemImage: "arrow.down.doc")
                }
                Button {
                    onRunCommand("unzip -o \"\(item.path)\" -d \"\(parentDir)/\(baseName)\"")
                } label: {
                    Label("Extract to Folder", systemImage: "folder.badge.plus")
                }
                Button {
                    onRunCommand("unzip -l \"\(item.path)\"")
                } label: {
                    Label("List Contents", systemImage: "list.bullet")
                }
            case "tar":
                Button {
                    onRunCommand("tar -xf \"\(item.path)\" -C \"\(parentDir)\"")
                } label: {
                    Label("Extract Here", systemImage: "arrow.down.doc")
                }
                Button {
                    onRunCommand("tar -tf \"\(item.path)\"")
                } label: {
                    Label("List Contents", systemImage: "list.bullet")
                }
            case "gz":
                Button {
                    if item.name.hasSuffix(".tar.gz") {
                        onRunCommand("tar -xzf \"\(item.path)\" -C \"\(parentDir)\"")
                    } else {
                        onRunCommand("gunzip -k \"\(item.path)\"")
                    }
                } label: {
                    Label(item.name.hasSuffix(".tar.gz") ? "Extract Here" : "Decompress", systemImage: "arrow.down.doc")
                }
            case "dmg":
                Button {
                    onRunCommand("hdiutil attach \"\(item.path)\"")
                } label: {
                    Label("Mount", systemImage: "externaldrive.badge.plus")
                }
            default:
                EmptyView()
            }

        case .audio:
            Button {
                onRunCommand("afplay \"\(item.path)\"")
            } label: {
                Label("Play Audio", systemImage: "play.fill")
            }

        case .application:
            Button {
                onRunCommand("open -a \"\(item.path)\"")
            } label: {
                Label("Launch", systemImage: "play.fill")
            }
            Button {
                onRunCommand("open \"\(item.path)/Contents\"")
            } label: {
                Label("Show Package Contents", systemImage: "folder")
            }

        default:
            EmptyView()
        }
    }

    // MARK: - SSH Download Dialog Logic (Synced from InteractiveFileView)
    
    private func showSSHDownloadDialog(isFolder: Bool) {
        if isFolder {
            let openPanel = NSOpenPanel()
            openPanel.title = "Select Download Destination"
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.canCreateDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            openPanel.prompt = "Download Here"
            
            openPanel.begin { response in
                if response == .OK, let url = openPanel.url {
                    self.performSCPDownload(destinationURL: url, isFolder: true)
                }
            }
        } else {
            let savePanel = NSSavePanel()
            savePanel.title = "Save to Local"
            savePanel.nameFieldStringValue = item.name
            savePanel.canCreateDirectories = true
            savePanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    self.performSCPDownload(destinationURL: url, isFolder: false)
                }
            }
        }
    }
    
    private func performSCPDownload(destinationURL: URL, isFolder: Bool) {
        var localPath = destinationURL.path
        var remotePath = item.path

        // Clean up paths
        remotePath = stripANSISequences(from: remotePath)
        localPath = stripANSISequences(from: localPath)

        if remotePath.hasSuffix("/") {
            remotePath = String(remotePath.dropLast())
        }

        let scpFlag = isFolder ? "-r " : ""
        if isFolder {
            let folderName = (remotePath as NSString).lastPathComponent
            localPath = (localPath as NSString).appendingPathComponent(folderName)
        }

        let userHost = sshConnectionString ?? "user@host"
        let downloadCommand = "scp \(scpFlag)\(userHost):\"\(remotePath)\" \"\(localPath)\""
        onRunCommand("__download_scp__:\(downloadCommand)")
    }

    private func stripANSISequences(from text: String) -> String {
        var cleaned = text
        let controlChars = CharacterSet(charactersIn: "\u{0001}"..."\u{001F}").subtracting(CharacterSet(charactersIn: "\n\t"))
        cleaned = cleaned.components(separatedBy: controlChars).joined()
        cleaned = cleaned.replacingOccurrences(of: "]\\d+;[^\n]*", with: "", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }
}

private struct FileInfoPopover: View {
    let item: FileItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(item.isDirectory ? VeloDesign.Colors.neonCyan : ColorTokens.textTertiary)
                Text(item.name)
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
            }
            
            Divider()
                .background(VeloDesign.Colors.glassBorder)
            
            VStack(alignment: .leading, spacing: 6) {
                InfoRow(label: "Type", value: item.isDirectory ? "Folder" : "File")
                InfoRow(label: "Location", value: item.path)
                if let size = item.size {
                    InfoRow(label: "Size", value: formattedSize(size))
                }
            }
        }
        .padding()
        .frame(width: 300)
        .background(VeloDesign.Colors.darkSurface)
    }
    
    private func InfoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ColorTokens.textTertiary)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ColorTokens.textSecondary)
                .lineLimit(3)
        }
    }
    
    private func formattedSize(_ size: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
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
        ],
        parsedTerminalItems: []
    )
    .frame(width: 300, height: 600)
}
