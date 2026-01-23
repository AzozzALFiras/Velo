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
        
        // Setup sane terminal settings (termios)
        // This is CRITICAL for SSH to recognize input correctly (especially ENTER key)
        var term = termios()
        
        // Input flags - Turn on ICRNL (Map CR to NL on input) so \r works as Enter
        term.c_iflag = tcflag_t(ICRNL | IXON | IXOFF | IUTF8)
        
        // Output flags - Turn on OPOST and ONLCR (Map NL to CR-NL on output)
        term.c_oflag = tcflag_t(OPOST | ONLCR)
        
        // Control flags - CS8 (8-bit chars), CREAD (enable receiver), CLOCAL (ignore modem lines)
        term.c_cflag = tcflag_t(CS8 | CREAD | CLOCAL)
        
        // Local flags - ISIG (signals), ICANON (canonical mode), IEXTEN (extended processing), ECHO (echo input), ECHOE (echo erase)
        term.c_lflag = tcflag_t(ISIG | ICANON | IEXTEN | ECHO | ECHOE | ECHOCTL | ECHOKE)
        
        // Set standard control characters
        term.c_cc.0 = 4   // VEOF (Ctrl+D)
        term.c_cc.1 = 255 // VEOL
        term.c_cc.2 = 255 // VEOL2
        term.c_cc.3 = 127 // VERASE (Delete)
        term.c_cc.4 = 23  // VWERASE (Ctrl+W)
        term.c_cc.5 = 21  // VKILL (Ctrl+U)
        term.c_cc.6 = 18  // VREPRINT (Ctrl+R)
        term.c_cc.7 = 8   // VINTR (Ctrl+?) - usually delete in shell, but 8 is Backspace
        term.c_cc.8 = 3   // VQUIT (Ctrl+\)
        term.c_cc.9 = 28  // VSUSP (Ctrl+Z)
        term.c_cc.10 = 26 // VDSUSP
        term.c_cc.11 = 17 // VSTART (Ctrl+Q)
        term.c_cc.12 = 19 // VSTOP (Ctrl+S)
        term.c_cc.13 = 22 // VLNEXT (Ctrl+V)
        term.c_cc.14 = 15 // VDISCARD
        term.c_cc.15 = 25 // VMIN
        term.c_cc.16 = 0  // VTIME
        term.c_cc.17 = 20 // VSTATUS (Ctrl+T)
        // Note: Array indexing might vary by swift strictness, assigning known indices
        
        // Use forkpty to create PTY and fork with explicit termios
        var masterFD: Int32 = 0
        let pid = forkpty(&masterFD, nil, &term, &winSize)
        
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
        print("⌨️ [PTYProcess] write() called. isRunning: \(isRunning), masterFD: \(masterFD), text: '\(text.prefix(20))...'")
        guard isRunning, masterFD >= 0 else { 
            print("⌨️ [PTYProcess] ⚠️ Cannot write - process not running or invalid FD!")
            return 
        }
        
        if let data = text.data(using: .utf8) {
            data.withUnsafeBytes { buffer in
                if let ptr = buffer.baseAddress {
                    let result = Darwin.write(masterFD, ptr, buffer.count)
                    print("⌨️ [PTYProcess] Wrote \(result) bytes to masterFD \(masterFD)")
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

    /// Deliver output to the main thread
    /// CRITICAL: Small outputs (< 512 bytes) are delivered immediately without batching.
    /// This ensures interactive prompts (password:, yes/no, sudo) are processed instantly.
    /// Large outputs are batched to reduce main thread dispatch overhead.
    private func deliverOutput(_ text: String) {
        // IMMEDIATE PATH: Small outputs are likely interactive prompts
        // Password prompts, yes/no questions, sudo prompts MUST be delivered immediately
        if text.count < 512 {
            DispatchQueue.main.async { [weak self] in
                self?.outputHandler(text)
            }
            return
        }

        // BATCHED PATH: Large outputs (logs, file contents, command output)
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

            // Drain ALL remaining accumulated output
            self.outputLock.lock()
            while !self.pendingOutput.isEmpty {
                let moreOutput = self.pendingOutput
                self.pendingOutput = ""
                self.outputLock.unlock()
                self.outputHandler(moreOutput)
                self.outputLock.lock()
            }
            self.outputScheduled = false
            self.outputLock.unlock()
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
