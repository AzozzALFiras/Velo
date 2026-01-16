//
//  SSHBaseService.swift
//  Velo
//
//  Created by Velo Assistant
//  Core execution engine for SSH commands using an Actor for non-blocking serial execution.
//

import Foundation

/// actor that ensures only one SSH command runs at a time without blocking the UI
actor SSHBaseService {
    static let shared = SSHBaseService()
    
    private var forceResetNextCommand = false
    
    private init() {}
    
    // Track which sessions have been silenced (stty -echo) to avoid repeated setup
    private var silencedSessionIds = Set<UUID>()
    
    func setForceReset(_ value: Bool) {
        forceResetNextCommand = value
    }
    
    /// Execute a command via terminal engine and capture output surgically
    func execute(_ command: String, via session: TerminalViewModel, timeout: Int = 20) async -> SSHCommandResult {
        let startTime = Date()
        let (engine, sessionId) = await MainActor.run { (session.terminalEngine, session.id) }
        
        // 1. Warmup / Reset logic
        if forceResetNextCommand {
            forceResetNextCommand = false
            await MainActor.run { engine.sendInput("\u{03}\n") }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        // Ensure silence on the specific session
        if !silencedSessionIds.contains(sessionId) {
            print("🔧 [SSHBase] First time silencing session \(sessionId)...")
            await MainActor.run { 
                engine.sendInput("\nstty -echo\n") 
                engine.sendInput("export PS1=''\n")
                engine.sendInput("export PROMPT_COMMAND=''\n")
            }
            // Give it more time to settle
            try? await Task.sleep(nanoseconds: 800_000_000)
            silencedSessionIds.insert(sessionId)
        }
        
        // 2. Wrap command in absolute unique markers
        let markerId = UUID().uuidString.prefix(12)
        let sm = "___V_BGN_\(markerId)___"
        let em = "___V_END_\(markerId)___"
        
        let lastLineIdAtStart = await MainActor.run { engine.outputLines.last?.id }
        
        await MainActor.run {
            // Send markers on separate lines to isolate them from terminal echoes and command output.
            engine.sendInput("\n\necho '\(sm)'\n\(command)\necho '\(em)'\n\n")
        }
        
        var attempts = 0
        let maxAttempts = timeout * 10
        var capturedOutput = ""
        
        // 3. Wait for markers (non-blocking)
        while attempts < maxAttempts {
            if Task.isCancelled { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            let (targetText, hasEnd, hasStart, lastLine) = await MainActor.run {
                let lines = engine.outputLines
                var startIdx = 0
                if let lastId = lastLineIdAtStart, let idx = lines.lastIndex(where: { $0.id == lastId }) {
                    startIdx = idx
                }
                let subset = lines[startIdx...]
                let text = subset.map { $0.text }.joined(separator: "\n")
                return (text, text.contains(em), text.contains(sm), subset.last?.text.lowercased())
            }
            
            if hasEnd {
                try? await Task.sleep(nanoseconds: 50_000_000)
                
                let finalTargetText = await MainActor.run {
                     let lines = engine.outputLines
                     var startIdx = 0
                     if let lastId = lastLineIdAtStart, let idx = lines.lastIndex(where: { $0.id == lastId }) {
                         startIdx = idx
                     }
                     return lines[startIdx...].map { $0.text }.joined(separator: "\n")
                }
                
                capturedOutput = extract(finalTargetText, sm: sm, em: em)
                print("🔧 [SSHBase] ✅ Found end marker for: \(command.prefix(20))... Output lines: \(capturedOutput.components(separatedBy: .newlines).count)")
                break
            }
            
            // Diagnostics for timeout
            if attempts == maxAttempts - 1 {
                print("🔧 [SSHBase] ⚠️ Timeout warning for command: \(command.prefix(40))")
                print("🔧 [SSHBase] 🔍 Last line seen: \(lastLine ?? "nil")")
                print("🔧 [SSHBase] 🔍 Marker search (BGN/END): \(hasStart)/\(hasEnd)")
                // print("🔧 [SSHBase] 📄 Buffer chunk: \(targetText.suffix(200))")
            }

            // Proactive prompt detection
            if !hasStart, let lastLine = lastLine, lastLine.contains("password:") {
                print("🔧 [SSHBase] 🔐 Password prompt detected.")
                forceResetNextCommand = true
                return SSHCommandResult(command: command, output: "Error: sudo password required", exitCode: 1, executionTime: Date().timeIntervalSince(startTime))
            }
            
            attempts += 1
        }
        
        return SSHCommandResult(
            command: command, 
            output: capturedOutput, 
            exitCode: capturedOutput.isEmpty && attempts >= maxAttempts ? 1 : 0, 
            executionTime: Date().timeIntervalSince(startTime)
        )
    }
    
    private func extract(_ text: String, sm: String, em: String) -> String {
        guard let smRange = text.range(of: sm, options: .backwards) else { return "" }
        let afterStart = text[smRange.upperBound...]
        
        guard let emRange = afterStart.range(of: em) else { 
            return String(afterStart).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let content = String(afterStart[..<emRange.lowerBound])
        
        // Final cleaning
        let lines = content.components(separatedBy: .newlines)
        let cleanedLines = lines.filter { line in
            let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Ignore echoes of the markers or the command if silencing failed
            let isEcho = l.contains(sm) && l.starts(with: "echo '")
            return !l.isEmpty && !isEcho && !l.contains(em) && !l.starts(with: "echo '")
        }
        
        return cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
