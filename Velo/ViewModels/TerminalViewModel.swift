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
    
    // AI & Tabs
    @Published var id: UUID = UUID()
    @Published var title: String = "Terminal"
    @Published var activeInsightTab: InsightTab = .suggestions
    @Published var aiService = CloudAIService()
    
    // Parsed items from terminal output (folders/files from ls)
    @Published var parsedDirectoryItems: [String] = []
    
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
        // Handle cd commands specially (for folder navigation)
        if command.hasPrefix("cd ") {
            let path = String(command.dropFirst(3)).replacingOccurrences(of: "\"", with: "")
            navigateToDirectory(path)
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
        // Scan last 30 lines for directory listings
        let recentLines = lines.suffix(30)
        var items: Set<String> = []
        var detectedDirChange = false
        
        for line in recentLines {
            let text = line.text
            
            // 1. Detect CD command execution to clear stale items
            // "root@mail:~# cd ..." or similar patterns
            // If we see a CD, we discard all previously gathered items in this batch
            // because they belong to the old directory context.
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
                .filter { $0.count >= 2 && $0.count <= 50 }
            
            for word in words {
                // Remove ANSI codes fully (including ? for bracketed paste and simple Escapes)
                var cleaned = word
                    .replacingOccurrences(of: "\\x1B\\[[0-9;?]*[a-zA-Z]", with: "", options: .regularExpression)
                    // Also strip standalone ESC or control chars if any
                    .replacingOccurrences(of: "\\x1B", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "*/@ []\r\n"))
                
                // Skip empty
                guard !cleaned.isEmpty else { continue }
                
                // Skip if starts with special chars (except . or _ which are valid for files)
                // We allow .config or _private
                guard let first = cleaned.first else { continue }
                
                // If pure number, skip (likelihood of being size or pid)
                if Int(cleaned) != nil { continue }
                
                // Must contain at least one alpha char to be interesting
                if cleaned.rangeOfCharacter(from: .letters) == nil { continue }
                
                // Skip generic irrelevant strings
                if cleaned.contains("-generic") { continue }
                if cleaned.contains("@") { continue } // email or user@host
                if cleaned.contains(":") { continue } // times or host:path
                
                items.insert(cleaned)
            }
        }
        
        // Update parsed items
        if !items.isEmpty {
            parsedDirectoryItems = Array(items).sorted()
            print("📂 Found \(items.count) items: \(parsedDirectoryItems.prefix(20))")
        } else if detectedDirChange {
            // IF we successfully changed directory but found no items (yet),
            // we MUST clear the old items to prevent stale suggestions.
            parsedDirectoryItems.removeAll()
            print("🧹 Cleared items due to CD command")
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
}
