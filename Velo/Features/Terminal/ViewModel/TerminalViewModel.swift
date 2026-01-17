//
//  TerminalViewModel.swift
//  Velo
//
//  AI-Powered Terminal - Main Terminal ViewModel
//

import SwiftUI
import Combine


// MARK: - Terminal ViewModel

/// Main view model for terminal state management
@MainActor
final class TerminalViewModel: ObservableObject, Identifiable {
    
    // Notifications
    static let downloadFinishedNotification = Notification.Name("VeloBackgroundDownloadFinished")
    static let fileFetchFinishedNotification = Notification.Name("VeloFileFetchFinished")
    
    
    // MARK: - Published Properties
    @Published var currentDirectory: String
    @Published var outputLines: [OutputLine] = []
    @Published var inputText: String = ""
    @Published var isExecuting: Bool = false
    @Published var lastExitCode: Int32 = 0
    @Published var errorMessage: String?
    @Published var commandStartTime: Date?
    @Published var activeCommand: String = ""
    
    /// Command blocks for this session (per-session history)
    @Published var blocks: [CommandBlock] = []
    
    // Derived state
    var isSSHActive: Bool {
        // Simple check: if active command starts with ssh and is executing
        return isExecuting && activeCommand.trimmingCharacters(in: .whitespaces).hasPrefix("ssh ")
    }
    
    var activeSSHConnectionString: String? {
        guard isSSHActive else { return nil }
        let cmd = activeCommand.trimmingCharacters(in: .whitespaces)
        let parts = cmd.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Find the user@host part
        // We skip flags and their values
        var i = 1 // Start after 'ssh'
        while i < parts.count {
            let part = parts[i]
            if part.hasPrefix("-") {
                // Common flags that take an argument
                let flagsWithArgs = ["-p", "-i", "-l", "-F", "-E", "-c", "-m", "-O", "-S", "-W", "-L", "-R", "-D"]
                if flagsWithArgs.contains(part) {
                    i += 2 // Skip flag and its value
                } else {
                    i += 1 // Skip flag without value (like -v, -t)
                }
            } else {
                // First non-flag part is usually user@host
                return part
            }
        }
        return nil
    }
    
    // AI & Tabs
    @Published var id: UUID = UUID()
    @Published var title: String = "Terminal"
    @Published var activeInsightTab: InsightTab = .suggestions
    @Published var aiService = CloudAIService()
    
    // Parsed items from terminal output (folders/files from ls)
    @Published var parsedDirectoryItems: [String] = []
    @Published var remoteWorkingDirectory: String? = nil // Tracked from SSH prompt
    
    // MARK: - Download State
    @Published var isDownloading = false
    @Published var showDownloadLogs = false
    @Published var downloadLogs = ""
    @Published var downloadFileName = "" // Current file being downloaded
    @Published var downloadStartTime: Date? = nil // When download started
    @Published var fetchedFileContent: String? = nil
    @Published var fetchingFilePath: String? = nil  // Track which file is being fetched
    
    // MARK: - Toast Notifications
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var toastIsSuccess = true

    // MARK: - Server Management (SSH High-Level UI)
    @Published var showServerManagement = false
    @Published var activeServerManagementTab: ServerManagementTab = .home

    func toggleServerManagement() {
        showServerManagement.toggle()
    }
    
