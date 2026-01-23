//
//  SSHBaseService.swift
//  Velo
//
//  Created by Velo Assistant
//  Core execution engine for SSH commands using an Actor for non-blocking serial execution.
//

import Foundation

@MainActor
final class OutputStatus {
    var capturedOutput: String = ""
    var hasEndMarker: Bool = false
    var hasStartMarker: Bool = false
    var continuation: CheckedContinuation<SSHCommandResult, Never>?
}

/// actor that ensures only one SSH command runs at a time without blocking the UI
actor SSHBaseService: TerminalOutputDelegate {
    static let shared = SSHBaseService()
    
    private var forceResetNextCommand = false
    
    private init() {}
    
    // Track which sessions have been silenced (stty -echo) to avoid repeated setup
    private var silencedSessionIds = Set<UUID>()
    
    // Track which sessions we're actively watching (for SSH password injection)
    private var watchedSessions = [UUID: TerminalViewModel]()
    
    // Track if SSH connection password has been injected for a session
    private var sshPasswordInjected = Set<UUID>()
    
    // Serial queue per session to prevent interleaving
    private var sessionQueues = [UUID: Task<Void, Never>]()
    
    // Active command context
    private struct ActiveCommand {
        let sm: String
        let em: String
        let cleanCommand: String
        let startTime: Date
        let status: OutputStatus
        let terminalViewModel: TerminalViewModel?
        let password: String?
        var passwordInjected: Bool = false
    }
    private var activeCommands = [UUID: ActiveCommand]()
    
    func setForceReset(_ value: Bool) {
        forceResetNextCommand = value
    }
    
    /// Execute a command via terminal engine and capture output surgically
    func execute(_ command: String, via session: TerminalViewModel, timeout: Int = 20) async -> SSHCommandResult {
        let sessionId = await MainActor.run { session.id }
        
        // Ensure serial execution for this specific session
        let previousTask = sessionQueues[sessionId]
        let newTask = Task { [previousTask] in
            _ = await previousTask?.value
            return await self.performExecute(command, via: session, timeout: timeout)
        }
        sessionQueues[sessionId] = Task { _ = await newTask.value }
        
        return await newTask.value
    }

    private func performExecute(_ command: String, via session: TerminalViewModel, timeout: Int = 20) async -> SSHCommandResult {
        let startTime = Date()
        let (engine, sessionId) = await MainActor.run { 
            session.terminalEngine.delegate = self
            print("🔔 [SSHBase] Delegate SET on engine. self = \\(String(describing: self))")
            return (session.terminalEngine, session.id) 
        }
        
        // Track this session for SSH password injection
        watchedSessions[sessionId] = session
        
        // Wait for SSH authentication if this is the first command for this session
        // This gives time for the buffered password prompt to be processed and password injected
        if !silencedSessionIds.contains(sessionId) {
            print("🔧 [SSHBase] Waiting for SSH session authentication...")
            
            // Wait up to 5 seconds for password injection to complete
            var waitAttempts = 0
            let maxWaitAttempts = 50 // 50 * 100ms = 5 seconds
            
            while waitAttempts < maxWaitAttempts {
                // Allow actor to process pending output handlers
                await Task.yield()
                
                // Check if password was injected (meaning auth is in progress/done)
                if sshPasswordInjected.contains(sessionId) {
                    print("🔧 [SSHBase] SSH password was injected, waiting for shell prompt...")
                    // Give extra time for SSH to fully authenticate after password
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    break
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                waitAttempts += 1
            }
            
            if waitAttempts >= maxWaitAttempts {
                print("🔧 [SSHBase] ⚠️ Timeout waiting for SSH auth, proceeding anyway...")
            }
        }
        
        // 1. Warmup / Reset logic
        if forceResetNextCommand {
            forceResetNextCommand = false
            await MainActor.run { engine.sendInput("\u{03}\n") }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        // Ensure silence on the specific session
        if !silencedSessionIds.contains(sessionId) {
            silencedSessionIds.insert(sessionId)
            
            print("🔧 [SSHBase] First time silencing session \(sessionId)...")
            await MainActor.run { 
                // Combine into a single command block to reduce terminal noise and speed up initialization
                let setupCmd = """
                stty -echo -echoctl 2>/dev/null; \
                mesg n 2>/dev/null || true; \
                export PS1='' PROMPT_COMMAND='' 2>/dev/null; \
                printf "\\033[?2004l\\x1b[?2004l" 2>/dev/null; \
                alias which='which' 2>/dev/null;
                """
                engine.sendInput("\n\(setupCmd)\n")
                
                // Silence kernel logs if root
                if session.activeSSHConnectionString?.lowercased().hasPrefix("root@") ?? false {
                    engine.sendInput("dmesg -n 1 2>/dev/null; echo 0 > /proc/sys/kernel/printk 2>/dev/null || true\n")
                }
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000) // Increased to 1.5 seconds
        }
        
        // 2. Wrap command in absolute unique markers
        let markerId = UUID().uuidString.prefix(8).lowercased()
        let sm = "VBGN_\(markerId)"
        let em = "VEND_\(markerId)"
        
        var cleanCommand = command.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // 3. Root User Optimization: If already root, bypass sudo everywhere (start of line or after pipes)
        let isRoot = await MainActor.run {
            session.activeSSHConnectionString?.lowercased().hasPrefix("root@") ?? false
        }
        
        if isRoot && cleanCommand.contains("sudo") {
            print("🔧 [SSHBase] Root user detected: Stripping sudo prefixes safely")
            // Use word boundary regex to safely remove 'sudo ' without mangling adjacent characters or commands (like 'stee')
            if let regex = try? NSRegularExpression(pattern: "\\bsudo\\s+", options: []) {
                let range = NSRange(location: 0, length: cleanCommand.utf16.count)
                cleanCommand = regex.stringByReplacingMatches(in: cleanCommand, options: [], range: range, withTemplate: "")
            }
        }
        
        // 2.5 Find password for auto-injection
        let password = await self.fetchPasswordForSession(session)
        
        let status = await OutputStatus()
        activeCommands[sessionId] = ActiveCommand(
            sm: sm, 
            em: em, 
            cleanCommand: cleanCommand, 
            startTime: startTime, 
            status: status,
            terminalViewModel: session,
            password: password
        )
        
        await MainActor.run {
            AppLogger.shared.log("Executing: \(cleanCommand)", level: .cmd)
            engine.sendInput("\n")
            // Note: We use printf to avoid 'echo' escaping issues and add a trailing marker check
            engine.sendInput("printf '\(sm)\\n'\n")
            engine.sendInput("\(cleanCommand)\n")
            engine.sendInput("EXIT_CODE=$?\n")
            engine.sendInput("printf \"$EXIT_CODE\\n\(em)\\n\"\n")
            engine.sendInput("\n")
        }
        
        // 3. Wait for continuation or timeout
        return await withCheckedContinuation { [status] continuation in
            Task {
                await status.setContinuation(continuation)
                
                // Timeout handler
                try? await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000_000)
                
                if await !status.hasEndMarker {
                    let result = await self.finishCommandTimeout(sessionId, command: command, startTime: startTime)
                    await status.resumeIfNeeded(with: result)
                }
            }
        }
    }
    
    /// Write a file to the remote server
    /// Uses `printf` for small files (fast, robust, no parsing states) and Heredoc for large files.
    /// Write a file to the remote server using Chunked Hex Strategy
    /// This is the "Bulletproof" method:
    /// 1. Splits content into tiny chunks (500 bytes).
    /// 2. Hex-encodes each chunk to bypass shell parsing (!, $, ", ').
    /// 3. Appends sequentially.
    /// 4. Completely avoids PTY buffer overflows and History Expansion crashes.
    /// Write a file to the remote server using Micro-Chunked Hex Strategy
    /// "Paranoid Mode":
    /// 1. Splits content into tiny chunks (100 bytes).
    /// 2. Hex-encodes each chunk.
    /// 3. Uses `tee -a` for appending.
    /// 4. Removes `sudo` from `printf` to avoid shell builtin conflicts.
    /// Write a file to the remote server using "Temp-Staging" Chunked Hex Strategy
    /// 1. Uploads content to a temporary file (`/tmp/velo_...`) using Micro-Chunks.
    /// 2. Uses `cat temp | tee dest` to move content to final destination safely.
    /// 3. Preserves destination permissions and minimizes sudo usage in the loop.
    func writeFile(at path: String, content: String, useSudo: Bool = true, via session: TerminalViewModel) async -> Bool {
        let safePath = path.replacingOccurrences(of: "'", with: "'\\''")
        let tempPath = "/tmp/velo_upload_\(UUID().uuidString.prefix(8))"
        
        // 1. Initialize Temp File (Truncate)
        // No sudo needed for /tmp usually.
        let initCmd = "printf '' > '\(tempPath)' && echo 'INIT_OK'"
        let initResult = await execute(initCmd, via: session, timeout: 10)
        
        guard initResult.output.contains("INIT_OK") else {
            print("❌ [SSHBase] Failed to initialize temp file at \(tempPath). Output: \(initResult.output)")
            return false
        }
        
        guard let data = content.data(using: .utf8) else { return false }
        
        // MICRO-CHUNK SIZE: 200 bytes
        // Slightly larger than 100 since we rely on temp file simple append which is faster/lighter
        let chunkSize = 200
        let totalBytes = data.count
        var offset = 0
        var chunkIndex = 0
        let totalChunks = Int(ceil(Double(totalBytes) / Double(chunkSize)))
        
        print("💾 [SSHBase] Staging \(totalBytes) bytes to \(tempPath) (Avg Chunk: \(chunkSize))...")
        
        // 2. Upload Loop (To Temp)
        while offset < totalBytes {
            let length = min(chunkSize, totalBytes - offset)
            let chunkData = data.subdata(in: offset..<offset+length)
            let hexEscaped = chunkData.map { String(format: "\\x%02x", $0) }.joined()
            
            // Simple append to temp file. No sudo. No tee.
            let cmd = "printf %b '\(hexEscaped)' >> '\(tempPath)' && echo 'C_OK'"
            
            // Execute
            let result = await execute(cmd, via: session, timeout: 10)
            
            if !result.output.contains("C_OK") {
                print("❌ [SSHBase] Chunk \(chunkIndex + 1)/\(totalChunks) failed. Offset: \(offset). Output: \(result.output)")
                // Attempt cleanup
                _ = await execute("rm -f '\(tempPath)'", via: session, timeout: 5)
                return false
            }
            
            offset += length
            chunkIndex += 1
            
            // Throttle: 100ms delay to let PTY buffer drain and prevent race conditions
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // 3. Finalize: Copy Temp to Dest
        print("💾 [SSHBase] Upload complete. Installing to \(path)...")
        
        // `cat temp | sudo tee dest`
        // This preserves destination permissions (unlike mv) and handles sudo authentication once.
        let installCmd = "\(useSudo ? "sudo " : "")cat '\(tempPath)' | \(useSudo ? "sudo " : "")tee '\(safePath)' > /dev/null && echo 'INSTALL_OK'"
        let installResult = await execute(installCmd, via: session, timeout: 30) // Long timeout for disk I/O
        
        // Cleanup Temp
        _ = await execute("rm -f '\(tempPath)'", via: session, timeout: 5)
        
        if installResult.output.contains("INSTALL_OK") {
            print("✅ [SSHBase] Successfully wrote file to \(path)")
            return true
        } else {
            print("❌ [SSHBase] Install failed. Output: \(installResult.output)")
            return false
        }
    }
    
    /// Read a file from the remote server
    func readFile(at path: String, via session: TerminalViewModel) async -> String? {
        let cmd = "sudo cat '\(path)' 2>/dev/null"
        let result = await execute(cmd, via: session, timeout: 15)
        return result.exitCode == 0 ? result.output : nil
    }

    private func finishCommandTimeout(_ sessionId: UUID, command: String, startTime: Date) async -> SSHCommandResult {
        guard let active = activeCommands[sessionId] else {
            return SSHCommandResult(command: command, output: "", exitCode: 1, executionTime: Date().timeIntervalSince(startTime))
        }
        
        print("🔧 [SSHBase] ⚠️ Timeout for: \(command.prefix(40))")
        
        // CRITICAL: If a command times out, the session is likely stuck (e.g. waiting for input in a heredoc).
        // We MUST force a reset (Ctrl+C) on the next command to unblock the session.
        self.forceResetNextCommand = true
        print("🔧 [SSHBase] 🔄 Scheduled session reset (Ctrl+C) for next command")
        
        activeCommands.removeValue(forKey: sessionId)
        
        let captured = await active.status.capturedOutput
        let finalClean = extract(captured, sm: active.sm, em: active.em, originalCommand: active.cleanCommand)
        
        return SSHCommandResult(
            command: command, 
            output: finalClean, 
            exitCode: finalClean.isEmpty ? 1 : 0, 
            executionTime: Date().timeIntervalSince(startTime)
        )
    }

    // MARK: - TerminalOutputDelegate
    
    nonisolated func terminalDidReceiveOutput(_ engine: TerminalEngine, text: String) {
        print("🔔 [SSHBase] Delegate received output: \(text.prefix(50))...")
        Task {
            await self.handleIncomingOutput(engine, text: text)
        }
    }
    
    // Corrected handleIncomingOutput
    private func handleIncomingOutput(_ sender: TerminalEngine, text: String) async {
        print("🔔 [SSHBase] handleIncomingOutput called. activeCommands count: \(activeCommands.count)")
        
        for (sessionId, active) in activeCommands {
            // Precise routing: Only process output if it comes from the engine that started this command
            let isCorrectEngine = await MainActor.run {
                active.terminalViewModel?.terminalEngine === sender
            }
            
            print("🔔 [SSHBase] Checking session \(sessionId). isCorrectEngine: \(isCorrectEngine)")
            
            guard isCorrectEngine else { continue }
            
            let status = active.status
            await status.appendOutput(text)
            
            // OPTIMIZATION: Don't read the whole string and split by lines on every packet.
            // Just check if we saw the End Marker recently.
            // We can check the whole string for the substring first (fast), then verify line position.
            let currentAll = await status.capturedOutput
            let em = active.em
            
            var commandFinished = false
            
            if currentAll.contains(em) {
                // Event-driven completion: Check for the end marker
                // A real marker will typically be on its own line and NOT preceded by "echo " or "printf "
                let markerLines = currentAll.components(separatedBy: .newlines)
                let hasRealEndMarker = markerLines.contains { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    return trimmed == em
                }
                
                if hasRealEndMarker {
                    commandFinished = true
                    await status.setHasEndMarker(true)
                    activeCommands.removeValue(forKey: sessionId)
                    
                    let originalCommand = active.cleanCommand
                    let sm = active.sm
                    let startTime = active.startTime
                    
                    // Perform heavy extraction off-actor to keep the queue moving
                    Task.detached(priority: .userInitiated) {
                        let (finalClean, exitCode) = self.extractWithExitCode(currentAll, sm: sm, em: em, originalCommand: originalCommand)
                        let result = SSHCommandResult(
                            command: originalCommand,
                            output: finalClean,
                            exitCode: exitCode,
                            executionTime: Date().timeIntervalSince(startTime)
                        )
                        
                        await status.resumeIfNeeded(with: result)
                    }
                    
                    print("🔧 [SSHBase] ✅ Event-driven completion for: \(active.cleanCommand.prefix(20))")
                    break
                }
            }
            
            // If we finished, we don't need to check for passwords
            if commandFinished { continue }
            
            let lowerAll = currentAll.lowercased()
            let isPasswordPrompt = lowerAll.contains("password:") || 
                                 lowerAll.contains("passphrase:") ||
                                 lowerAll.contains("password for") ||
                                 lowerAll.contains("رمز المرور") // Arabic support for user
            
            if isPasswordPrompt && !active.passwordInjected {
                if let pwd = active.password {
                    var updated = active
                    updated.passwordInjected = true
                    activeCommands[sessionId] = updated
                    
                    print("🔧 [SSHBase] 🔐 Injecting sudo password for command: \(active.cleanCommand.prefix(20))")
                    await MainActor.run {
                        // Use \r for PTY - terminals expect Carriage Return, not Line Feed
                        active.terminalViewModel?.terminalEngine.sendInput("\(pwd)\r")
                    }
                } else {
                    // Log why we didn't inject
                    print("🔧 [SSHBase] ⚠️ Password prompt detected for '\(active.cleanCommand.prefix(20))' but no password available for this session.")
                }
            }
        }
        
        // FALLBACK: Check for SSH connection password prompt even if no active command
        // This handles the case where SSH connection itself needs password before any command
        let lowerText = text.lowercased()
        let isSSHPasswordPrompt = lowerText.contains("password:") || 
                                   lowerText.contains("passphrase:") ||
                                   lowerText.contains("password for")
        
        if isSSHPasswordPrompt && activeCommands.isEmpty {
            print("🔧 [SSHBase] Detected SSH connection password prompt. Checking watched sessions...")
            
            // Find the session by matching the engine
            for (sessionId, session) in watchedSessions {
                let isCorrectEngine = await MainActor.run {
                    session.terminalEngine === sender
                }
                
                guard isCorrectEngine else { continue }
                
                // Check if we already injected password for this SSH connection
                guard !sshPasswordInjected.contains(sessionId) else {
                    print("🔧 [SSHBase] SSH password already injected for session \(sessionId)")
                    continue
                }
                
                // Try to get password for this session
                if let password = await fetchPasswordForSession(session) {
                    sshPasswordInjected.insert(sessionId)
                    print("🔧 [SSHBase] 🔐 Injecting SSH connection password for session \(sessionId)")
                    await MainActor.run {
                        // Use \r for PTY - terminals expect Carriage Return, not Line Feed
                        session.terminalEngine.sendInput("\(password)\r")
                    }
                } else {
                    print("🔧 [SSHBase] ⚠️ SSH password prompt detected but no password found for session \(sessionId)")
                }
            }
        }
    }
    
    nonisolated private func extractWithExitCode(_ text: String, sm: String, em: String, originalCommand: String) -> (String, Int) {
        // First strip ANSI codes from the whole blob to make marker matching reliable
        let cleanText = stripAnsiCodes(text)
        
        guard let smRange = cleanText.range(of: sm, options: .backwards) else { return ("", 0) }
        let afterStart = cleanText[smRange.upperBound...]
        
        guard let emRange = afterStart.range(of: em) else { 
            let content = String(afterStart).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return parseFinalOutput(content, originalCommand: originalCommand)
        }
        
        let content = String(afterStart[..<emRange.lowerBound]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return parseFinalOutput(content, originalCommand: originalCommand)
    }

    nonisolated private func parseFinalOutput(_ content: String, originalCommand: String) -> (String, Int) {
        var lines = content.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            
        // The last line should be our exit code
        var exitCode = 0
        if let lastLine = lines.last, let code = Int(lastLine) {
            exitCode = code
            lines.removeLast()
        }
        
        // Final cleaning
        let cleanedLines = lines.filter { line in
            let isCommandEcho = line == originalCommand
            let isSilencingNoise = line.contains("stty -echo") || line.contains("export PS1") || line.contains("export PROMPT_COMMAND") || line.contains("printf") || line.contains("EXIT_CODE=")
            return !isCommandEcho && !isSilencingNoise
        }

        return (cleanedLines.joined(separator: "\n").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), exitCode)
    }

    nonisolated private func extract(_ text: String, sm: String, em: String, originalCommand: String) -> String {
        return extractWithExitCode(text, sm: sm, em: em, originalCommand: originalCommand).0
    }

    nonisolated private func stripAnsiCodes(_ text: String) -> String {
        var clean = text
        // 1. Manually strip literal bracketed paste and other private mode sequences
        // Handle both with and without ESC prefix, and literal representations
        let manualPatterns = [
            "\u{1B}[?2004h", "\u{1B}[?2004l", "\u{1B}[?2001h", "\u{1B}[?2001l",
            "[?2004h", "[?2004l", "[?2001h", "[?2001l", "[?1h", "[?1l", "[?25h", "[?25l"
        ]
        for p in manualPatterns {
            clean = clean.replacingOccurrences(of: p, with: "")
        }
        
        // 2. Comprehensive ANSI regex - covers colors, cursor, and private modes
        let pattern = [
            "[\\u001B\\u009B][[\\]()#;?]*((?:[a-zA-Z\\d]*(?:;[-a-zA-Z\\d\\/#&.:=?%@~_]*)*)?\\u0007|(?:(?:\\d{1,4}(?:;\\d{0,4})*)?[\\dA-PR-TZcf-ntqry=><~]))",
            "\\u001B\\[[\\?\\d;]*[hl]",
            "\\u001B\\][\\d;]*\\u0007", // OSC sequences
            "\\r"
        ].joined(separator: "|")
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return clean }
        let range = NSRange(location: 0, length: clean.utf16.count)
        return regex.stringByReplacingMatches(in: clean, options: [], range: range, withTemplate: "")
    }
    
    // MARK: - Session Cleanup

    /// Clear all caches for a session when it ends
    /// This prevents memory accumulation from long-running sessions
    func clearSessionCache(for sessionId: UUID) {
        sessionPasswords.removeValue(forKey: sessionId)
        activeCommands.removeValue(forKey: sessionId)
        silencedSessionIds.remove(sessionId)
        sessionQueues.removeValue(forKey: sessionId)
        watchedSessions.removeValue(forKey: sessionId)
        sshPasswordInjected.remove(sessionId)
        print("🧹 [SSHBase] Cleared caches for session \(sessionId)")
    }

    // MARK: - Helpers

    private var sessionPasswords = [UUID: String]()

    private func fetchPasswordForSession(_ session: TerminalViewModel) async -> String? {
        let sessionId = await MainActor.run { session.id }
        
        // 1. Check Cache
        if let cached = sessionPasswords[sessionId] {
            print("🔐 [SSHBase] Using cached password for session \(sessionId)")
            return cached
        }
        
        let connStr = await MainActor.run { session.activeSSHConnectionString }
        print("🔐 [SSHBase] Fetching password for connection: \(connStr ?? "nil")")
        
        guard let connStr = connStr else { 
            print("🔐 [SSHBase] ⚠️ No connection string available")
            return nil 
        }
        
        let parts = connStr.components(separatedBy: "@")
        guard parts.count == 2 else { 
            print("🔐 [SSHBase] ⚠️ Invalid connection string format: \(connStr)")
            return nil 
        }
        
        let username = parts[0]
        let hostAndPort = parts[1]
        let host = hostAndPort.components(separatedBy: ":").first ?? hostAndPort
        
        print("🔐 [SSHBase] Looking for: username='\(username)', host='\(host)'")
        
        let password = await MainActor.run {
            let manager = SSHManager()
            let savedConnections = manager.connections
            
            print("🔐 [SSHBase] Found \(savedConnections.count) saved connections")
            for conn in savedConnections {
                print("🔐 [SSHBase]   - \(conn.username)@\(conn.host):\(conn.port)")
            }
            
            // Try to find matching connection
            if let conn = savedConnections.first(where: { 
                $0.host.lowercased() == host.lowercased() && 
                $0.username.lowercased() == username.lowercased() 
            }) {
                print("🔐 [SSHBase] ✅ Found matching connection: \(conn.username)@\(conn.host)")
                let pwd = manager.getPassword(for: conn)
                print("🔐 [SSHBase] Password from keychain: \(pwd != nil ? "Found (\(pwd!.count) chars)" : "NOT FOUND")")
                return pwd
            }
            
            print("🔐 [SSHBase] ⚠️ No matching connection found")
            return nil
        }
        
        // 2. Cache Result
        if let found = password {
            sessionPasswords[sessionId] = found
            print("🔐 [SSHBase] ✅ Password cached for session \(sessionId)")
        }
        
        return password
    }
}

@MainActor
extension OutputStatus {
    /// Maximum size for captured output to prevent memory explosion (10MB)
    private static let maxCapturedOutputSize = 10_000_000

    func appendOutput(_ text: String) {
        capturedOutput += text

        // PERFORMANCE FIX: Cap output size to prevent memory explosion
        if capturedOutput.count > Self.maxCapturedOutputSize {
            // Keep the last 5MB to preserve recent context including potential markers
            capturedOutput = String(capturedOutput.suffix(5_000_000))
        }
    }

    func setHasEndMarker(_ val: Bool) { hasEndMarker = val }
    func setContinuation(_ cont: CheckedContinuation<SSHCommandResult, Never>) { continuation = cont }

    func resumeIfNeeded(with result: SSHCommandResult) {
        if let cont = continuation {
            cont.resume(returning: result)
            continuation = nil
        }
    }
}
