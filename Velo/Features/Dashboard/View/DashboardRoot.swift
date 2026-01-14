//
//  DashboardRoot.swift
//  Velo
//
//  Dashboard Redesign - Main Root View
//  3-Panel NavigationSplitView layout with Sidebar, Workspace, Intelligence Panel
//

import SwiftUI

// MARK: - Dashboard Root

/// The main dashboard view with 3-panel layout using NavigationSplitView
struct DashboardRoot: View {
    
    // MARK: - State Management
    
    // Shared managers (using existing infrastructure)
    @StateObject private var historyManager = CommandHistoryManager()
    @StateObject private var tabManager: TabManager
    
    // Context manager (new Observation-based)
    @State private var contextManager = ContextManager()
    
    // System monitor for CPU/RAM/Disk stats
    @State private var systemMonitor = SystemMonitor()
    
    // Command shortcuts manager
    @State private var shortcutsManager = CommandShortcutsManager()
    
    // Command blocks for current session
    @State private var blocks: [CommandBlock] = []
    
    // Panel visibility
    @State private var showSidebar = true
    @State private var showIntelligencePanel = true
    @State private var sidebarSection: SidebarSection? = .sessions
    @State private var selectedIntelligenceTab: IntelligenceTab = .chat
    @State private var editingFile: String? = nil
    @State private var editingFileContent: String = ""
    @State private var showEditor = false
    
    // Column visibility
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    // Input state
    @State private var inputText = ""
    @State private var isExecuting = false
    
    // Alerts & UI
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showSettings = false
    @State private var showShortcuts = false
    
    // AI state
    @State private var aiMessages: [AIMessage] = []
    @State private var recentErrors: [ErrorItem] = []
    @State private var suggestions: [SuggestionItem] = []
    @State private var scripts: [AutoScript] = []
    
    // Command Bar
    @State private var showCommandBar = false
    @StateObject private var sshManager = SSHManager()
    @StateObject private var aiService = CloudAIService()
    @State private var dockerManager = DockerManager()
    
    // MARK: - Initialization
    