    func showSuccessToast(_ message: String) {
        toastMessage = message
        toastIsSuccess = true
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showToast = false
        }
    }
    
    func showErrorToast(_ message: String) {
        toastMessage = message
        toastIsSuccess = false
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.showToast = false
        }
    }
    
    @Published var isFetchingFile = false
    private var fileFetchBuffer = ""
    private var downloadProcess: PTYProcess?
    private var downloadPasswordInjected = false
    
    // Dependencies
    let terminalEngine: TerminalEngine
    let historyManager: CommandHistoryManager
    let predictionEngine: PredictionEngine
    
    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
    private var historyNavigationIndex = 0
    
    // MARK: - Init
    init(
        terminalEngine: TerminalEngine,
        historyManager: CommandHistoryManager
    ) {
        self.terminalEngine = terminalEngine
        self.historyManager = historyManager
        self.predictionEngine = PredictionEngine(historyManager: historyManager)
        self.currentDirectory = terminalEngine.currentDirectory
        
        setupBindings()
    }
    
    init() {
        let engine = TerminalEngine()
        let history = CommandHistoryManager()
        
        self.terminalEngine = engine
        self.historyManager = history
        self.predictionEngine = PredictionEngine(historyManager: history)
        self.currentDirectory = engine.currentDirectory
        
        setupBindings()
    }
    
    
    // MARK: - Execute Command
    func executeCommand() {
        let command = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        
        // Handle "clear" locally even during SSH (it clears Velo's output buffer)
        if command == "clear" {
            clearScreen()
            inputText = ""
            return
        }
        
        // Auto-LS logic: Append ' && ls' to cd commands if enabled
        var finalCommand = command
        if UserDefaults.standard.bool(forKey: "autoLSafterCD") && command.trimmingCharacters(in: .whitespaces).hasPrefix("cd ") {
            finalCommand += " && ls"
        }
        
        // If a process is already running (e.g., SSH session), send input to it
        if isExecuting {
            terminalEngine.sendInput(finalCommand + "\n")
            inputText = ""
            return
        }
        
        // Clear input immediately
        inputText = ""
        predictionEngine.clear()
        historyNavigationIndex = 0
        errorMessage = nil
        
        // Handle built-in commands (cd for local machine)
        // Note: We use original 'command' for local 'cd' because '&& ls' won't work with handleBuiltinCommand logic directly
        // UNLESS we modify handleBuiltinCommand. But for local 'cd', Velo handles navigation internally.
        // So Auto-LS logic here is mainly for SSH/Remote sessions.
        // For local 'cd', we might want to run 'ls' too?
        // Velo's local 'cd' updates currentDirectory and 'ls' is handled by 'ls' command separately.
        // Since Velo is a terminal emulator, running 'cd ... && ls' as a raw command via 'execute' works locally too (it runs in shell).
        // BUT 'handleBuiltinCommand' intercepts 'cd'.
        if handleBuiltinCommand(command) {
            // For local CD, if auto-LS is on, we can manually trigger 'ls'
            if UserDefaults.standard.bool(forKey: "autoLSafterCD") && command.hasPrefix("cd ") {
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await MainActor.run {
                        self.inputText = "ls"
                        self.executeCommand()
                    }
                }
            }
            return
        }
        
        // Detect if command needs PTY (interactive commands)
        let needsPTY = command.hasPrefix("ssh ") ||
        command.hasPrefix("sftp ") ||
        command.contains("sudo ") ||
        command.hasPrefix("top") ||
        command.hasPrefix("htop") ||
        command.hasPrefix("vim ") ||
        command.hasPrefix("nano ") ||
        command.hasPrefix("less ") ||
        command.hasPrefix("more ")
        
        // Execute via terminal engine
        Task {
            isExecuting = true
            
            do {
                let result: CommandModel
                if needsPTY {
                    result = try await terminalEngine.executePTY(command)
                } else {
                    result = try await terminalEngine.execute(command)
                }
                
                // Add to history
                historyManager.addCommand(result)
                
                lastExitCode = result.exitCode
                outputLines = terminalEngine.outputLines
                
            } catch {
                errorMessage = error.localizedDescription
                addOutputLine(error.localizedDescription, isError: true)
            }
            
            isExecuting = false
        }
    }
    
    // MARK: - Interrupt
    func interrupt() {
        terminalEngine.interrupt()
    }
    
    // MARK: - Send Tab (for SSH autocomplete)
    func sendTab() {
        // Send Tab character for shell autocomplete
        terminalEngine.sendInput("\t")
    }
    
    // MARK: - Clear Screen
    func clearScreen() {
        // Clear local output buffer only
        // We don't send commands to remote because Velo doesn't interpret ANSI codes
        outputLines.removeAll()
        terminalEngine.clearOutput()
        parsedDirectoryItems.removeAll()  // Also clear parsed items
    }
    
    // MARK: - Accept Inline Suggestion (Tab key)
    func acceptInlineSuggestion() -> Bool {
        if let suggestion = predictionEngine.inlinePrediction, !suggestion.isEmpty {
            inputText = suggestion
            predictionEngine.clear()
            return true
        }
        return false
    }
    
    // MARK: - AI Actions
    @MainActor
    func askAI(query: String) {
        activeInsightTab = .chat
        Task {
            await aiService.sendMessage(query)
        }
    }
    
    // MARK: - Terminal Engine Delegateion
    func navigateHistoryUp() {
        let commands = historyManager.recentCommands
        guard !commands.isEmpty else { return }
        
        if historyNavigationIndex < commands.count {
            inputText = commands[historyNavigationIndex].command
            historyNavigationIndex += 1
        }
    }
    
    func navigateHistoryDown() {
        if historyNavigationIndex > 1 {
            historyNavigationIndex -= 1
            let commands = historyManager.recentCommands
            inputText = commands[historyNavigationIndex - 1].command
        } else {
            historyNavigationIndex = 0
            inputText = ""
        }
    }
    
    // MARK: - Rerun Command
    func rerunCommand(_ command: CommandModel) {
        inputText = command.command
        executeCommand()
    }
    
    // MARK: - Edit Command
    func editCommand(_ command: CommandModel) {
        inputText = command.command
    }
    
    // MARK: - Accept Prediction
    func acceptPrediction() {
        if let prediction = predictionEngine.acceptInlinePrediction() {
            inputText = prediction
        }
    }
    
    // MARK: - Accept Suggestion
    func acceptSuggestion(_ suggestion: CommandSuggestion) {
        inputText = suggestion.command
        predictionEngine.clear()
    }
    
    // MARK: - Navigate to Directory
    func navigateToDirectory(_ path: String) {
        do {
            try terminalEngine.changeDirectory(to: path)
            currentDirectory = terminalEngine.currentDirectory
            addOutputLine("📁 Navigated to: \(currentDirectory)", isError: false)
            
            // Add to history
            let result = CommandModel(
                command: "cd \(path)",
                output: "Navigated to: \(currentDirectory)",
                exitCode: 0,
                workingDirectory: currentDirectory,
                context: .filesystem
            )
            historyManager.addCommand(result)
        } catch {
            addOutputLine("❌ \(error.localizedDescription)", isError: true)
        }
    }
    
    // MARK: - Execute File Action
    /// Execute a command from the file action menu
    func executeFileAction(_ command: String) {
        // Handle cd commands specially
        if command.hasPrefix("cd ") {
            let path = String(command.dropFirst(3)).replacingOccurrences(of: "\"", with: "")
            navigateToDirectory(path)
            return
        }
        
        // Handle special display command
        if command.hasPrefix("__show_command__:") {
            let cmdToDisplay = String(command.dropFirst(17))
            inputText = cmdToDisplay
            addOutputLine("📋 Command ready (also copied to clipboard):", isError: false)
            return
        }
        
        // Handle file fetch for editing (background SSH)
        if command.hasPrefix("__fetch_file__:") {
            // Format: __fetch_file__:userHost:::path
            let payload = String(command.dropFirst(15))
            print("📄 [TerminalVM] Received file fetch command. Payload: '\(payload)'")
            let parts = payload.components(separatedBy: ":::")
            print("📄 [TerminalVM] Parsed parts: \(parts.count) - [\(parts.joined(separator: ", "))]")
            if parts.count == 2 {
                let userHost = parts[0]
                let path = parts[1]
                print("📄 [TerminalVM] Calling startBackgroundFileFetch(path: '\(path)', userHost: '\(userHost)')")
                startBackgroundFileFetch(path: path, userHost: userHost)
            } else {
                print("⚠️ [TerminalVM] Invalid __fetch_file__ format: \(payload)")
            }
            return
        }
        
        // Handle background download
        if command.hasPrefix("__download_scp__:") {
            let cmdToRun = String(command.dropFirst(17))
            startBackgroundDownload(command: cmdToRun)
            return
        }
        
        // Handle background upload (drag-drop to SSH)
        if command.hasPrefix("__upload_scp__:") {
            let cmdToRun = String(command.dropFirst(15))
            startBackgroundUpload(command: cmdToRun)
            return
        }
        
        // Handle background file save (SSH)
        if command.hasPrefix("__save_file_blob__:") {
            // Format: __save_file_blob__:userHost:::path:::base64Content
            let payload = String(command.dropFirst(19))
            let parts = payload.components(separatedBy: ":::")
            
            if parts.count == 3 {
                let userHost = parts[0]
                let path = parts[1]
                let base64Content = parts[2]
                
                if let data = Data(base64Encoded: base64Content),
                   let content = String(data: data, encoding: .utf8) {
                    startBackgroundFileSave(path: path, content: content, userHost: userHost)
                } else {
                    print("❌ [TerminalVM] Failed to decode base64 content for save")
                    addOutputLine("❌ Failed to save file: Content decoding error", isError: true)
                }
            } else {
                print("⚠️ [TerminalVM] Invalid __save_file_blob__ format. Parts count: \(parts.count)")
            }
            return
        }
        
        // For regular commands, execute them
        inputText = command
        executeCommand()
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Sync current directory
        terminalEngine.$currentDirectory
            .assign(to: &$currentDirectory)
        
        // Sync output lines and parse for directory items
        terminalEngine.$outputLines
            .sink { [weak self] lines in
                guard let self = self else { return }
                self.outputLines = lines
                self.parseDirectoryItemsFromOutput(lines)
            }
            .store(in: &cancellables)
        
        // Sync running state
        terminalEngine.$isRunning
            .assign(to: &$isExecuting)
        
        // Sync command state
        terminalEngine.$commandStartTime
            .assign(to: &$commandStartTime)
        
        terminalEngine.$currentCommand
            .assign(to: &$activeCommand)
        
        // Update predictions on input change (with parsed items from output)
        $inputText
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                // Pass parsed items to prediction engine
                // When isExecuting (SSH session), disable local suggestions
                self.predictionEngine.predict(
                    for: text,
                    workingDirectory: self.currentDirectory,
                    remoteItems: self.parsedDirectoryItems,
                    isSSH: self.isExecuting
                )
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Parse Directory Items from Output
    private func parseDirectoryItemsFromOutput(_ lines: [OutputLine]) {
        // Scan last 30 lines for directory listings and prompt-based CWD tracking
        let recentLines = lines.suffix(30)
        var items: Set<String> = []
        var detectedDirChange = false
        var detectedRemoteCWD: String? = nil
        
        // Typical SSH prompt patterns:
        // root@host:~#
        // user@host:/var/log$
        // [user@host ~]$
        // Regex to extract path between : and # or $ (or inside [])
        // Regex to extract path: looks for something starting with / or ~ after a colon or space,
        // and ending before a # or $ prompt.
        let pathRegex = try? NSRegularExpression(pattern: "(?::|\\s)([\\/~][^\\s#$]*)[#$]", options: [])
        
        for line in recentLines {
            var text = line.text
            
            // First, clean ANSI/OSC sequences from the line before regex matching
            let ansiPattern = "[\\u001B\\u009B][[\\]()#;?]*((?:[a-zA-Z\\d]*(?:;[-a-zA-Z\\d\\/#&.:=?%@~_]*)*)?\\u0007|(?:(?:\\d{1,4}(?:;\\d{0,4})*)?[\\dA-PR-TZcf-ntqry=><~]))"
            text = text.replacingOccurrences(of: ansiPattern, with: "", options: .regularExpression)
            text = text.replacingOccurrences(of: "\\r", with: "")
            text = text.replacingOccurrences(of: "\\u{07}", with: "")
            
            // Handle mid-string prompts (e.g. from multiple commands) by looking at the last part
            let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 1. Try to detect remote CWD from prompt
            if let match = pathRegex?.firstMatch(in: cleanedText, options: [], range: NSRange(cleanedText.startIndex..., in: cleanedText)) {
                if let range = Range(match.range(at: 1), in: cleanedText) {
                    var path = String(cleanedText[range]).trimmingCharacters(in: .whitespaces)
                    
                    // Additional cleanup - remove any embedded user@host: that might remain
                    path = path.replacingOccurrences(of: "^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+:", with: "", options: .regularExpression)
                    
                    if !path.isEmpty && (path.hasPrefix("/") || path.hasPrefix("~")) {
                        print("📍 [TerminalVM] Detected remote CWD: '\(path)' from cleaned line: '\(cleanedText)'")
                        detectedRemoteCWD = path
                    }
                }
            }
            
            // 2. Detect CD command execution to clear stale items
            if text.contains(" cd ") && (text.contains("#") || text.contains("$") || text.contains(">")) {
                items.removeAll()
                detectedDirChange = true
                continue
            }
            
            // Skip very short lines
            guard text.count >= 3 else { continue }
            
            // Skip ANSI escape codes and bracketed paste markers
            if text.contains("[?2004") { continue }
            if text.contains("root@") && (text.hasSuffix("#") || text.hasSuffix("$")) { continue }
            
            // Split into words by whitespace
            let words = text.components(separatedBy: CharacterSet.whitespaces)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count >= 2 && $0.count <= 60 }
            
            for word in words {
                // Remove ANSI codes fully
                let ansiPattern = "[\\u001B\\u009B][[\\]()#;?]*((?:[a-zA-Z\\d]*(?:;[-a-zA-Z\\d\\/#&.:=?%@~_]*)*)?\\u0007|(?:(?:\\d{1,4}(?:;\\d{0,4})*)?[\\dA-PR-TZcf-ntqry=><~]))"
                var cleaned = word.replacingOccurrences(of: ansiPattern, with: "", options: .regularExpression)
                
                // Preserve trailing / for directories!
                let hasTrailingSlash = cleaned.hasSuffix("/")
                cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "*/@ []\\r\\n"))
                if hasTrailingSlash && !cleaned.isEmpty {
                    cleaned += "/"
                }
                
                // Skip empty
                guard !cleaned.isEmpty else { continue }
                
                // Skip if still contains control sequence patterns
                if cleaned.contains("]0;") || cleaned.contains("]1;") || cleaned.contains("]2;") { continue }
                
                // If pure number, skip
                if Int(cleaned) != nil { continue }
                
                // Must contain at least one alpha char or common file char
                if cleaned.rangeOfCharacter(from: .letters) == nil && !cleaned.contains(".") && !cleaned.contains("_") {
                    continue
                }
                
                // Skip generic irrelevant strings
                if cleaned.contains("-generic") { continue }
                if cleaned.contains("@") { continue }
                if cleaned.contains(":") { continue }
                
                items.insert(cleaned)
            }
        }
        
        // Update state
        if let newRemoteCWD = detectedRemoteCWD, newRemoteCWD != remoteWorkingDirectory {
            remoteWorkingDirectory = newRemoteCWD
        }
        
        // Update parsed items
        if !items.isEmpty {
            parsedDirectoryItems = Array(items).sorted()
        } else if detectedDirChange {
            parsedDirectoryItems.removeAll()
        }
    }
    
    private func handleBuiltinCommand(_ command: String) -> Bool {
        let parts = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let cmd = parts.first else { return false }
        
        switch cmd {
        case "cd":
            let path = parts.dropFirst().joined(separator: " ")
            var targetPath: String
            
            if path.isEmpty {
                // cd with no args goes to home
                targetPath = NSHomeDirectory()
            } else if path.hasPrefix("/") {
                // Absolute path
                targetPath = path
            } else if path.hasPrefix("~") {
                // Home-relative path
                targetPath = (path as NSString).expandingTildeInPath
            } else {
                // Relative path (including .., ../, ../../, etc) - resolve against current directory
                targetPath = (currentDirectory as NSString).appendingPathComponent(path)
            }
            
            // Standardize path to resolve .. and . components
            targetPath = (targetPath as NSString).standardizingPath
            
            do {
                try terminalEngine.changeDirectory(to: targetPath)
                currentDirectory = terminalEngine.currentDirectory
                addOutputLine("Changed directory to: \(currentDirectory)", isError: false)
                
                // Add to history as successful command
                let result = CommandModel(
                    command: command,
                    output: "Changed directory to: \(currentDirectory)",
                    exitCode: 0,
                    workingDirectory: currentDirectory,
                    context: .filesystem
                )
                historyManager.addCommand(result)
            } catch {
                addOutputLine(error.localizedDescription, isError: true)
            }
            return true
            
        case "clear":
            clearScreen()
            return true
            
        case "exit":
            NSApplication.shared.terminate(nil)
            return true
            
        default:
            return false
        }
    }
    
    private func addOutputLine(_ text: String, isError: Bool) {
        let line = OutputLine(text: text, isError: isError)
        outputLines.append(line)
    }
    // MARK: - Background Download
    func startBackgroundDownload(command: String) {
        print("📡 [TerminalVM] Starting background SCP download: \(command)")
        
        isDownloading = true
        showDownloadLogs = true
        downloadStartTime = Date()
        
        // Extract filename from command
        if let firstQuote = command.firstIndex(of: "'"),
           let secondQuote = command[command.index(after: firstQuote)...].firstIndex(of: "'") {
            let pathRange = command.index(after: firstQuote)..<secondQuote
            let filePath = String(command[pathRange])
            downloadFileName = (filePath as NSString).lastPathComponent
        } else {
            downloadFileName = "file"
        }
        
        downloadLogs = "� Downloading: \(downloadFileName)...\n"
        downloadLogs += "Command: \(command)\n"
        downloadLogs += String(repeating: "-", count: 50) + "\n\n"
        downloadPasswordInjected = false
        
        // 1. Try to find password
        var passwordToInject: String?
        
        // Parse SCP command: scp [-r] user@host:path local
        downloadLogs += "📋 Parsing command...\n"
        let parts = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        downloadLogs += "  Command parts: \(parts.count) parts\n"
        downloadLogs += "  Parts: \(parts.joined(separator: " | "))\n\n"
        
        // Find the source part (contains @)
        if let sourcePart = parts.first(where: { $0.contains("@") && $0.contains(":") }) {
            downloadLogs += "✓ Found source part: \(sourcePart)\n"
            
            // Split by colon to separate user@host from path
            let components = sourcePart.components(separatedBy: ":")
            downloadLogs += "  Split by colon: \(components.count) components\n"
            
            if let userHost = components.first {
                downloadLogs += "  User@Host string: \(userHost)\n"
                
                // Split by @ to get username and host
                let userHostParts = userHost.components(separatedBy: "@")
                downloadLogs += "  Split by @: \(userHostParts.count) parts\n"
                
                if userHostParts.count == 2 {
                    let username = userHostParts[0]
                    let host = userHostParts[1]
                    downloadLogs += "  ✓ Username: \(username)\n"
                    downloadLogs += "  ✓ Host: \(host)\n\n"
                    
                    if !host.isEmpty && !username.isEmpty {
                        downloadLogs += "🔑 Looking for credentials for \(username)@\(host)...\n"
                        
                        // Access keychain via SSHManager
                        let manager = SSHManager()
                        downloadLogs += "  Checking \(manager.connections.count) saved connections\n"
                        
                        // Try to find matching connection
                        if let conn = manager.connections.first(where: { $0.host == host && $0.username == username }) {
                            downloadLogs += "  ✓ Found matching connection: \(conn.name ?? "Unnamed")\n"
                            if let pwd = manager.getPassword(for: conn) {
                                passwordToInject = pwd
                                downloadLogs += "✅ Password found in keychain (length: \(pwd.count))\n\n"
                            } else {
                                downloadLogs += "⚠️ Connection found but no password in keychain\n\n"
                            }
                        } else {
                            downloadLogs += "⚠️ No matching connection found\n"
                            downloadLogs += "  Available connections:\n"
                            for conn in manager.connections {
                                downloadLogs += "    - \(conn.username)@\(conn.host)\n"
                            }
                            downloadLogs += "\n"
                        }
                    } else {
                        downloadLogs += "❌ Username or host is empty\n\n"
                    }
                } else {
                    downloadLogs += "❌ Failed to parse user@host (wrong part count)\n\n"
                }
            } else {
                downloadLogs += "❌ No user@host component found\n\n"
            }
        } else {
            downloadLogs += "❌ Could not find source part with @ and :\n"
            downloadLogs += "  Looking for pattern: user@host:path\n\n"
        }
        
        // 2. Start Process
        downloadLogs += "📡 Setting up PTY process...\n"
        downloadLogs += "  Password auto-inject: \(passwordToInject != nil ? "Enabled" : "Disabled")\n\n"
        
        downloadProcess = PTYProcess { [weak self] text in
            guard let self = self else { return }
            
            // Log raw output with timestamp
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] PTY Output: \(text.replacingOccurrences(of: "\n", with: "\\n"))")
            
            self.downloadLogs += text
            
            // Auto-auth check - use instance flag to prevent multiple injections
            // Detect various password prompt formats
            let lowerText = text.lowercased()
            let isPasswordPrompt = lowerText.contains("password:") ||
            lowerText.contains("passphrase:") ||
            lowerText.contains("password for") ||
            lowerText.hasSuffix("password: ") ||
            lowerText.hasSuffix("password:")
            
            print("[\(timestamp)] Password check: prompt=\(isPasswordPrompt), hasPassword=\(passwordToInject != nil), injected=\(self.downloadPasswordInjected)")
            
            if let pwd = passwordToInject, !self.downloadPasswordInjected, isPasswordPrompt {
                print("[\(timestamp)] 🔐 Injecting password (length: \(pwd.count))")
                self.downloadLogs += "\n🔐 Auto-injecting password...\n"
                self.downloadProcess?.write(pwd + "\n")
                self.downloadPasswordInjected = true
                print("[\(timestamp)] ✓ Password injected successfully")
            } else if isPasswordPrompt && passwordToInject == nil {
                print("[\(timestamp)] ⚠️ Password prompt detected but no password available")
                self.downloadLogs += "\n⚠️ Password prompt detected - please enter manually:\n"
            } else if isPasswordPrompt && self.downloadPasswordInjected {
                print("[\(timestamp)] ℹ️ Password already injected, ignoring duplicate prompt")
            }
        }
        
        downloadLogs += "📡 Establishing connection...\n"
        print("[Download] Starting SCP command: \(command)")
        
        // Modify environment to add SSH options for non-interactive mode
        var scpEnvironment = ProcessInfo.processInfo.environment
        scpEnvironment["SSH_ASKPASS"] = "" // Prevent GUI password prompts
        
        downloadLogs += "  Working directory: \(FileManager.default.homeDirectoryForCurrentUser.path)\n"
        downloadLogs += "  Environment variables: \(scpEnvironment.count) set\n\n"
        
        do {
            print("[Download] Executing PTY process...")
            try downloadProcess?.execute(
                command: command,
                environment: scpEnvironment,
                workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path
            )
            
            downloadLogs += "✓ Process started successfully\n"
            print("[Download] ✓ PTY process started")
            
            // Monitor for exit
            downloadLogs += "⏳ Monitoring process for completion...\n\n"
            print("[Download] Waiting for process to complete...")
            
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                print("[Download] Starting waitForExit()...")
                let code = self.downloadProcess?.waitForExit() ?? -1
                print("[Download] Process exited with code: \(code)")
                
                DispatchQueue.main.async {
                    self.isDownloading = false
                    
                    // Calculate elapsed time
                    let elapsed = self.downloadStartTime.map { Date().timeIntervalSince($0) } ?? 0
                    let elapsedStr = String(format: "%.1f", elapsed)
                    
                    self.downloadLogs += "\n" + String(repeating: "=", count: 50) + "\n"
                    self.downloadLogs += "⏱ Duration: \(elapsedStr)s\n"
                    self.downloadProcess = nil
                    
                    if code == 0 {
                        self.downloadLogs += "✅ Download successful!\n"
                        self.downloadLogs += "💡 Check your Downloads folder (or destination) for the file.\n"
                        self.showSuccessToast("✅ \(self.downloadFileName) downloaded (\(elapsedStr)s)")
                        print("[Download] ✅ Download completed successfully")
                    } else {
                        self.downloadLogs += "❌ Download failed with exit code \(code).\n"
                        self.showErrorToast("❌ Download failed (code: \(code))")
                        print("[Download] ❌ Download failed with code: \(code)")
                        
                        if passwordToInject == nil {
                            self.downloadLogs += "💡 Tip: Make sure the SSH connection is saved in your connections list with credentials.\n"
                        }
                        
                        // Common error codes
                        switch code {
                        case 1:
                            self.downloadLogs += "  Possible cause: General error or permission denied\n"
                        case 255:
                            self.downloadLogs += "  Possible cause: SSH connection failed or authentication error\n"
                        case 127:
                            self.downloadLogs += "  Possible cause: Command not found (scp not installed?)\n"
                        default:
                            self.downloadLogs += "  Check the output above for error details\n"
                        }
                    }
                    
                    self.downloadStartTime = nil
                    self.downloadFileName = ""
                    
                    // Notify observers that download finished
                    print("🚀 [TerminalVM] Posting downloadFinishedNotification for: \(command) (code: \(code))")
                    NotificationCenter.default.post(
                        name: TerminalViewModel.downloadFinishedNotification,
                        object: nil,
                        userInfo: ["command": command, "code": code]
                    )
                }
            }
            
        } catch {
            isDownloading = false
            downloadLogs += "\n❌ Failed to start process\n"
            downloadLogs += "Error: \(error.localizedDescription)\n"
            downloadLogs += "💡 Tip: Make sure SCP is installed and the SSH server is accessible.\n"
            print("[Download] ❌ Failed to execute: \(error)")
        }
    }
    
    // MARK: - Background Upload (Drag-Drop to SSH)
    @Published var isUploading = false
    @Published var uploadLogs = ""
    @Published var uploadFileName = ""  // Current file being uploaded
    @Published var uploadStartTime: Date? = nil  // When upload started
    @Published var uploadProgress: Double = 0.0 // 0.0 to 1.0
    private var uploadProcess: PTYProcess?
    private var uploadPasswordInjected = false
    
    func startBackgroundUpload(command: String) {
        print("📤 [TerminalVM] Starting background SCP upload: \(command)")
        
        guard !isUploading else {
            print("⚠️ [TerminalVM] Upload already in progress, skipping.")
            return
        }
        
        isUploading = true
        showDownloadLogs = true
        uploadStartTime = Date()  // Track when upload started
        
        // Extract filename from command (e.g., scp '/path/to/file' ...)
        if let firstQuote = command.firstIndex(of: "'"),
           let secondQuote = command[command.index(after: firstQuote)...].firstIndex(of: "'") {
            let pathRange = command.index(after: firstQuote)..<secondQuote
            let filePath = String(command[pathRange])
            uploadFileName = (filePath as NSString).lastPathComponent
        } else {
            uploadFileName = "file"
        }
        
        downloadLogs = "📤 Uploading: \(uploadFileName)...\n"
        downloadLogs += "Command: \(command)\n"
        downloadLogs += String(repeating: "-", count: 50) + "\n\n"
        uploadPasswordInjected = false
        
        // Parse SCP upload command to find password
        var passwordToInject: String?
        let parts = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Find the destination part (contains @ and :) - e.g. user@host:'/path'
        if let destPart = parts.first(where: { $0.contains("@") && $0.contains(":") }) {
            let colonIndex = destPart.firstIndex(of: ":")!
            let userHost = String(destPart[..<colonIndex])
            let userHostParts = userHost.components(separatedBy: "@")
            
            if userHostParts.count == 2 {
                let username = userHostParts[0]
                let host = userHostParts[1]
                
                // Get password from keychain
                let manager = SSHManager()
                if let conn = manager.connections.first(where: { $0.host == host && $0.username == username }),
                   let pwd = manager.getPassword(for: conn) {
                    passwordToInject = pwd
                    downloadLogs += "✅ Password found for \(username)@\(host)\n\n"
                }
            }
        }
        
        // Start upload process
        uploadProcess = PTYProcess { [weak self] text in
            guard let self = self else { return }
            self.downloadLogs += text
            
            // Try to parse percentage (e.g., " 45% ")
            if let range = text.range(of: #"\d+%"#, options: .regularExpression) {
                let percentStr = String(text[range]).dropLast()
                if let percentValue = Double(percentStr) {
                    DispatchQueue.main.async {
                        self.uploadProgress = percentValue / 100.0
                    }
                }
            }
            
            // Password injection
            let lowerText = text.lowercased()
            let isPasswordPrompt = lowerText.contains("password:") || lowerText.hasSuffix("password: ")
            
            if let pwd = passwordToInject, !self.uploadPasswordInjected, isPasswordPrompt {
                self.downloadLogs += "\n🔐 Auto-injecting password...\n"
                self.uploadProcess?.write(pwd + "\n")
                self.uploadPasswordInjected = true
            }
        }
        
        do {
            try uploadProcess?.execute(
                command: command,
                environment: ProcessInfo.processInfo.environment,
                workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path
            )
            
            downloadLogs += "✓ Upload process started\n"
            
            // Monitor for completion
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                let code = self.uploadProcess?.waitForExit() ?? -1
                
                DispatchQueue.main.async {
                    self.isUploading = false
                    
                    // Calculate elapsed time
                    let elapsed = self.uploadStartTime.map { Date().timeIntervalSince($0) } ?? 0
                    let elapsedStr = String(format: "%.1f", elapsed)
                    
                    self.downloadLogs += "\n" + String(repeating: "=", count: 50) + "\n"
                    self.downloadLogs += "⏱ Duration: \(elapsedStr)s\n"
                    
                    if code == 0 {
                        self.downloadLogs += "✅ Upload successful!\n"
                        self.showSuccessToast("✅ \(self.uploadFileName) uploaded (\(elapsedStr)s)")
                    } else {
                        self.downloadLogs += "❌ Upload failed with exit code \(code)\n"
                        self.showErrorToast("❌ Upload failed (code: \(code))")
                    }
                    
                    self.uploadProcess = nil
                    self.uploadStartTime = nil
                    self.uploadFileName = ""
                    self.uploadProgress = 0.0
                }
            }
        } catch {
            isUploading = false
            downloadLogs += "\n❌ Failed to start upload: \(error.localizedDescription)\n"
            showErrorToast("❌ Upload failed to start")
        }
    }
    
    // MARK: - Background File Fetching (SSH)
    private var fileFetchProcess: PTYProcess?
    private var fileFetchPasswordInjected = false
    
    /// Fetch file content via background SSH connection (doesn't pollute main terminal)
    func startBackgroundFileFetch(path: String, userHost: String) {
        guard !isFetchingFile else {
            print("⚠️ [TerminalVM] File fetch already in progress")
            return
        }
        
        isFetchingFile = true
        fileFetchBuffer = ""
        fetchedFileContent = nil
        fetchingFilePath = path  // Track which file is being fetched
        fileFetchPasswordInjected = false
        
        print("🚀 [TerminalVM] Starting background file fetch for: \(path) via \(userHost)")
        

        // Parse user@host to find credentials for password injection
        var passwordToInject: String?
        let userHostParts = userHost.components(separatedBy: "@")
        let username = userHostParts.first ?? ""
        let host = userHostParts.last ?? ""
        
        let manager = SSHManager()
        if let conn = manager.connections.first(where: { $0.host == host && $0.username == username }) {
            if let pwd = manager.getPassword(for: conn) {
                print("🔑 [TerminalVM] Found password for \(userHost)")
                passwordToInject = pwd
            }
        }
        
        // SCP Approach:
        // 1. Create a local temp file path
        let tempFilename = UUID().uuidString
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(tempFilename)
        
        // 2. Build SCP command: scp -o StrictHostKeyChecking=no user@host:"/path" /local/temp
        // We use PTYProcess to handle password prompts if needed
        // Note: Quoting on remote path is crucial. standard double quotes work best.
        let scpCommand = "scp -o StrictHostKeyChecking=no \(userHost):\"\(path)\" \"\(tempFile.path)\""
        print("📡 [TerminalVM] Running: \(scpCommand)")
        
        self.fileFetchPasswordInjected = false
        
        // Initialize process with password handler
        fileFetchProcess = PTYProcess { [weak self] text in
            guard let self = self else { return }
            
            // Debug output to see what's happening (optional)
            // print("RAW PTY: \(text)")
            
            // Check for password prompt
            let lowerText = text.lowercased()
            let isPasswordPrompt = lowerText.contains("password:") || lowerText.contains("passphrase:")
            
            if let pwd = passwordToInject, !self.fileFetchPasswordInjected, isPasswordPrompt {
                print("🔐 [TerminalVM] Injecting password for file fetch")
                self.fileFetchProcess?.write(pwd + "\n")
                self.fileFetchPasswordInjected = true
            }
        }
        
        var env = ProcessInfo.processInfo.environment
        env["SSH_ASKPASS"] = ""
        
        do {
            try fileFetchProcess?.execute(
                command: scpCommand,
                environment: env,
                workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path
            )
            
            // Wait for completion in background
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                let exitCode = self.fileFetchProcess?.waitForExit() ?? -1
                print("📝 [TerminalVM] File fetch exited with code: \(exitCode)")
                
                DispatchQueue.main.async {
                    self.isFetchingFile = false
                    self.fileFetchProcess = nil
                    
                    if exitCode == 0 {
                        // Success! Read the temp file
                        do {
                            let content = try String(contentsOf: tempFile, encoding: .utf8)
                            print("✅ [TerminalVM] File content fetched successfully (\(content.count) chars)")
                            self.fetchedFileContent = content
                            
                            // Cleanup
                            try? FileManager.default.removeItem(at: tempFile)
                        } catch {
                            print("❌ [TerminalVM] Failed to read downloaded file: \(error)")
                            self.fetchedFileContent = "// Error: Downloaded file could not be read: \(error.localizedDescription)"
                        }
                    } else {
                        // Error - set a placeholder message
                        self.fetchedFileContent = "// Error: Could not fetch file content (exit code: \(exitCode))\n// Check SSH connection, file permissions, or disk space."
                        print("❌ [TerminalVM] File fetch failed with code: \(exitCode)")
                        try? FileManager.default.removeItem(at: tempFile)
                    }
                    
                    // Clear tracking AFTER setting content so views can validate the path
                    self.fetchingFilePath = nil 
                    
                    // Notify observers
                    NotificationCenter.default.post(name: TerminalViewModel.fileFetchFinishedNotification, object: nil)
                }
            }
        } catch {
            isFetchingFile = false
            fetchedFileContent = "// Error: \(error.localizedDescription)"
            print("❌ [TerminalVM] Failed to start file fetch: \(error)")
            NotificationCenter.default.post(name: TerminalViewModel.fileFetchFinishedNotification, object: nil)
        }
    }
    
    func cancelFileFetch() {
        print("🛑 [TerminalVM] Cancelling file fetch for: \(fetchingFilePath ?? "unknown")")
        fileFetchProcess?.terminate()
        fileFetchProcess = nil
        isFetchingFile = false
        fetchingFilePath = nil
    }
    
    // MARK: - Background File Saving (SSH)
    func startBackgroundFileSave(path: String, content: String, userHost: String) {
        startRemoteFileSave(path: path, content: content, userHost: userHost)
    }

    func startRemoteFileSave(path: String, content: String, userHost: String) {
        print("🚀 [TerminalVM] Starting background file save for: \(path)")
        
        // Parse user@host to find credentials
        var passwordToInject: String?
        let userHostParts = userHost.components(separatedBy: "@")
        let username = userHostParts.first ?? ""
        let host = userHostParts.last ?? ""
        
        let manager = SSHManager()
        if let conn = manager.connections.first(where: { $0.host == host && $0.username == username }) {
            if let pwd = manager.getPassword(for: conn) {
                passwordToInject = pwd
            }
        }
        
        // Write content to a local temp file
        let tempFilename = UUID().uuidString
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(tempFilename)
        
        do {
            try content.write(to: tempFile, atomically: true, encoding: .utf8)
            print("💾 [TerminalVM] Wrote content to temp file: \(tempFile.path) (\(content.count) chars)")
        } catch {
            print("❌ [TerminalVM] Failed to create temp file: \(error)")
            addOutputLine("❌ Save failed: Could not create temporary file", isError: true)
            return
        }
        
        let scpCommand = "scp -o StrictHostKeyChecking=no \"\(tempFile.path)\" \(userHost):\"\(path)\""
        print("📡 [TerminalVM] Running save command: \(scpCommand)")
        
        self.fileFetchPasswordInjected = false
        
        let saveProcess = PTYProcess { [weak self] text in
            guard let self = self else { return }
            let lowerText = text.lowercased()
            if !self.fileFetchPasswordInjected && (lowerText.contains("password:") || lowerText.contains("passphrase:")) {
                if let pwd = passwordToInject {
                    print("🔐 [TerminalVM] Injecting password for file save")
                    self.fileFetchProcess?.write(pwd + "\n")
                    self.fileFetchPasswordInjected = true
                }
            }
        }
        
        self.fileFetchProcess = saveProcess
        
        var env = ProcessInfo.processInfo.environment
        env["SSH_ASKPASS"] = ""
        
        do {
            try saveProcess.execute(
                command: scpCommand,
                environment: env,
                workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path
            )
            
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                let exitCode = saveProcess.waitForExit()
                print("📝 [TerminalVM] File save exited with code: \(exitCode)")
                
                try? FileManager.default.removeItem(at: tempFile)
                
                DispatchQueue.main.async {
                    self.fileFetchProcess = nil
                    
                    if exitCode == 0 {
                        print("✅ [TerminalVM] Save successful")
                        self.showSuccessToast("Saved successfully")
                    } else {
                        print("❌ [TerminalVM] Save failed with code: \(exitCode)")
                        self.showErrorToast("Save failed (exit code: \(exitCode))")
                        self.addOutputLine("❌ Save failed with exit code: \(exitCode). Check permissions or connection.", isError: true)
                    }
                }
            }
        } catch {
            print("❌ [TerminalVM] Failed to execute save: \(error)")
            self.addOutputLine("❌ Save failed to execute: \(error.localizedDescription)", isError: true)
            try? FileManager.default.removeItem(at: tempFile)
            fileFetchProcess = nil
        }
    }

    /// Wrapper for background scp download
    func startSCPDownload(command: String) {
        // Delegate to the robust background download implementation
        startBackgroundDownload(command: command)
    }
}
