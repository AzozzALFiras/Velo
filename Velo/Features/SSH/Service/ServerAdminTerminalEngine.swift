//
//  ServerAdminTerminalEngine.swift
//  Velo
//
//  Dedicated hidden SSH execution engine for Server Admin operations.
//  Creates its own PTYProcess and SSH session, completely separate from
//  the user-visible terminal. Used for package installation, version
//  switching, service control, and other admin-level operations.
//

import Foundation

// MARK: - Errors

enum ServerAdminError: Error, LocalizedError {
    case alreadyConnected
    case connectionFailed(String)
    case authenticationFailed
    case notConnected
    case timeout(String)

    var errorDescription: String? {
        switch self {
        case .alreadyConnected:       return "Already connected"
        case .connectionFailed(let m): return "Connection failed: \(m)"
        case .authenticationFailed:   return "Authentication failed"
        case .notConnected:           return "Not connected"
        case .timeout(let cmd):       return "Command timed out: \(cmd)"
        }
    }
}

// MARK: - ServerAdminTerminalEngine

/// An actor that provides a hidden, dedicated SSH channel for server admin operations.
/// It creates its own PTYProcess, establishes an independent SSH connection, and
/// executes commands with surgical precision using VADM markers.
actor ServerAdminTerminalEngine {

    // MARK: - Connection State

    enum ConnectionState: Sendable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    private(set) var state: ConnectionState = .disconnected

    // MARK: - Internal State

    private var ptyProcess: PTYProcess?
    private var connection: SSHConnection?
    private var password: String?
    private var outputBuffer: String = ""
    private var silenced: Bool = false

    /// Active command being executed (nil when idle)
    private var activeCommand: ActiveAdminCommand?

    /// Serial execution queue to prevent command interleaving
    private var executionQueue: Task<Void, Never>?

    /// Maximum output buffer size (10 MB)
    private static let maxOutputBufferSize = 10_000_000

    // MARK: - Active Command Context

    private struct ActiveAdminCommand {
        let startMarker: String
        let endMarker: String
        let command: String
        let startTime: Date
        var capturedOutput: String = ""
        var hasEndMarker: Bool = false
        var continuation: CheckedContinuation<SSHCommandResult, Never>?
        var passwordInjected: Bool = false
    }

    // MARK: - Connect

    /// Establish a hidden SSH connection.
    func connect(using connection: SSHConnection, password: String?) async throws {
        guard case .disconnected = state else {
            throw ServerAdminError.alreadyConnected
        }

        self.connection = connection
        self.password = password
        state = .connecting

        // Build a robust SSH command with additional flags for non-interactive use
        var sshCmd = "ssh -tt"
        sshCmd += " -o StrictHostKeyChecking=accept-new"
        sshCmd += " -o ServerAliveInterval=60"
        sshCmd += " -o ServerAliveCountMax=5"
        sshCmd += " -o BatchMode=no" // We want to be able to inject password
        
        if connection.port != 22 {
            sshCmd += " -p \(connection.port)"
        }
        if connection.authMethod == .privateKey, let keyPath = connection.privateKeyPath {
            sshCmd += " -i \(keyPath)"
        }
        sshCmd += " \(connection.username)@\(connection.host)"

        print("🚀 [ServerAdminEngine] Connecting to \(connection.host)...")

        // Create a PTYProcess
        let pty = PTYProcess { [weak self] text in
            guard let self = self else { return }
            Task { await self.handleOutput(text) }
        }
        self.ptyProcess = pty

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["DEBIAN_FRONTEND"] = "noninteractive"
        env["LC_ALL"] = "C" // Standardize output language

        do {
            try pty.execute(
                command: sshCmd,
                environment: env,
                workingDirectory: NSHomeDirectory()
            )
        } catch {
            state = .error(error.localizedDescription)
            throw ServerAdminError.connectionFailed(error.localizedDescription)
        }

        // Wait for prompt
        do {
            try await waitForShellReady(timeout: 45)
        } catch {
            disconnect()
            throw error
        }

        // Setup environment
        await setupEnvironment()

        state = .connected
        print("✅ [ServerAdminEngine] Session established and silenced.")
    }

    // MARK: - Execute

    /// Execute a command and return results.
    func execute(_ command: String, timeout: Int = 300) async -> SSHCommandResult {
        guard case .connected = state, ptyProcess != nil else {
            return SSHCommandResult(command: command, output: "Engine not connected", exitCode: -1, executionTime: 0)
        }

        // Serial queue
        let prev = executionQueue
        let task = Task { [prev] in
            _ = await prev?.value
            return await self.performExecute(command, timeout: timeout)
        }
        executionQueue = Task { _ = await task.value }

        return await task.value
    }

    // MARK: - Disconnect

    func disconnect() {
        ptyProcess?.terminate()
        ptyProcess = nil
        state = .disconnected
        outputBuffer = ""
        silenced = false
        activeCommand = nil
        executionQueue = nil
        connection = nil
        password = nil
    }

    // MARK: - Private Implementation

    private func performExecute(_ command: String, timeout: Int) async -> SSHCommandResult {
        guard let pty = ptyProcess else {
            return SSHCommandResult(command: command, output: "Engine disconnected", exitCode: -1, executionTime: 0)
        }

        let startTime = Date()
        let markerId = UUID().uuidString.prefix(6).lowercased()
        let sm = "VADM_S_\(markerId)"
        let em = "VADM_E_\(markerId)"

        let cleanCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        activeCommand = ActiveAdminCommand(
            startMarker: sm,
            endMarker: em,
            command: cleanCommand,
            startTime: startTime
        )

        // Inject Golden Command Pattern flags for package managers
        var finalCommand = cleanCommand
        let lowerCmd = finalCommand.lowercased()
        
        let isApt = lowerCmd.contains("apt-get") || lowerCmd.contains("apt ")
        let isYum = lowerCmd.contains("yum ") || lowerCmd.contains("dnf ")
        
        if isApt && !finalCommand.contains("DEBIAN_FRONTEND") {
             // Robust flags for apt-get/apt
             var fortified = "export DEBIAN_FRONTEND=noninteractive; \(finalCommand)"
             
             // Add -y and -q if not present
             if !fortified.contains(" -y") { fortified += " -y" }
             if !fortified.contains(" -q") { fortified += " -q" }
             
             // Conflict resolution: keep existing configs
             fortified += " -o Dpkg::Options::=\"--force-confdef\""
             fortified += " -o Dpkg::Options::=\"--force-confold\""
             
             // Disable problematic hooks that can cause failures (e.g., cnf-update-db)
             fortified += " -o APT::Update::Post-Invoke-Success::=''"
             fortified += " -o APT::Update::Post-Invoke::=''"
             
             // Ensure no prompts even for unauthenticated packages
             fortified += " --allow-unauthenticated"
             
             // Robustify update commands to prevent chain failure
             // Replace 'apt-get update &&' with 'apt-get update || true &&'
             if fortified.contains("update &&") {
                 fortified = fortified.replacingOccurrences(of: "apt-get update &&", with: "apt-get update || true &&")
                 fortified = fortified.replacingOccurrences(of: "apt update &&", with: "apt update || true &&")
             }

             // Only mask exit code for pure update commands (no install/remove/purge).
             // Install commands must preserve real exit codes so callers can detect failures.
             let isModifyCommand = lowerCmd.contains("install") || lowerCmd.contains("remove") || lowerCmd.contains("purge")
             if !isModifyCommand {
                 fortified = "(" + fortified + ") || true"
             }
             
             finalCommand = fortified
        } else if isYum {
            // Robust flags for yum/dnf
            var fortified = finalCommand
            if !fortified.contains(" -y") { fortified += " -y" }
            
            // For dnf, assume yes and non-interactive
            if fortified.contains("dnf ") {
                fortified = "export DNF_VAR_noninteractive=1; \(fortified)"
            }
            
            finalCommand = fortified
        }

        // Wrap in markers
        pty.write("\r")
        pty.write("echo '\(sm)'\r")
        pty.write("\(finalCommand)\r")
        pty.write("V_EXIT_CODE=$?\r")
        pty.write("echo \"V_EXIT_VAL:$V_EXIT_CODE\"\r")
        pty.write("echo '\(em)'\r")

        return await withCheckedContinuation { continuation in
            activeCommand?.continuation = continuation
            
            // Timeout logic
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000_000)
                if let active = self.activeCommand, active.startMarker == sm, !active.hasEndMarker {
                    print("⚠️ [ServerAdminEngine] Command timeout: \(cleanCommand.prefix(50))...")
                    let res = SSHCommandResult(
                        command: cleanCommand,
                        output: stripAnsiCodes(active.capturedOutput),
                        exitCode: -1,
                        executionTime: Date().timeIntervalSince(startTime)
                    )
                    active.continuation?.resume(returning: res)
                    self.activeCommand = nil
                }
            }
        }
    }

    private func handleOutput(_ text: String) {
        outputBuffer += text
        if outputBuffer.count > Self.maxOutputBufferSize {
            outputBuffer = String(outputBuffer.suffix(100_000))
        }

        guard var active = activeCommand else {
            // Connection phase
            return
        }

        active.capturedOutput += text
        
        let clean = stripAnsiCodes(active.capturedOutput)
        
        // Check for password prompt
        if (clean.lowercased().contains("password:") || clean.lowercased().contains("password for")) && !active.passwordInjected {
            if let pwd = password {
                active.passwordInjected = true
                print("🔐 [ServerAdminEngine] Injecting password...")
                ptyProcess?.write("\(pwd)\r")
            }
        }

        // Check for end marker
        if clean.contains(active.endMarker) {
            active.hasEndMarker = true
            let result = parseOutput(clean, sm: active.startMarker, em: active.endMarker, originalCommand: active.command, startTime: active.startTime)
            active.continuation?.resume(returning: result)
            activeCommand = nil
            return
        }

        activeCommand = active
    }

    private func parseOutput(_ text: String, sm: String, em: String, originalCommand: String, startTime: Date) -> SSHCommandResult {
        guard let smRange = text.range(of: sm) else {
            return SSHCommandResult(command: originalCommand, output: "", exitCode: -1, executionTime: Date().timeIntervalSince(startTime))
        }
        
        let afterStart = text[smRange.upperBound...]
        guard let emRange = afterStart.range(of: em) else {
            return SSHCommandResult(command: originalCommand, output: "", exitCode: -1, executionTime: Date().timeIntervalSince(startTime))
        }
        
        let content = String(afterStart[..<emRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = content.components(separatedBy: .newlines)
        
        var exitCode = 0
        var outputLines: [String] = []
        
        for line in lines {
            let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if l.hasPrefix("V_EXIT_VAL:") {
                if let codeStr = l.components(separatedBy: ":").last, let code = Int(codeStr) {
                    exitCode = code
                }
            } else if !l.contains(originalCommand) && !l.isEmpty {
                // Filter out noise like "export DEBIAN..."
                if !l.contains("DEBIAN_FRONTEND=noninteractive") {
                    outputLines.append(line)
                }
            }
        }
        
        // Clean the output of ANSI codes before returning
        let cleanedOutput = stripAnsiCodes(outputLines.joined(separator: "\n"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return SSHCommandResult(
            command: originalCommand,
            output: cleanedOutput,
            exitCode: exitCode,
            executionTime: Date().timeIntervalSince(startTime)
        )
    }

    private func waitForShellReady(timeout: Int = 60) async throws {
        let deadline = Date().addingTimeInterval(TimeInterval(timeout))
        var passwordInjected = false
        
        while Date() < deadline {
            let clean = stripAnsiCodes(outputBuffer)
            let lower = clean.lowercased()
            
            if lower.contains("permission denied") || lower.contains("authentication failed") {
                throw ServerAdminError.authenticationFailed
            }
            
            if lower.contains("password:") || lower.contains("passphrase:") {
                if !passwordInjected {
                    if let pwd = password {
                        passwordInjected = true
                        ptyProcess?.write("\(pwd)\r")
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        continue
                    } else {
                        throw ServerAdminError.authenticationFailed
                    }
                }
            }
            
            // Prompt detection
            let lines = clean.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
            if let last = lines.last?.trimmingCharacters(in: .whitespaces),
               last.hasSuffix("$") || last.hasSuffix("#") || last.hasSuffix(">") {
                return
            }
            
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        
        throw ServerAdminError.timeout("Shell Ready Polling")
    }

    private func setupEnvironment() async {
        let setupCmd = """
        stty -echo -echoctl 2>/dev/null; \
        export PS1='' PROMPT_COMMAND='' 2>/dev/null; \
        export DEBIAN_FRONTEND=noninteractive; \
        printf "\\033[?2004l" 2>/dev/null;
        """
        ptyProcess?.write("\r\(setupCmd)\r")
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        outputBuffer = ""
        silenced = true
    }

    private func stripAnsiCodes(_ text: String) -> String {
        var clean = text
        
        // Manual removal of common terminal codes
        let manualPatterns = ["[?2004h", "[?2004l", "\r"]
        for p in manualPatterns { clean = clean.replacingOccurrences(of: p, with: "") }
        
        // Remove ESC sequences: ESC [ ... any letter, and OSC sequences
        let patterns = [
            "(?:\\u{1B}\\[|\\x9B)[\\d;?]*[ -/]*[@-~]",  // CSI sequences
            "\\u{1B}\\][^\\u{07}]*\\u{07}",              // OSC sequences
            "\\u{1B}[()][AB012]",                         // Charset switching
            "\\u{1B}\\[[0-9;]*[a-zA-Z]"                  // General CSI
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: clean.utf16.count)
                clean = regex.stringByReplacingMatches(in: clean, options: [], range: range, withTemplate: "")
            }
        }
        
        // Remove standalone ESC characters
        clean = clean.replacingOccurrences(of: "\u{1B}", with: "")
        
        // Remove any remaining control characters (except newlines and tabs)
        clean = clean.filter { char in
            if char.isNewline || char == "\t" { return true }
            return char.asciiValue.map { $0 >= 32 } ?? true
        }
        
        return clean
    }
}
