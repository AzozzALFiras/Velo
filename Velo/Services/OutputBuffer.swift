//
//  OutputBuffer.swift
//  Velo
//
//  Created by Velo AI
//

import Foundation

// MARK: - Thread Safe Output Buffer
/// Handles ANSI parsing and line splitting on a background thread
final class OutputBuffer {
    private var lines: [OutputLine] = []
    private var pendingBuffer: String = ""
    private var lastLineIsPartial: Bool = false
    private let lock = NSLock()
    private let ansiParser = ANSIParser.shared
    
    private var lastFlushEndedPartial: Bool = false
    
    // Returns lines to add, and whether to replace the last existing line of the UI
    struct BufferUpdate {
        let lines: [OutputLine]
        let replaceLast: Bool
    }
    
    func append(_ text: String, isError: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        // Logic mirroring previous MainActor implementation, but thread-safe
        let fullText = pendingBuffer + text
        pendingBuffer = ""
        
        var current = ""
        
        for char in fullText {
            if char == "\n" {
                // Commit complete line
                let attributed = ansiParser.parse(current)
                lines.append(OutputLine(text: ansiParser.stripANSI(current), attributedText: attributed, isError: isError))
                current = ""
                lastLineIsPartial = false
            } else if char == "\r" {
                current = "" // Carriage return handling
            } else {
                current.append(char)
            }
        }
        
        // Handle remainder
        if !current.isEmpty {
            pendingBuffer = current
            let attributed = ansiParser.parse(current)
            lines.append(OutputLine(text: ansiParser.stripANSI(current), attributedText: attributed, isError: isError))
            lastLineIsPartial = true
        }
    }
    
    func flush() -> BufferUpdate {
        lock.lock()
        defer { lock.unlock() }
        
        let linesToFlush = lines
        lines.removeAll()
        
        // Determine overlap logic
        // If we flushed lines, and the LAST flush ended with a partial line,
        // and THIS flush has content, we say "replaceLast = true" (heuristically)
        let replace = lastFlushEndedPartial && !linesToFlush.isEmpty
        
        // Update state for next time
        // If pendingBuffer is non-empty, this flush IS sending a partial line at the end.
        lastFlushEndedPartial = !pendingBuffer.isEmpty
        
        return BufferUpdate(lines: linesToFlush, replaceLast: replace)
    }
    
    func clear() {
        lock.lock()
        lines.removeAll()
        pendingBuffer = ""
        lastLineIsPartial = false
        lastFlushEndedPartial = false
        lock.unlock()
    }
}
