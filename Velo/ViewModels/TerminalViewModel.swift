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
        
        // If a process is already running, send input to it instead
        if isExecuting {
            terminalEngine.sendInput(command + "\n")
            inputText = ""
            return
        }
        
        // Clear input immediately
        inputText = ""
        predictionEngine.clear()
        historyNavigationIndex = 0
        errorMessage = nil
        
        // Handle built-in commands
        if handleBuiltinCommand(command) {
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
    
    // MARK: - Clear Screen
    func clearScreen() {
        outputLines.removeAll()
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
        
        // Sync output lines
        terminalEngine.$outputLines
            .assign(to: &$outputLines)
        
        // Sync running state
        terminalEngine.$isRunning
            .assign(to: &$isExecuting)
        
        // Sync command state
        terminalEngine.$commandStartTime
            .assign(to: &$commandStartTime)
        
        terminalEngine.$currentCommand
            .assign(to: &$activeCommand)
        
        // Update predictions on input change
        $inputText
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                self.predictionEngine.predict(for: text, workingDirectory: self.currentDirectory)
            }
            .store(in: &cancellables)
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
