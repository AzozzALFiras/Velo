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
    
    // Column visibility
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    // Input state
    @State private var inputText = ""
    @State private var isExecuting = false
    
    // Settings
    @State private var showSettings = false
    @State private var showShortcuts = false
    
    // SSH Connections (loaded from existing SSHManager or storage)
    @State private var sshConnections: [SSHConnection] = []
    
    // AI state
    @State private var aiMessages: [AIMessage] = []
    @State private var recentErrors: [ErrorItem] = []
    @State private var suggestions: [SuggestionItem] = []
    @State private var scripts: [AutoScript] = []
    
    // MARK: - Initialization
    
    init() {
        let history = CommandHistoryManager()
        _historyManager = StateObject(wrappedValue: history)
        _tabManager = StateObject(wrappedValue: TabManager(historyManager: history))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left Sidebar
            DashboardSidebar(
                selectedSection: $sidebarSection,
                sessions: tabManager.sessions,
                activeSessionId: tabManager.activeSessionId,
                sshConnections: sshConnections,
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
                
                // Main workspace area
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
                            onRunScript: runScript
                        )
                        .frame(width: 340)
                        .transition(.move(edge: .trailing))
                    }
                }
            }
            .background(ColorTokens.layer0)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    toolbarItems
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .background(ColorTokens.layer0)
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
            // Set the command on the active session
            activeSession?.inputText = command
            activeSession?.executeCommand()
            
            // Simulate completion (in real implementation, this would come from terminal output)
            try? await Task.sleep(for: .seconds(0.5))
            
            // Update block status (would be driven by actual execution)
            block.status = .success
            block.endTime = Date()
            block.appendOutput(text: "Command executed successfully")
            
            isExecuting = false
            
            // Refresh context after command
            await contextManager.refreshGitStatus()
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
        } else {
            aiMessages.append(AIMessage(content: query, isUser: true))
            showIntelligencePanel = true
            
            // Trigger AI response (would connect to existing CloudAIService)
            Task {
                // Simulate AI response
                try? await Task.sleep(for: .seconds(1))
                aiMessages.append(AIMessage(
                    content: "I'll help you with that. Here's a suggestion:",
                    isUser: false,
                    codeBlocks: ["git status"]
                ))
            }
        }
    }
    
    private func sendAIMessage(_ message: String) {
        aiMessages.append(AIMessage(content: message, isUser: true))
        
        // Connect to existing AI service
        activeSession?.askAI(query: message)
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
