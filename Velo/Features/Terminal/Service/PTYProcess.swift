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

    // For proper cleanup when suspended
    private var isSourceSuspended: Bool = false
    private let suspendLock = NSLock()

    // PERFORMANCE: Batch output to reduce main thread dispatch overhead
    private var pendingOutput: String = ""
    private var outputScheduled: Bool = false
    private let outputLock = NSLock()
    
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
        suspendLock.lock()
        // If suspended, resume before cancelling (required by GCD)
        if isSourceSuspended {
            readSource?.resume()
            isSourceSuspended = false
        }
        suspendLock.unlock()

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
        let source = DispatchSource.makeReadSource(fileDescriptor: masterFD, queue: .global(qos: .utility))

        source.setEventHandler { [weak self] in
            self?.readAvailable()
        }

        source.setCancelHandler { [weak self] in
            // Note: FD is closed in cleanupOnEOF() or terminate()
            // This handler is just for cleanup notification
            self?.isRunning = false
        }

        readSource = source
        source.resume()
    }
    
    private func readAvailable() {
        guard masterFD >= 0, isRunning else { return }

        // Read ALL available data to drain the buffer (prevents source from re-firing)
        var allData = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        // Read in a loop until we get EAGAIN or error
        while true {
            let bytesRead = read(masterFD, &buffer, buffer.count)

            if bytesRead > 0 {
                allData.append(contentsOf: buffer[0..<bytesRead])
                // Continue reading if there might be more data
                if bytesRead == buffer.count {
                    continue
                } else {
                    break
                }
            } else if bytesRead == 0 {
                // EOF - clean up
                cleanupOnEOF()
                return
            } else {
                // bytesRead < 0
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    // No more data available right now - this is normal
                    break
                } else {
                    // Real error - clean up
                    cleanupOnEOF()
                    return
                }
            }
        }

        // If we read any data, batch it and schedule delivery
        if !allData.isEmpty {
            if let text = String(data: allData, encoding: .utf8) {
                deliverOutput(text)
            }
        }
    }

    /// Batch output delivery to reduce main thread dispatch overhead
    private func deliverOutput(_ text: String) {
        outputLock.lock()
        pendingOutput += text

        // Cap pending output to prevent memory explosion (100KB max)
        if pendingOutput.count > 100_000 {
            pendingOutput = String(pendingOutput.suffix(50_000))
        }

        // If delivery is already scheduled, just accumulate
        if outputScheduled {
            outputLock.unlock()
            return
        }

        outputScheduled = true
        let output = pendingOutput
        pendingOutput = ""
        outputLock.unlock()

        // Deliver on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.outputHandler(output)

            // Check if more output accumulated while we were delivering
            self.outputLock.lock()
            if !self.pendingOutput.isEmpty {
                let moreOutput = self.pendingOutput
                self.pendingOutput = ""
                self.outputLock.unlock()
                self.outputHandler(moreOutput)
            } else {
                self.outputScheduled = false
                self.outputLock.unlock()
            }
        }
    }

    /// Clean up resources when EOF or error is encountered
    /// This prevents the DispatchSourceRead from firing continuously
    private func cleanupOnEOF() {
        suspendLock.lock()
        // If suspended, resume before cancelling (required by GCD)
        if isSourceSuspended {
            readSource?.resume()
            isSourceSuspended = false
        }
        suspendLock.unlock()

        // Cancel the dispatch source FIRST to stop the read loop
        readSource?.cancel()
        readSource = nil

        // Close file descriptor to release system resources
        if masterFD >= 0 {
            close(masterFD)
            masterFD = -1
        }

        DispatchQueue.main.async { [weak self] in
            self?.isRunning = false
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
