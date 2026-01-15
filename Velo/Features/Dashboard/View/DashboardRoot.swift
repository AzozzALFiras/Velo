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
    
    // Panel visibility
    @State private var showSidebar = true
    @State private var showIntelligencePanel = true
    @State private var sidebarSection: SidebarSection? = .sessions
    @State private var selectedIntelligenceTab: IntelligenceTab = .chat
    @State private var editingFile: String? = nil
    @State private var editingFileContent: String = ""
    @State private var showEditor = false
    @State private var isFetchingFile = false
    
    // Column visibility
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    // Input state
    @State private var inputText = ""
    @State private var isExecuting = false
    
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showSettings = false
    @State private var showShortcuts = false
    
    // SSH Password Prompt
    @State private var showPasswordPrompt = false
    @State private var passwordInput = ""
    @State private var pendingSSHConnection: SSHConnection? = nil
    @State private var showSSHConnectionSheet = false
    
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
                // Main Content Area - System Info + Sessions + Workspace + Intelligence Panel
                VStack(spacing: 0) {
                    // System Info Bar
                    SystemInfoBar(
                        monitor: systemMonitor,
                        isSSH: isCurrentSessionSSH,
                        serverName: currentSSHServerName
                    )
                    
                    // Session Tabs
                    SessionTabsBar(
                        sessions: tabManager.sessions,
                        activeSessionId: tabManager.activeSessionId,
                        onSelectSession: { id in tabManager.switchToSession(id: id) },
                        onCloseSession: { id in tabManager.closeSession(id: id) },
                        onNewSession: { tabManager.addSession() }
                    )
                    
                    Divider()
                        .background(ColorTokens.border)
                    
                    // Main workspace area or specialized panel
                    if sidebarSection == .git {
                        GitPanel(contextManager: contextManager, currentDirectory: currentDirectory)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                    } else if sidebarSection == .docker {
                        DockerPanel(manager: dockerManager)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                    } else if let session = tabManager.activeSession {
                        ActiveSessionContainer(
                            session: session,
                            contextManager: contextManager,
                            historyManager: historyManager,
                            aiMessages: aiMessages,
                            recentErrors: recentErrors,
                            suggestions: suggestions,
                            scripts: scripts,
                            showIntelligencePanel: $showIntelligencePanel,
                            selectedIntelligenceTab: $selectedIntelligenceTab,
                            inputText: $inputText,
                            isExecuting: $isExecuting,
                            executeCommand: executeCommand,
                            handleBlockAction: handleBlockAction,
                            retryBlock: retryBlock,
                            askAI: askAI,
                            editFile: editFile,
                            gitSync: gitSync,
                            showBranchSwitcher: showBranchSwitcher,
                            showShortcuts: $showShortcuts,
                            sendAIMessage: sendAIMessage,
                            runCommand: runCommand,
                            explainError: explainError,
                            fixError: fixError,
                            runScript: runScript
                        )
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
            .onChange(of: tabManager.activeSessionId) { _, _ in
                syncWithActiveSession()
            }
            .onReceive(NotificationCenter.default.publisher(for: TerminalViewModel.fileFetchFinishedNotification)) { _ in
                if let content = tabManager.activeSession?.fetchedFileContent, !content.isEmpty {
                    editingFileContent = content
                    if isFetchingFile {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isFetchingFile = false
                            showEditor = true
                        }
                    }
                }
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
            
            // Integrated Editor Overlay
            if showEditor, let path = editingFile {
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showEditor = false 
                            }
                        }
                    
                    VStack(spacing: 0) {
                        RemoteFileEditorView(
                            filename: (path as NSString).lastPathComponent,
                            remotePath: path,
                            sshConnectionString: currentSSHServerName ?? "local",
                            initialContent: editingFileContent,
                            onSave: { newContent in
                                saveFile(at: path, content: newContent)
                            },
                            onCancel: { 
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showEditor = false 
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(VeloDesign.Colors.glassBorder, lineWidth: 1)
                        )
                        .frame(maxWidth: 1000, maxHeight: 800)
                        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
                    }
                    .padding(40)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 1.05))
                ))
                .zIndex(200)
            }

            // Fetching Overlay
            if isFetchingFile {
                ZStack {
                    // Transparent backdrop - allow seeing program elements
                    Color.black.opacity(0.08)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Prevent accidental dismissal
                        }
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(VeloDesign.Colors.neonCyan)
                        
                        VStack(spacing: 8) {
                            Text("Fetching Remote File")
                                .font(VeloDesign.Typography.headline)
                                .foregroundColor(VeloDesign.Colors.textPrimary)
                            
                            Text(editingFile ?? "")
                                .font(VeloDesign.Typography.monoSmall)
                                .foregroundColor(VeloDesign.Colors.textMuted)
                                .lineLimit(1)
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isFetchingFile = false
                                tabManager.activeSession?.cancelFileFetch()
                            }
                        }) {
                            Text("Cancel")
                                .font(VeloDesign.Typography.subheadline.weight(.medium))
                                .foregroundColor(VeloDesign.Colors.textMuted)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(VeloDesign.Colors.glassWhite.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(32)
                    .frame(width: 320)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(VeloDesign.Colors.cardBackground.opacity(0.7))
                            .background(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(VeloDesign.Colors.glassBorder, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                }
                .transition(.opacity.combined(with: .scale(scale: 1.1)))
                .zIndex(300)
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
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
        .sheet(isPresented: $showPasswordPrompt) {
            SSHPasswordSheet(
                serverName: pendingSSHConnection?.name ?? "SSH Server",
                password: $passwordInput,
                onSubmit: submitSSHPassword,
                onCancel: {
                    passwordInput = ""
                    showPasswordPrompt = false
                    pendingSSHConnection = nil
                }
            )
        }
        .sheet(isPresented: $showSSHConnectionSheet) {
            SSHConnectionSheet(
                serverName: pendingSSHConnection?.name ?? "SSH Server",
                host: "\(pendingSSHConnection?.username ?? "user")@\(pendingSSHConnection?.host ?? "host")",
                onCancel: cancelSSHConnection
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .sshPasswordRequired)) { _ in
            // Dismiss connection sheet if password is needed
            showSSHConnectionSheet = false
            handleSSHPasswordPrompt()
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentDirectory: String {
        if let session = tabManager.activeSession, session.isSSHActive, let remoteDir = session.remoteWorkingDirectory {
            return remoteDir
        }
        return tabManager.activeSession?.currentDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
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
        guard !inputText.isEmpty else { return }
        
        // Allow execution if not already executing, OR if we are in an SSH session
        // (SSH sessions keep isExecuting=true, but we still want to send input)
        let isSSH = isCurrentSessionSSH
        if isExecuting && !isSSH { return }
        
        var command = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for shortcut expansion
        if let expanded = shortcutsManager.expandShortcut(command) {
            command = expanded
        }
        
        inputText = ""
        
        // Get active session and append block to it
        guard let session = activeSession else { return }
        
        // Create a new block for this session
        let block = CommandBlock(
            command: command,
            status: .running,
            workingDirectory: currentDirectory
        )
        session.blocks.append(block)
        
        // Execute via terminal VM
        isExecuting = true
        
        Task {
            // Set the command on the active session
            session.inputText = command
            
            // If it's an interactive session, we send input to the existing process
            // If it's a new command, it will start a new process
            session.executeCommand()
            
            // For SSH sessions, we don't want to wait for the process to exit
            // because the process IS the SSH session itself.
            // Instead, we wait just a moment for the output to start streaming,
            // then we release the UI lock so the user can type the next command.
            if isSSH {
                // Short wait to capture immediate output
                try? await Task.sleep(for: .milliseconds(500))
                
                // Final sync for this block's initial burst
                let syncOutput = session.outputLines.suffix(max(0, session.outputLines.count - block.output.count))
                for line in syncOutput {
                    block.appendOutput(text: line.text, isError: line.isError)
                }
                
                block.status = .success // Mark as "sent" or "done" for this block
                isExecuting = false // Release lock
                return
            }
            
            // For standard local commands, wait for completion as usual
            while session.isExecuting {
                try? await Task.sleep(for: .milliseconds(100))
                
                // Stream output to block as it arrives
                let newOutput = session.outputLines.suffix(max(0, session.outputLines.count - block.output.count))
                for line in newOutput {
                    block.appendOutput(text: line.text, isError: line.isError)
                    
                    // Detect SSH password prompt
                    if line.text.lowercased().contains("password:") && pendingSSHConnection != nil {
                        await MainActor.run {
                            NotificationCenter.default.post(name: .sshPasswordRequired, object: nil)
                        }
                    }
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
            activeSession?.blocks.removeAll { $0.id == block.id }
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
        // Handle special internal commands
        if command.hasPrefix("__edit__:") {
            let path = String(command.dropFirst(9))
            editFile(at: path)
            return
        }

        if command.hasPrefix("__download_scp__:") {
            let scpCmd = String(command.dropFirst(17))
            if let session = tabManager.activeSession {
                session.startBackgroundDownload(command: scpCmd)
            }
            return
        }

        // Handle SCP upload (drag-drop to SSH)
        if command.hasPrefix("__upload_scp__:") {
            let scpCmd = String(command.dropFirst(15))
            if let session = tabManager.activeSession {
                session.startBackgroundUpload(command: scpCmd)
            }
            return
        }

        if command.hasPrefix("__copy_path__:") {
            let path = String(command.dropFirst(14))
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path, forType: .string)
            return
        }

        // Copy filename to clipboard
        if command.hasPrefix("__copy_name__:") {
            let name = String(command.dropFirst(14))
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(name, forType: .string)
            return
        }

        // Open file with default application
        if command.hasPrefix("__open__:") {
            let path = String(command.dropFirst(9))
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.open(url)
            return
        }

        // Reveal file in Finder
        if command.hasPrefix("__show_in_finder__:") {
            let path = String(command.dropFirst(19))
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }

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
        // Prevent multiple simultaneous fetches for the same file
        if editingFile == path && (showEditor || isFetchingFile) { return }
        
        // Handle Remote SSH Editing
        if let session = tabManager.activeSession, session.isSSHActive {
            if let userHost = session.activeSSHConnectionString {
                // Start background fetch and show loading state
                editingFile = path
                editingFileContent = ""
                isFetchingFile = true
                
                // Trigger the fetch - TerminalViewModel handles duplicate prevention
                session.startBackgroundFileFetch(path: path, userHost: userHost)
                return
            }
        }

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
        // Handle remote save
        if let session = tabManager.activeSession, session.isSSHActive {
            if let userHost = session.activeSSHConnectionString {
                session.startRemoteFileSave(path: path, content: content, userHost: userHost)
                return
            }
        }
        
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            editingFileContent = content
            session.showSuccessToast("Saved successfully")
        } catch {
            session.showErrorToast("Save failed: \(error.localizedDescription)")
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
            if let lastBlock = activeSession?.blocks.last {
                askAI("Explain what this command does: \(lastBlock.command)")
            }
        case .generate:
            askAI("Generate a script to")
        case .debug:
            askAI("Help me debug the last error")
        }
    }
    
    private func connectToSSH(_ connection: SSHConnection) {
        // Store connection and show progress sheet
        pendingSSHConnection = connection
        showSSHConnectionSheet = true
        
        // Mark as connected
        sshManager.markAsConnected(connection)
        
        // Try to get password from Keychain first
        let savedPassword = sshManager.getPassword(for: connection)
        
        tabManager.createSSHSession(
            host: connection.host,
            user: connection.username,
            port: connection.port,
            keyPath: connection.privateKeyPath,
            password: savedPassword
        )
        
        // Auto-dismiss sheet after connection completes (or timeout)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if showSSHConnectionSheet {
                showSSHConnectionSheet = false
            }
        }
    }
    
    private func cancelSSHConnection() {
        showSSHConnectionSheet = false
        pendingSSHConnection = nil
        // Could also terminate the session here if needed
    }
    
    /// Called when terminal detects password prompt
    private func handleSSHPasswordPrompt() {
        guard pendingSSHConnection != nil else { return }
        showPasswordPrompt = true
    }
    
    /// Submit password to SSH session
    private func submitSSHPassword() {
        guard let session = activeSession, !passwordInput.isEmpty else { return }
        
        // Send password to terminal
        session.terminalEngine.sendInput(passwordInput + "\n")
        
        // Optionally save to Keychain
        if let connection = pendingSSHConnection {
            sshManager.savePassword(passwordInput, for: connection)
        }
        
        passwordInput = ""
        showPasswordPrompt = false
        pendingSSHConnection = nil
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

// MARK: - Active Session Container

/// A container that observes the active session to ensure the UI re-renders on session property changes
private struct ActiveSessionContainer: View {
    @ObservedObject var session: TerminalViewModel
    var contextManager: ContextManager
    @ObservedObject var historyManager: CommandHistoryManager
    
    var aiMessages: [AIMessage]
    var recentErrors: [ErrorItem]
    var suggestions: [SuggestionItem]
    var scripts: [AutoScript]
    
    @Binding var showIntelligencePanel: Bool
    @Binding var selectedIntelligenceTab: IntelligenceTab
    @Binding var inputText: String
    @Binding var isExecuting: Bool
    
    var executeCommand: () -> Void
    var handleBlockAction: (CommandBlock, BlockAction) -> Void
    var retryBlock: (CommandBlock) -> Void
    var askAI: (String) -> Void
    var editFile: (String) -> Void
    var gitSync: () -> Void
    var showBranchSwitcher: () -> Void
    @Binding var showShortcuts: Bool
    
    var sendAIMessage: (String) -> Void
    var runCommand: (String) -> Void
    var explainError: (ErrorItem) -> Void
    var fixError: (ErrorItem) -> Void
    var runScript: (AutoScript) -> Void
    
    private var currentDirectory: String {
        if session.isSSHActive, let remoteDir = session.remoteWorkingDirectory {
            return remoteDir
        }
        return session.currentDirectory
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Workspace
                DashboardWorkspace(
                    contextManager: contextManager,
                    blocks: session.blocks,
                    inputText: $inputText,
                    isExecuting: $isExecuting,
                    currentDirectory: currentDirectory,
                    onExecute: executeCommand,
                    onBlockAction: handleBlockAction,
                    onRetryBlock: retryBlock,
                    onAskAI: askAI,
                    onOpenPath: { path in
                        editFile(path)
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
                        isSSH: session.isSSHActive,
                        sshConnectionString: session.activeSSHConnectionString,
                        parsedTerminalItems: session.parsedDirectoryItems,
                        isUploading: session.isUploading,
                        uploadFileName: session.uploadFileName,
                        uploadStartTime: session.uploadStartTime,
                        uploadProgress: session.uploadProgress,
                        onSendMessage: sendAIMessage,
                        onRunCommand: runCommand,
                        onExplainError: explainError,
                        onFixError: fixError,
                        onRunScript: runScript,
                        onEditFile: { path in
                            editFile(path)
                        },
                        onChangeDirectory: { path in
                            session.currentDirectory = path
                            Task { await contextManager.updateContext(for: path) }
                        }
                    )
                    .frame(width: 340)
                    .transition(.move(edge: .trailing))
                }
            }
            
            // Integrated Command Bar spanning both columns
            TerminalInputBar(
                inputText: $inputText,
                isExecuting: $isExecuting,
                currentDirectory: currentDirectory,
                isGitRepository: contextManager.isGitRepository,
                hasDocker: contextManager.isDockerProject,
                onExecute: executeCommand,
                onShowFiles: {
                    selectedIntelligenceTab = .files
                    withAnimation { showIntelligencePanel = true }
                },
                onShowHistory: {
                    selectedIntelligenceTab = .history
                    withAnimation { showIntelligencePanel = true }
                },
                onShowShortcuts: { showShortcuts = true },
                onAskAI: askAI
            )
        }
        .transition(.opacity)
        // Toast overlay for upload/download notifications
        .overlay(alignment: .bottom) {
            if session.showToast {
                HStack(spacing: 8) {
                    Image(systemName: session.toastIsSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(session.toastIsSuccess ? ColorTokens.success : ColorTokens.error)
                    
                    Text(session.toastMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.85))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                .padding(.bottom, 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: session.showToast)
            }
        }
    }
}
