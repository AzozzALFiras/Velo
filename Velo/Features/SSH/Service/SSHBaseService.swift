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
            return (session.terminalEngine, session.id) 
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
            try? await Task.sleep(nanoseconds: 1_200_000_000)
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
        return await withCheckedContinuation { continuation in
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
    
    private func finishCommandTimeout(_ sessionId: UUID, command: String, startTime: Date) async -> SSHCommandResult {
        guard let active = activeCommands[sessionId] else {
            return SSHCommandResult(command: command, output: "", exitCode: 1, executionTime: Date().timeIntervalSince(startTime))
        }
        
        print("🔧 [SSHBase] ⚠️ Timeout for: \(command.prefix(40))")
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
        Task {
            await self.handleIncomingOutput(engine, text: text)
        }
    }
    
    private func handleIncomingOutput(_ sender: TerminalEngine, text: String) async {
        for (sessionId, active) in activeCommands {
            // Precise routing: Only process output if it comes from the engine that started this command
            let isCorrectEngine = await MainActor.run {
                active.terminalViewModel?.terminalEngine === sender
            }
            
            guard isCorrectEngine else { continue }
            
            let status = active.status
            await status.appendOutput(text)
            
            let currentAll = await status.capturedOutput
            
            // Event-driven completion: Check for the end marker
            // IMPORTANT: We must ensure this is the REAL marker, not an echo of the command
            // A real marker will typically be on its own line and NOT preceded by "echo " or "printf "
            let markerLines = currentAll.components(separatedBy: .newlines)
            let hasRealEndMarker = markerLines.contains { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed == active.em
            }
            
            if hasRealEndMarker {
                await status.setHasEndMarker(true)
                activeCommands.removeValue(forKey: sessionId)
                
                let (finalClean, exitCode) = extractWithExitCode(currentAll, sm: active.sm, em: active.em, originalCommand: active.cleanCommand)
                let result = SSHCommandResult(
                    command: active.cleanCommand,
                    output: finalClean,
                    exitCode: exitCode,
                    executionTime: Date().timeIntervalSince(active.startTime)
                )
                
                await status.resumeIfNeeded(with: result)
                print("🔧 [SSHBase] ✅ Event-driven completion for: \(active.cleanCommand.prefix(20))")
                break
            }
            
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
                        active.terminalViewModel?.terminalEngine.sendInput("\(pwd)\n")
                    }
                } else {
                    // Log why we didn't inject
                    print("🔧 [SSHBase] ⚠️ Password prompt detected for '\(active.cleanCommand.prefix(20))' but no password available for this session.")
                }
            }
        }
    }
    
    private func extractWithExitCode(_ text: String, sm: String, em: String, originalCommand: String) -> (String, Int) {
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

    private func parseFinalOutput(_ content: String, originalCommand: String) -> (String, Int) {
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

    private func extract(_ text: String, sm: String, em: String, originalCommand: String) -> String {
        return extractWithExitCode(text, sm: sm, em: em, originalCommand: originalCommand).0
    }

    private func stripAnsiCodes(_ text: String) -> String {
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
    
    // MARK: - Helpers
    
    private func fetchPasswordForSession(_ session: TerminalViewModel) async -> String? {
        let connStr = await MainActor.run { session.activeSSHConnectionString }
        guard let connStr = connStr else { return nil }
        
        let parts = connStr.components(separatedBy: "@")
        guard parts.count == 2 else { return nil }
        
        let username = parts[0]
        let hostAndPort = parts[1]
        let host = hostAndPort.components(separatedBy: ":").first ?? hostAndPort
        
        return await MainActor.run {
            let manager = SSHManager()
            let savedConnections = manager.connections
            
            print("🔑 [SSHBase] Looking for credentials for \(username)@\(host)... (Total saved: \(savedConnections.count))")
            
            // Try to find matching connection
            if let conn = savedConnections.first(where: { 
                $0.host.lowercased() == host.lowercased() && 
                $0.username.lowercased() == username.lowercased() 
            }) {
                let pwd = manager.getPassword(for: conn)
                print("🔑 [SSHBase] ✅ Found matching connection '\(conn.name)' - Password: \(pwd != nil ? "YES" : "NO")")
                return pwd
            } else {
                print("🔑 [SSHBase] ❌ No matching connection found for \(username)@\(host)")
                for c in savedConnections {
                    print("  - Available: \(c.username)@\(c.host)")
                }
            }
            return nil
        }
    }
}

@MainActor
extension OutputStatus {
    func appendOutput(_ text: String) { capturedOutput += text }
    func setHasEndMarker(_ val: Bool) { hasEndMarker = val }
    func setContinuation(_ cont: CheckedContinuation<SSHCommandResult, Never>) { continuation = cont }
    
    func resumeIfNeeded(with result: SSHCommandResult) {
        if let cont = continuation {
            cont.resume(returning: result)
            continuation = nil
        }
    }
}