    init() {
        let history = CommandHistoryManager()
        _historyManager = StateObject(wrappedValue: history)
        _tabManager = StateObject(wrappedValue: TabManager(historyManager: history))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                // Left Sidebar
                DashboardSidebar(
                    selectedSection: $sidebarSection,
                    sessions: tabManager.sessions,
                    activeSessionId: tabManager.activeSessionId,
                    sshConnections: sshManager.connections,
                    onNewSession: { tabManager.addSession() },
                    onSelectSession: { id in tabManager.switchToSession(id: id) },
                    onConnectSSH: connectToSSH,
                    onNewSSH: { showSettings = true },
                    onAIAction: handleAIAction,
                    onOpenSettings: { showSettings = true },
                    onOpenShortcuts: { showShortcuts = true }
                )
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
            } detail: {
                // Main Content Area - System Info + Workspace + Intelligence Panel
                VStack(spacing: 0) {
                    // System Info Bar
                    SystemInfoBar(
                        monitor: systemMonitor,
                        isSSH: isCurrentSessionSSH,
                        serverName: currentSSHServerName
                    )
                    
                    Divider()
                        .background(ColorTokens.border)
                    
                    // Main workspace area or specialized panel
                    Group {
                        if sidebarSection == .git {
                        GitPanel(contextManager: contextManager, currentDirectory: currentDirectory)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                        } else if sidebarSection == .docker {
                            DockerPanel(manager: dockerManager)
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                        } else {
                            HStack(spacing: 0) {
                                // Workspace
                                DashboardWorkspace(
                                    contextManager: contextManager,
                                    blocks: blocks,
                                    inputText: $inputText,
                                    isExecuting: $isExecuting,
                                    currentDirectory: currentDirectory,
                                    onExecute: executeCommand,
                                    onBlockAction: handleBlockAction,
                                    onRetryBlock: retryBlock,
                                    onAskAI: askAI,
                                    onOpenPath: { path in
                                        editFile(at: path)
                                    },
                                    onSync: gitSync,
                                    onBranchSwitch: showBranchSwitcher,
                                    onShowShortcuts: { showShortcuts = true },
                                    onShowFiles: {
                                        selectedIntelligenceTab = .files
                                        withAnimation { showIntelligencePanel = true }
                                    },
                                    onShowHistory: {
                                        selectedIntelligenceTab = .history
                                        withAnimation { showIntelligencePanel = true }
                                    }
                                )
                                
                                // Intelligence Panel
                                if showIntelligencePanel {
                                    Divider()
                                        .background(ColorTokens.border)
                                    
                                    IntelligencePanel(
                                        selectedTab: $selectedIntelligenceTab,
                                        historyManager: historyManager,
                                        aiMessages: aiMessages,
                                        recentErrors: recentErrors,
                                        suggestions: suggestions,
                                        scripts: scripts,
                                        currentDirectory: currentDirectory,
                                        onSendMessage: sendAIMessage,
                                        onRunCommand: runCommand,
                                        onExplainError: explainError,
                                        onFixError: fixError,
                                        onRunScript: runScript,
                                        onEditFile: { path in
                                            editFile(at: path)
                                        },
                                        onChangeDirectory: { path in
                                            tabManager.activeSession?.currentDirectory = path
                                            // Trigger context update
                                            Task { await contextManager.updateContext(for: path) }
                                        }
                                    )
                                    .frame(width: 340)
                                    .transition(.move(edge: .trailing))
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                }
                .background(ColorTokens.layer0)
                .sheet(isPresented: $showEditor) {
                    if let path = editingFile {
                        RemoteFileEditorView(
                            filename: (path as NSString).lastPathComponent,
                            remotePath: path,
                            sshConnectionString: currentSSHServerName ?? "local",
                            initialContent: editingFileContent,
                            onSave: { newContent in
                                saveFile(at: path, content: newContent)
                            },
                            onCancel: { showEditor = false }
                        )
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        toolbarItems
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(onClose: { showSettings = false })
            }
            .sheet(isPresented: $showShortcuts) {
                ShortcutsPanel(manager: shortcutsManager) { shortcut in
                    showShortcuts = false
                    inputText = shortcut.command
                    executeCommand()
                } onAddShortcut: {
                    // Future: show add shortcut sheet
                }
                .frame(width: 400, height: 500)
            }
            .onAppear {
                loadSSHConnections()
                setupInitialState()
                systemMonitor.startMonitoring()
            }
            .onDisappear {
                systemMonitor.stopMonitoring()
            }
            .onChange(of: tabManager.activeSessionId) { _, _ in
                syncWithActiveSession()
            }
            .blur(radius: showCommandBar ? 8 : 0)
            .disabled(showCommandBar)
            
            // Global Command Bar Overlay
            if showCommandBar {
                CommandBarView(
                    isPresented: $showCommandBar,
                    commands: historyManager.recentCommands.map { $0.command },
                    servers: sshManager.connections.map { $0.name },
                    files: [], // Future: recent files
                    onRunCommand: { cmd in
                        inputText = cmd
                        executeCommand()
                    },
                    onSelectServer: { name in
                        if let conn = sshManager.connections.first(where: { $0.name == name }) {
                            connectToSSH(conn)
                        }
                    },
                    onOpenFile: { path in
                        editFile(at: path)
                    },
                    onAskAI: { query in
                        askAI(query)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(100)
            }
        }
        .background(
            // Hidden button for keyboard shortcut
            Button("") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showCommandBar.toggle()
                }
            }
            .keyboardShortcut("k", modifiers: [.command])
            .opacity(0)
        )
    }
    
    // MARK: - Computed Properties
    
    private var currentDirectory: String {
        tabManager.activeSession?.currentDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
    }
    
    private var activeSession: TerminalViewModel? {
        tabManager.activeSession
    }
    
    // SSH session detection for SystemInfoBar
    private var isCurrentSessionSSH: Bool {
        tabManager.activeSession?.isSSHActive ?? false
    }
    
    private var currentSSHServerName: String? {
        tabManager.activeSession?.activeSSHConnectionString
    }
    
    // MARK: - Toolbar
    
    @ViewBuilder
    private var toolbarItems: some View {
        // Toggle Intelligence Panel
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                showIntelligencePanel.toggle()
            }
        } label: {
            Image(systemName: showIntelligencePanel ? "sidebar.right" : "sidebar.right")
                .foregroundStyle(showIntelligencePanel ? ColorTokens.accentPrimary : ColorTokens.textSecondary)
        }
        .help(showIntelligencePanel ? "Hide Intelligence Panel" : "Show Intelligence Panel")
    }
    
    // MARK: - Actions
    
    private func executeCommand() {
        guard !inputText.isEmpty, !isExecuting else { return }
        
        var command = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for shortcut expansion
        if let expanded = shortcutsManager.expandShortcut(command) {
            command = expanded
        }
        
        inputText = ""
        
        // Create a new block
        let block = CommandBlock(
            command: command,
            status: .running,
            workingDirectory: currentDirectory
        )
        blocks.append(block)
        
        // Execute via terminal VM
        isExecuting = true
        
        Task {
            guard let session = activeSession else {
                block.status = .error
                block.appendOutput(text: "No active session", isError: true)
                isExecuting = false
                return
            }
            
            // Set the command on the active session
            session.inputText = command
            
            // Execute the command
            session.executeCommand()
            
            // Wait for command to complete (observe isExecuting flag)
            while session.isExecuting {
                try? await Task.sleep(for: .milliseconds(100))
                
                // Stream output to block as it arrives
                let newOutput = session.outputLines.suffix(max(0, session.outputLines.count - block.output.count))
                for line in newOutput {
                    block.appendOutput(text: line.text, isError: line.isError)
                }
            }
            
            // Final sync of any remaining output
            let remainingOutput = session.outputLines.suffix(max(0, session.outputLines.count - block.output.count))
            for line in remainingOutput {
                block.appendOutput(text: line.text, isError: line.isError)
            }
            
            // Update block status based on exit code
            let exitCode = session.lastExitCode
            block.status = (exitCode == 0) ? .success : .error
            block.endTime = Date()
            block.exitCode = exitCode
            
            // Update current directory if changed
            if session.currentDirectory != currentDirectory {
                tabManager.activeSession?.currentDirectory = session.currentDirectory
            }
            
            // Add to history
            historyManager.addCommand(CommandModel(
                command: command,
                output: block.output.map { $0.text }.joined(separator: "\n"),
                exitCode: exitCode,
                duration: block.duration,
                workingDirectory: currentDirectory,
                context: .detect(from: command)
            ))
            
            isExecuting = false
            
            // Refresh context after command
            await contextManager.updateContext(for: session.currentDirectory)
        }
    }
    
    private func handleBlockAction(_ block: CommandBlock, _ action: BlockAction) {
        switch action {
        case .delete:
            blocks.removeAll { $0.id == block.id }
        case .pin:
            // Handle pin
            break
        default:
            // Other actions handled by CommandBlockView
            break
        }
    }
    
    private func retryBlock(_ block: CommandBlock) {
        inputText = block.command
        executeCommand()
    }
    
    private func askAI(_ query: String) {
        if query.isEmpty {
            // Just open the panel and focus
            showIntelligencePanel = true
            selectedIntelligenceTab = .chat
        } else {
            aiMessages.append(AIMessage(content: query, isUser: true))
            showIntelligencePanel = true
            selectedIntelligenceTab = .chat
            
            // Use CloudAIService for real response
            Task {
                await aiService.sendMessage(query)
                
                // Sync AI service messages to local state
                if let lastMessage = aiService.messages.last, lastMessage.role == .assistant {
                    // Extract code blocks from response
                    let codeBlocks = extractCodeBlocks(from: lastMessage.content)
                    aiMessages.append(AIMessage(
                        content: lastMessage.content,
                        isUser: false,
                        codeBlocks: codeBlocks
                    ))
                }
            }
        }
    }
    
    private func sendAIMessage(_ message: String) {
        askAI(message)
    }
    
    /// Extract code blocks from markdown-style AI response
    private func extractCodeBlocks(from text: String) -> [String] {
        var blocks: [String] = []
        let pattern = "```(?:\\w+)?\\n([\\s\\S]*?)```"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            
            for match in matches {
                if let codeRange = Range(match.range(at: 1), in: text) {
                    let code = String(text[codeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !code.isEmpty {
                        blocks.append(code)
                    }
                }
            }
        }
        
        return blocks
    }
    
    private func runCommand(_ command: String) {
        inputText = command
        executeCommand()
    }
    
    private func explainError(_ error: ErrorItem) {
        askAI("Explain this error: \(error.message)")
    }
    
    private func fixError(_ error: ErrorItem) {
        askAI("How do I fix this error: \(error.message)\n\nFrom command: \(error.command)")
    }
    
    private func runScript(_ script: AutoScript) {
        for command in script.commands {
            inputText = command
            executeCommand()
        }
    }
    
    private func editFile(at path: String) {
        let url = URL(fileURLWithPath: path)
        
        // 1. Check if it's a binary file or too large (simple heuristic)
        // For now, try to load as string, if it fails, open with system
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            
            // Heuristic for binary: check for null bytes in the first 8kb
            let range = 0..<min(data.count, 8192)
            let isBinary = data.subdata(in: range).contains(0)
            
            if isBinary {
                // Open with system
                NSWorkspace.shared.open(url)
                return
            }
            
            if data.count > 1024 * 1024 * 2 { // > 2MB
                alertTitle = "File Too Large"
                alertMessage = "This file is too large to open in the dashboard editor. Opening with system default instead."
                showAlert = true
                NSWorkspace.shared.open(url)
                return
            }
            
            guard let content = String(data: data, encoding: .utf8) else {
                // Not UTF-8, probably binary or encoded differently
                NSWorkspace.shared.open(url)
                return
            }
            
            editingFile = path
            editingFileContent = content
            showEditor = true
            
        } catch {
            alertTitle = "Error Opening File"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
    
    private func saveFile(at path: String, content: String) {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            editingFileContent = content
        } catch {
            alertTitle = "Save Failed"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
    
    private func gitSync() {
        inputText = "git pull && git push"
        executeCommand()
    }
    
    private func showBranchSwitcher() {
        // Would open a branch picker popover
        print("Show branch switcher")
    }
    
    private func handleAIAction(_ action: AIQuickAction) {
        showIntelligencePanel = true
        
        switch action {
        case .quickFix:
            if let lastError = recentErrors.last {
                fixError(lastError)
            }
        case .explain:
            if let lastBlock = blocks.last {
                askAI("Explain what this command does: \(lastBlock.command)")
            }
        case .generate:
            askAI("Generate a script to")
        case .debug:
            askAI("Help me debug the last error")
        }
    }
    
    private func connectToSSH(_ connection: SSHConnection) {
        tabManager.createSSHSession(
            host: connection.host,
            user: connection.username,
            port: connection.port,
            keyPath: connection.privateKeyPath,
            password: nil  // Would be fetched from keychain
        )
    }
    
    // MARK: - Setup
    
    private func loadSSHConnections() {
        // Load from existing SSHManager or UserDefaults
        // For now, empty - would integrate with existing SSH infrastructure
    }
    
    private func setupInitialState() {
        // Initial context detection
        Task {
            await contextManager.updateContext(for: currentDirectory)
        }
    }
    
    private func syncWithActiveSession() {
        // Sync blocks with active session's history
        // In a real implementation, blocks would be derived from the session's output
    }
}

// MARK: - Preview

#Preview {
    DashboardRoot()
        .frame(width: 1400, height: 800)
}
