//
//  ServerAdminExecutor.swift
//  Velo
//
//  Dedicated hidden SSH execution engine for Server Admin operations.
//  Creates its own PTYProcess and SSH session, completely separate from
//  the user-visible terminal. Used for package installation, version
//  switching, service control, and other admin-level operations.
//

import Foundation

// MARK: - Errors

enum AdminExecutorError: Error, LocalizedError {
    case alreadyConnected
    case connectionFailed(String)
    case authenticationFailed
    case notConnected
    case timeout

    var errorDescription: String? {
        switch self {
        case .alreadyConnected:       return "Already connected"
        case .connectionFailed(let m): return "Connection failed: \(m)"
        case .authenticationFailed:   return "Authentication failed"
        case .notConnected:           return "Not connected"
        case .timeout:                return "Connection timed out"
        }
    }
}

// MARK: - ServerAdminExecutor

/// An actor that provides a hidden, dedicated SSH channel for server admin operations.
/// It creates its own PTYProcess, establishes an independent SSH connection, and
/// executes commands without polluting the user-visible terminal.
actor ServerAdminExecutor {

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

    /// Establish a hidden SSH connection using the given credentials.
    /// Creates its own PTYProcess running `ssh user@host -p port`.
    func connect(using connection: SSHConnection, password: String?) async throws {
        guard case .disconnected = state else {
            throw AdminExecutorError.alreadyConnected
        }

        self.connection = connection
        self.password = password
        state = .connecting

        // Build a robust SSH command with additional flags for non-interactive use:
        // -tt: Force PTY allocation (ensures remote shell allocates a terminal)
        // -o StrictHostKeyChecking=accept-new: Auto-accept new host keys, reject changed ones
        // -o ServerAliveInterval=60: Keep connection alive during long installs
        // -o ServerAliveCountMax=5: Allow 5 missed keepalives before disconnecting
        var sshCmd = "ssh -tt"
        sshCmd += " -o StrictHostKeyChecking=accept-new"
        sshCmd += " -o ServerAliveInterval=60"
        sshCmd += " -o ServerAliveCountMax=5"
        if connection.port != 22 {
            sshCmd += " -p \(connection.port)"
        }
        if connection.authMethod == .privateKey, let keyPath = connection.privateKeyPath {
            sshCmd += " -i \(keyPath)"
        }
        sshCmd += " \(connection.username)@\(connection.host)"

        print("[AdminExecutor] Connecting: \(connection.username)@\(connection.host):\(connection.port)")
        print("[AdminExecutor] SSH command: \(sshCmd)")
        print("[AdminExecutor] Password available: \(password != nil)")

        // Create a PTYProcess with an output handler that routes to this actor
        let pty = PTYProcess { [weak self] text in
            guard let self = self else { return }
            Task { await self.handleOutput(text) }
        }
        self.ptyProcess = pty

        // Build environment
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["SSH_ASKPASS"] = ""            // Prevent GUI password prompts
        env["SSH_ASKPASS_REQUIRE"] = ""

        do {
            try pty.execute(
                command: sshCmd,
                environment: env,
                workingDirectory: NSHomeDirectory()
            )
        } catch {
            print("[AdminExecutor] PTYProcess.execute failed: \(error)")
            state = .error(error.localizedDescription)
            throw AdminExecutorError.connectionFailed(error.localizedDescription)
        }

        print("[AdminExecutor] PTY process started, waiting for shell ready...")

        // Wait for the SSH session to be ready (auth + shell prompt)
        do {
            try await waitForShellReady(timeout: 30)
        } catch {
            print("[AdminExecutor] waitForShellReady failed: \(error). Buffer: \(outputBuffer.suffix(300))")
            disconnect()
            throw error
        }

        print("[AdminExecutor] Shell ready, silencing session...")

        // Silence the session: disable echo, PS1, bracketed paste
        await silenceSession()

        state = .connected
        print("[AdminExecutor] ✅ Connected successfully to \(connection.username)@\(connection.host)")
    }

    // MARK: - Execute

    /// Execute a command on the hidden SSH session.
    /// Uses VADM_ marker-based output extraction (distinct from SSHBaseService's VBGN_/VEND_).
    /// Returns an SSHCommandResult with the clean output and exit code.
    func execute(_ command: String, timeout: Int = 60) async -> SSHCommandResult {
        guard case .connected = state, ptyProcess != nil else {
            print("[AdminExecutor] ❌ execute() called but not connected (state: \(state))")
            return SSHCommandResult(command: command, output: "", exitCode: -1, executionTime: 0)
        }
        print("[AdminExecutor] execute() queuing command: \(command.prefix(100))... (timeout: \(timeout)s)")

        // Serial execution: queue behind previous command
        let previousTask = executionQueue
        let newTask = Task { [previousTask] in
            _ = await previousTask?.value
            return await self.performExecute(command, timeout: timeout)
        }
        executionQueue = Task { _ = await newTask.value }

        return await newTask.value
    }

    // MARK: - Disconnect

    /// Terminate the SSH session and release resources.
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

    // MARK: - Private: Execute Implementation

    private func performExecute(_ command: String, timeout: Int) async -> SSHCommandResult {
        guard let pty = ptyProcess else {
            return SSHCommandResult(command: command, output: "", exitCode: -1, executionTime: 0)
        }

        let startTime = Date()

        // Generate unique markers (VADM prefix to distinguish from SSHBaseService's VBGN/VEND)
        let markerId = UUID().uuidString.prefix(8).lowercased()
        let sm = "VADM_\(markerId)"
        let em = "VADME_\(markerId)"

        var cleanCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)

        // Root user optimization: strip sudo if already root
        if let conn = connection, conn.username.lowercased() == "root", cleanCommand.contains("sudo") {
            if let regex = try? NSRegularExpression(pattern: "\\bsudo\\s+", options: []) {
                let range = NSRange(location: 0, length: cleanCommand.utf16.count)
                cleanCommand = regex.stringByReplacingMatches(in: cleanCommand, options: [], range: range, withTemplate: "")
            }
        }

        // Set up active command context
        activeCommand = ActiveAdminCommand(
            startMarker: sm,
            endMarker: em,
            command: cleanCommand,
            startTime: startTime
        )

        print("[AdminExecutor] Sending command with markers \(sm)/\(em)")
        print("[AdminExecutor] Clean command: \(cleanCommand.prefix(120))...")

        // Send marker-wrapped command sequence
        pty.write("\r")
        pty.write("printf '\(sm)\\n'\r")
        pty.write("\(cleanCommand)\r")
        pty.write("EXIT_CODE=$?\r")
        pty.write("printf \"$EXIT_CODE\\n\(em)\\n\"\r")
        pty.write("\r")

        // Wait for completion or timeout
        return await withCheckedContinuation { continuation in
            // Store continuation in active command
            activeCommand?.continuation = continuation

            // Timeout handler
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000_000)

                // If still waiting, force timeout
                if let active = self.activeCommand, !active.hasEndMarker {
                    print("[AdminExecutor] ⚠️ Command timed out after \(timeout)s: \(command.prefix(80))...")
                    print("[AdminExecutor] Captured output length: \(active.capturedOutput.count)")
                    let captured = active.capturedOutput
                    let (finalOutput, exitCode) = self.extractWithExitCode(captured, sm: active.startMarker, em: active.endMarker, originalCommand: active.command)
                    print("[AdminExecutor] Timeout result - exitCode: \(exitCode), output length: \(finalOutput.count)")
                    let result = SSHCommandResult(
                        command: command,
                        output: finalOutput,
                        exitCode: finalOutput.isEmpty ? 1 : exitCode,
                        executionTime: Date().timeIntervalSince(startTime)
                    )
                    self.activeCommand?.continuation?.resume(returning: result)
                    self.activeCommand = nil
                }
            }
        }
    }

    // MARK: - Private: Output Handling

    private func handleOutput(_ text: String) {
        outputBuffer += text

        // Cap buffer size
        if outputBuffer.count > Self.maxOutputBufferSize {
            outputBuffer = String(outputBuffer.suffix(5_000_000))
        }

        guard var active = activeCommand else {
            // No active command - check for password prompt during connection
            // (handled by waitForShellReady polling)
            return
        }

        active.capturedOutput += text

        // Cap captured output
        if active.capturedOutput.count > Self.maxOutputBufferSize {
            active.capturedOutput = String(active.capturedOutput.suffix(5_000_000))
        }

        // Check for end marker
        let cleanCaptured = stripAnsiCodes(active.capturedOutput)
        if cleanCaptured.contains(active.endMarker) {
            let markerLines = cleanCaptured.components(separatedBy: .newlines)
            let hasRealEndMarker = markerLines.contains { line in
                line.trimmingCharacters(in: .whitespaces) == active.endMarker
            }

            if hasRealEndMarker {
                active.hasEndMarker = true
                let (finalOutput, exitCode) = extractWithExitCode(
                    cleanCaptured, sm: active.startMarker, em: active.endMarker, originalCommand: active.command
                )
                let elapsed = Date().timeIntervalSince(active.startTime)
                print("[AdminExecutor] ✅ Command completed in \(String(format: "%.1f", elapsed))s - exitCode: \(exitCode), output: \(finalOutput.count) chars")
                let result = SSHCommandResult(
                    command: active.command,
                    output: finalOutput,
                    exitCode: exitCode,
                    executionTime: elapsed
                )
                active.continuation?.resume(returning: result)
                activeCommand = nil
                return
            }
        }

        // Check for password prompt (sudo) and auto-inject
        let lower = active.capturedOutput.lowercased()
        let isPasswordPrompt = lower.contains("password:") ||
                                lower.contains("passphrase:") ||
                                lower.contains("password for")

        if isPasswordPrompt && !active.passwordInjected {
            if let pwd = password {
                active.passwordInjected = true
                ptyProcess?.write("\(pwd)\r")
            }
        }

        // Auto-answer yes/no prompts
        if lower.contains("[y/n]") || lower.contains("(y/n)") || lower.contains("do you want to continue") {
            let lines = lower.components(separatedBy: .newlines)
            if let last = lines.last?.trimmingCharacters(in: .whitespaces),
               last.hasSuffix("[y/n]") || last.hasSuffix("(y/n)") || last.hasSuffix("?") || last.hasSuffix("]") {
                ptyProcess?.write("y\r")
            }
        }

        activeCommand = active
    }

    // MARK: - Private: Connection Setup

    private func waitForShellReady(timeout: Int) async throws {
        let deadline = Date().addingTimeInterval(TimeInterval(timeout))
        var passwordInjected = false
        var hostKeyAccepted = false
        var iterationCount = 0

        while Date() < deadline {
            iterationCount += 1

            // Strip ANSI codes for reliable pattern matching
            let cleanBuffer = stripAnsiCodes(outputBuffer)
            let lower = cleanBuffer.lowercased()

            if iterationCount % 10 == 1 {
                print("[AdminExecutor] waitForShellReady iteration \(iterationCount), buffer length: \(outputBuffer.count), clean length: \(cleanBuffer.count)")
                if !cleanBuffer.isEmpty {
                    let suffix = String(cleanBuffer.suffix(200))
                    print("[AdminExecutor] Buffer tail: \(suffix)")
                }
            }

            // Check for auth failure indicators
            if lower.contains("permission denied") || lower.contains("authentication failed") {
                print("[AdminExecutor] ❌ Authentication failed detected")
                throw AdminExecutorError.authenticationFailed
            }

            // Check for host key change (WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED)
            if lower.contains("host identification has changed") || lower.contains("host key verification failed") {
                print("[AdminExecutor] ❌ Host key verification failed")
                throw AdminExecutorError.connectionFailed("Host key verification failed. Remove old key with: ssh-keygen -R \(connection?.host ?? "host")")
            }

            // Check for connection failure
            if lower.contains("connection refused") || lower.contains("no route to host") ||
               lower.contains("connection timed out") || lower.contains("could not resolve") {
                print("[AdminExecutor] ❌ Connection failed: \(cleanBuffer.suffix(200))")
                throw AdminExecutorError.connectionFailed(cleanBuffer)
            }

            // Handle host key confirmation
            if !hostKeyAccepted && (lower.contains("are you sure you want to continue connecting") ||
               lower.contains("(yes/no")) {
                print("[AdminExecutor] Host key confirmation prompt detected, accepting...")
                hostKeyAccepted = true
                ptyProcess?.write("yes\r")
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                continue
            }

            // Handle password prompt
            let isPasswordPrompt = lower.contains("password:") ||
                                    lower.contains("passphrase:")
            if isPasswordPrompt && !passwordInjected {
                if let pwd = password {
                    print("[AdminExecutor] Password prompt detected, injecting password (\(pwd.count) chars)")
                    passwordInjected = true
                    ptyProcess?.write("\(pwd)\r")
                    // Give time for authentication
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds for auth
                    continue
                } else {
                    print("[AdminExecutor] ❌ Password prompt detected but no password available")
                    throw AdminExecutorError.authenticationFailed
                }
            }

            // Detect shell readiness using ANSI-stripped buffer:
            // After successful SSH login, we see a shell prompt like "$", "#", or ">"
            // or MOTD containing "Last login:" or "Welcome"
            if passwordInjected || !isPasswordPrompt {
                let trimmed = cleanBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                let lastLine = trimmed.components(separatedBy: .newlines).last?
                    .trimmingCharacters(in: .whitespaces) ?? ""

                // Check last line for prompt characters
                if lastLine.hasSuffix("$") || lastLine.hasSuffix("#") || lastLine.hasSuffix(">") {
                    print("[AdminExecutor] ✅ Shell prompt detected: '\(lastLine.suffix(40))'")
                    return
                }

                // Check for common login success indicators anywhere in buffer
                if trimmed.contains("Last login:") || trimmed.contains("Welcome") {
                    // Wait a bit more for the actual prompt to appear
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                    let recheck = stripAnsiCodes(outputBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
                    let recheckLast = recheck.components(separatedBy: .newlines).last?
                        .trimmingCharacters(in: .whitespaces) ?? ""
                    if recheckLast.hasSuffix("$") || recheckLast.hasSuffix("#") || recheckLast.hasSuffix(">") {
                        print("[AdminExecutor] ✅ Shell prompt detected after MOTD: '\(recheckLast.suffix(40))'")
                        return
                    }
                    // If MOTD is present but no prompt yet, the shell might use a non-standard prompt
                    // Give it another pass
                    if recheck.count > 100 {
                        print("[AdminExecutor] ✅ MOTD detected, buffer substantial (\(recheck.count) chars), assuming shell ready")
                        return
                    }
                }
            }

            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms polling
        }

        // If we got this far without error, assume shell is ready (some servers have non-standard prompts)
        if !outputBuffer.isEmpty {
            let cleanBuffer = stripAnsiCodes(outputBuffer)
            print("[AdminExecutor] ⚠️ Timeout reached but buffer has content (\(cleanBuffer.count) chars), assuming shell ready. Tail: \(cleanBuffer.suffix(200))")
            return
        }

        print("[AdminExecutor] ❌ Timeout with empty buffer")
        throw AdminExecutorError.timeout
    }

    private func silenceSession() async {
        guard !silenced, let pty = ptyProcess else { return }

        let setupCmd = """
        stty -echo -echoctl 2>/dev/null; \
        mesg n 2>/dev/null || true; \
        export PS1='' PROMPT_COMMAND='' 2>/dev/null; \
        printf "\\033[?2004l\\x1b[?2004l" 2>/dev/null; \
        alias which='which' 2>/dev/null;
        """
        pty.write("\r\(setupCmd)\r")

        // If root, silence kernel logs
        if connection?.username.lowercased() == "root" {
            pty.write("dmesg -n 1 2>/dev/null; echo 0 > /proc/sys/kernel/printk 2>/dev/null || true\r")
        }

        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s for setup to complete
        silenced = true
        outputBuffer = "" // Clear setup noise
    }

    // MARK: - Private: Output Parsing (mirrors SSHBaseService patterns)

    private func extractWithExitCode(_ text: String, sm: String, em: String, originalCommand: String) -> (String, Int) {
        let cleanText = stripAnsiCodes(text)

        guard let smRange = cleanText.range(of: sm, options: .backwards) else { return ("", 0) }
        let afterStart = cleanText[smRange.upperBound...]

        guard let emRange = afterStart.range(of: em) else {
            let content = String(afterStart).trimmingCharacters(in: .whitespacesAndNewlines)
            return parseFinalOutput(content, originalCommand: originalCommand)
        }

        let content = String(afterStart[..<emRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        return parseFinalOutput(content, originalCommand: originalCommand)
    }

    private func parseFinalOutput(_ content: String, originalCommand: String) -> (String, Int) {
        var lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Last line should be the exit code
        var exitCode = 0
        if let lastLine = lines.last, let code = Int(lastLine) {
            exitCode = code
            lines.removeLast()
        }

        // Filter out noise
        let cleanedLines = lines.filter { line in
            let isCommandEcho = line == originalCommand
            let isSilencingNoise = line.contains("stty -echo") ||
                                    line.contains("export PS1") ||
                                    line.contains("export PROMPT_COMMAND") ||
                                    line.contains("printf") ||
                                    line.contains("EXIT_CODE=")
            return !isCommandEcho && !isSilencingNoise
        }

        return (cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines), exitCode)
    }

    private func stripAnsiCodes(_ text: String) -> String {
        var clean = text
        // Strip known bracketed paste / private mode sequences
        let manualPatterns = [
            "\u{1B}[?2004h", "\u{1B}[?2004l", "\u{1B}[?2001h", "\u{1B}[?2001l",
            "[?2004h", "[?2004l", "[?2001h", "[?2001l", "[?1h", "[?1l", "[?25h", "[?25l"
        ]
        for p in manualPatterns {
            clean = clean.replacingOccurrences(of: p, with: "")
        }

        // Comprehensive ANSI regex
        let pattern = [
            "(?:\u{1B}\\[|\\x9B)[\\d;?]*[ -/]*[@-~]",          // CSI sequences
            "\u{1B}\\][^\u{0007}\u{1B}]*(?:\u{0007}|\u{1B}\\\\)", // OSC sequences
            "\u{1B}[PX^_].*?\u{1B}\\\\",                         // DCS, PM, APC
            "\u{1B}[@-_]",                                         // Fe escape sequences
            "[\u{0080}-\u{009F}]",                                 // C1 control codes
            "\r"                                                   // Carriage return
        ].joined(separator: "|")

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return clean }
        let range = NSRange(location: 0, length: clean.utf16.count)
        return regex.stringByReplacingMatches(in: clean, options: [], range: range, withTemplate: "")
    }
}
