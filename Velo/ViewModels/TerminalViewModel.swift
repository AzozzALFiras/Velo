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
    
    // MARK: - Identity
    // MARK: - Published Properties
    @Published var currentDirectory: String
    @Published var outputLines: [OutputLine] = []
    @Published var inputText: String = ""
    @Published var isExecuting: Bool = false
    @Published var lastExitCode: Int32 = 0
    @Published var errorMessage: String?
    @Published var commandStartTime: Date?
    @Published var activeCommand: String = ""
    
    // Derived state
    var isSSHActive: Bool {
        // Simple check: if active command starts with ssh and is executing
        return isExecuting && activeCommand.trimmingCharacters(in: .whitespaces).hasPrefix("ssh ")
    }
    
    var activeSSHConnectionString: String? {
        guard isSSHActive else { return nil }
        let cmd = activeCommand.trimmingCharacters(in: .whitespaces)
        // Extract user@host from "ssh -tt user@host" or "ssh user@host"
        // Simply removing "ssh " and flags until we hit the user@host part
        // This is a naive implementation; a better one would tokenize, but for now:
        let parts = cmd.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        // Find the part that contains "@" or looks like a host
        // parts[0] is ssh
        for part in parts.dropFirst() {
            if !part.hasPrefix("-") { // Skip flags like -tt, -p
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
                     // Small delay to ensure cd completes
                     try? await Task.sleep(nanoseconds: 100_000_000)
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
        
        // Handle background download
        if command.hasPrefix("__download_scp__:") {
            let cmdToRun = String(command.dropFirst(17))
            startBackgroundDownload(command: cmdToRun)
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
                self?.outputLines = lines
                self?.parseDirectoryItemsFromOutput(lines)
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
        let pathRegex = try? NSRegularExpression(pattern: "(?::|\\s)([\\/~][^\\s#$]*)[#$]\\s?$", options: [])
        
        for line in recentLines {
            let text = line.text
            
            // 1. Try to detect remote CWD from prompt
            if let match = pathRegex?.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range(at: 1), in: text) {
                    let path = String(text[range]).trimmingCharacters(in: .whitespaces)
                    if !path.isEmpty {
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
                // Using \u{1B} for Escape character in regex replacement
                var cleaned = word
                    .replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[a-zA-Z]", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\u{1B}", with: "")

                // Preserve trailing / for directories!
                // Trim other characters but NOT the trailing slash
                let hasTrailingSlash = cleaned.hasSuffix("/")
                cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "*/@ []\r\n"))
                if hasTrailingSlash && !cleaned.isEmpty {
                    cleaned += "/"
                }

                // Skip empty
                guard !cleaned.isEmpty else { continue }
                
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
          //  print("📍 Detected remote CWD: \(newRemoteCWD)")
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
        guard !isDownloading else {
            downloadLogs += "⚠️ Download already in progress\n"
            return
        }

        isDownloading = true
        showDownloadLogs = true
        downloadLogs = "🚀 Starting download...\n"
        downloadLogs += "Command: \(command)\n"
        downloadLogs += "Timestamp: \(Date())\n"
        downloadLogs += String(repeating: "-", count: 50) + "\n\n"
        downloadPasswordInjected = false // Reset flag

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
                    self.downloadLogs += "\n" + String(repeating: "=", count: 50) + "\n"
                    self.downloadLogs += "🏁 Process completed\n"
                    self.downloadLogs += "Exit code: \(code)\n"
                    self.downloadLogs += "Timestamp: \(Date())\n"
                    self.downloadLogs += String(repeating: "=", count: 50) + "\n\n"
                    self.downloadProcess = nil

                    if code == 0 {
                        self.downloadLogs += "✅ Download successful!\n"
                        self.downloadLogs += "💡 Check your Downloads folder for the file.\n"
                        print("[Download] ✅ Download completed successfully")
                    } else {
                        self.downloadLogs += "❌ Download failed with exit code \(code).\n"
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
}
