//
//  PTYProcess.swift
//  Velo
//
//  Pseudo-Terminal Process for Interactive Commands (SSH, etc.)
//

import Foundation
import Darwin

// MARK: - PTY Process
/// A process wrapper that uses a real pseudo-terminal for interactive commands
final class PTYProcess {
    
    // MARK: - Properties
    private var masterFD: Int32 = -1
    private var childPID: pid_t = 0
    private var isRunning = false
    
    private var readSource: DispatchSourceRead?
    private let outputHandler: (String) -> Void
    
    // MARK: - Init
    init(outputHandler: @escaping (String) -> Void) {
        self.outputHandler = outputHandler
    }
    
    deinit {
        terminate()
    }
    
    // MARK: - Execute
    func execute(command: String, environment: [String: String], workingDirectory: String) throws {
        guard !isRunning else {
            throw PTYError.alreadyRunning
        }
        
        // Build environment array for posix_spawn
        var envArray = environment.map { "\($0.key)=\($0.value)" }
        envArray.append("TERM=xterm-256color")
        
        // Get shell
        let shell = environment["SHELL"] ?? "/bin/zsh"
        
        // Create terminal size
        var winSize = winsize(
            ws_row: 30,
            ws_col: 120,
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        
        // Use forkpty to create PTY and fork
        var masterFD: Int32 = 0
        let pid = forkpty(&masterFD, nil, nil, &winSize)
        
        if pid < 0 {
            throw PTYError.forkFailed
        } else if pid == 0 {
            // Child process
            
            // Change directory
            _ = chdir(workingDirectory)
            
            // Set environment
            for (key, value) in environment {
                setenv(key, value, 1)
            }
            setenv("TERM", "xterm-256color", 1)
            
            // Execute shell with command
            let args = [shell, "-c", command]
            
            // Convert to C strings and exec
            args.withCStrings { argv in
                execv(shell, argv)
            }
            
            // If exec fails
            _exit(127)
        } else {
            // Parent process
            self.masterFD = masterFD
            self.childPID = pid
            self.isRunning = true
            
            // Set non-blocking
            let flags = fcntl(masterFD, F_GETFL)
            _ = fcntl(masterFD, F_SETFL, flags | O_NONBLOCK)
            
            // Setup read dispatch source
            setupReadSource()
        }
    }
    
    // MARK: - Write Input
    func write(_ text: String) {
        guard isRunning, masterFD >= 0 else { return }
        
        if let data = text.data(using: .utf8) {
            data.withUnsafeBytes { buffer in
                if let ptr = buffer.baseAddress {
                    _ = Darwin.write(masterFD, ptr, buffer.count)
                }
            }
        }
    }
    
    // MARK: - Send Signal
    func sendSignal(_ signal: Int32) {
        guard childPID > 0 else { return }
        kill(childPID, signal)
    }
    
    func interrupt() {
        sendSignal(SIGINT)
    }
    
    func terminate() {
        readSource?.cancel()
        readSource = nil
        
        if childPID > 0 {
            kill(childPID, SIGTERM)
            var status: Int32 = 0
            _ = waitpid(childPID, &status, WNOHANG)
            childPID = 0
        }
        
        if masterFD >= 0 {
            close(masterFD)
            masterFD = -1
        }
        
        isRunning = false
    }
    
    // MARK: - Wait for Exit
    func waitForExit() -> Int32 {
        guard childPID > 0 else { return -1 }
        
        var status: Int32 = 0
        _ = waitpid(childPID, &status, 0)
        
        let exitCode: Int32
        if (status & 0x7f) == 0 {  // WIFEXITED
            exitCode = (status >> 8) & 0xff  // WEXITSTATUS
        } else {
            exitCode = -1
        }
        
        isRunning = false
        return exitCode
    }
    
    // MARK: - Resize
    func resize(rows: UInt16, cols: UInt16) {
        guard masterFD >= 0 else { return }
        
        var winSize = winsize(
            ws_row: rows,
            ws_col: cols,
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        _ = ioctl(masterFD, TIOCSWINSZ, &winSize)
    }
    
    // MARK: - Private
    private func setupReadSource() {
        let source = DispatchSource.makeReadSource(fileDescriptor: masterFD, queue: .global(qos: .userInteractive))
        
        source.setEventHandler { [weak self] in
            self?.readAvailable()
        }
        
        source.setCancelHandler { [weak self] in
            if let fd = self?.masterFD, fd >= 0 {
                close(fd)
                self?.masterFD = -1
            }
        }
        
        readSource = source
        source.resume()
    }
    
    private func readAvailable() {
        guard masterFD >= 0 else { return }
        
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(masterFD, &buffer, buffer.count)
        
        if bytesRead > 0 {
            if let text = String(bytes: buffer[0..<bytesRead], encoding: .utf8) {
                DispatchQueue.main.async { [weak self] in
                    self?.outputHandler(text)
                }
            }
        } else if bytesRead == 0 || (bytesRead < 0 && errno != EAGAIN) {
            // EOF or error
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
            }
        }
    }
}

// MARK: - String Array Extension for C Strings
extension Array where Element == String {
    func withCStrings<R>(_ body: ([UnsafeMutablePointer<CChar>?]) -> R) -> R {
        var cStrings = self.map { strdup($0) }
        cStrings.append(nil)
        defer { cStrings.forEach { free($0) } }
        return body(cStrings)
    }
}

// MARK: - Errors
enum PTYError: Error, LocalizedError {
    case alreadyRunning
    case openPTYFailed
    case forkFailed
    
    var errorDescription: String? {
        switch self {
        case .alreadyRunning: return "Process is already running"
        case .openPTYFailed: return "Failed to open pseudo-terminal"
        case .forkFailed: return "Failed to fork process"
        }
    }
}
