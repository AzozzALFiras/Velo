//
//  TerminalEngine.swift
//  Velo
//
//  AI-Powered Terminal - Core Terminal Engine
//

import Foundation
import Combine

// MARK: - Terminal Engine
/// Core engine for managing shell processes and command execution
@MainActor
final class TerminalEngine: ObservableObject {
    
    // MARK: - Published State
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var currentDirectory: String = ""
    @Published private(set) var outputLines: [OutputLine] = []
    @Published private(set) var lastExitCode: Int32 = 0
    
    // MARK: - Publishers
    let outputPublisher = PassthroughSubject<OutputLine, Never>()
    let commandCompletedPublisher = PassthroughSubject<CommandModel, Never>()
    
    @Published private(set) var commandStartTime: Date?
    @Published private(set) var currentCommand: String = ""
    
    // MARK: - Private Properties
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var accumulatedOutput: String = ""
    
    // Output Buffer (Background Thread Processing)
    private let outputBuffer = OutputBuffer()
    private var flushTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let shell: String
    private let environment: [String: String]
    
    // MARK: - Init
    init() {
        // Detect default shell
        self.shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        
        // Copy environment and add custom vars
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["CLICOLOR"] = "1"
        env["CLICOLOR_FORCE"] = "1"
        env["HOME"] = NSHomeDirectory()
        
        // Ensure PATH includes common binary locations (Homebrew, etc.)
        let additionalPaths = [
            "/opt/homebrew/bin",           // Homebrew on Apple Silicon
            "/opt/homebrew/sbin",
            "/usr/local/bin",               // Homebrew on Intel Macs
            "/usr/local/sbin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            NSHomeDirectory() + "/.local/bin",  // User local binaries
            NSHomeDirectory() + "/bin"
        ]
        
        let existingPath = env["PATH"] ?? "/usr/bin:/bin"
        let newPath = (additionalPaths + [existingPath]).joined(separator: ":")
        env["PATH"] = newPath
        
        self.environment = env
        
        // Always start in user's home directory (avoids sandbox issues)
        self.currentDirectory = NSHomeDirectory()
    }
    
    // MARK: - Execute Command
    /// Execute a command and stream output
    func execute(_ command: String) async throws -> CommandModel {
        guard !isRunning else {
            throw TerminalError.alreadyRunning
        }
        
        isRunning = true
        commandStartTime = Date()
        currentCommand = command
        accumulatedOutput = ""
        outputBuffer.clear()
        
        defer {
            isRunning = false
            cleanup()
        }
        
        // Create pipes
        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        
        inputPipe = input
        outputPipe = output
        errorPipe = error
        
        // Create process
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: shell)
        proc.arguments = ["-c", command]
        proc.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        proc.environment = environment
        proc.standardInput = input
        proc.standardOutput = output
        proc.standardError = error
        
        process = proc
        
        // Setup output handling
        setupOutputHandling(output: output, error: error)
        
        // Start flush timer on main thread
        await MainActor.run {
            self.flushTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.flushBuffer()
            }
        }
        
        // Run process
        do {
            try proc.run()
        } catch {
            throw TerminalError.executionFailed(error.localizedDescription)
        }
        
        // Wait for completion
        proc.waitUntilExit()
        
        // Calculate duration
        let duration = commandStartTime.map { Date().timeIntervalSince($0) } ?? 0
        lastExitCode = proc.terminationStatus
        
        // Create command model
        let commandModel = CommandModel(
            command: command,
            output: accumulatedOutput,
            exitCode: proc.terminationStatus,
            timestamp: commandStartTime ?? Date(),
            duration: duration,
            workingDirectory: currentDirectory,
            context: CommandContext.detect(from: command)
        )
        
        commandCompletedPublisher.send(commandModel)
        
        return commandModel
    }
    
    // MARK: - Execute with Streaming
    /// Execute command and call handler for each output line
    func executeStreaming(_ command: String, outputHandler: @escaping (OutputLine) -> Void) async throws -> CommandModel {
        let subscription = outputPublisher.sink { line in
            outputHandler(line)
        }
        
        defer {
            subscription.cancel()
        }
        
        return try await execute(command)
    }
    
    // MARK: - Interrupt
    /// Send SIGINT to running process
    func interrupt() {
        process?.interrupt()
    }
    
    // MARK: - Terminate
    /// Force terminate running process
    func terminate() {
        process?.terminate()
    }
    
    // MARK: - Send Input
    /// Send input to running process
    func sendInput(_ text: String) {
        guard let pipe = inputPipe else { return }
        
        let data = (text + "\n").data(using: .utf8) ?? Data()
        pipe.fileHandleForWriting.write(data)
    }
    
    // MARK: - Change Directory
    /// Change current working directory
    func changeDirectory(to path: String) throws {
        let expandedPath = (path as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw TerminalError.invalidDirectory(path)
        }
        
        currentDirectory = expandedPath
    }
    
    // MARK: - Clear Output
    func clearOutput() {
        outputLines.removeAll()
    }
    
    // MARK: - Private Methods
    private func setupOutputHandling(output: Pipe, error: Pipe) {
        // Handle stdout - runs on background queue
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                self?.outputBuffer.append(text, isError: false)
            }
        }
        
        // Handle stderr - runs on background queue
        error.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                self?.outputBuffer.append(text, isError: true)
            }
        }
    }
    
    private func flushBuffer() {
        let update = outputBuffer.flush()
        guard !update.lines.isEmpty else { return }
        
        // Efficient Main Actor update
        if update.replaceLast, !outputLines.isEmpty {
            outputLines.removeLast()
        }
        
        outputLines.append(contentsOf: update.lines)
        
        // Optional: Notify publisher if needed
        for line in update.lines {
            outputPublisher.send(line)
        }
    }

    

    
    private func cleanup() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        
        try? inputPipe?.fileHandleForWriting.close()
        try? outputPipe?.fileHandleForReading.close()
        try? errorPipe?.fileHandleForReading.close()
        
        inputPipe = nil
        outputPipe = nil
        errorPipe = nil
        process = nil
    }
}

// MARK: - Terminal Errors
enum TerminalError: LocalizedError {
    case alreadyRunning
    case executionFailed(String)
    case invalidDirectory(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "A command is already running"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        case .invalidDirectory(let path):
            return "Invalid directory: \(path)"
        }
    }
}



