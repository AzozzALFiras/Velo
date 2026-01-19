//
//  OutputBuffer.swift
//  Velo
//
//  Enhanced Thread Safe Output Buffer
//  Optimized for smooth line-by-line streaming
//

import Foundation

// MARK: - Thread Safe Output Buffer
/// Handles ANSI parsing and line splitting on a background thread
/// Optimized for streaming output (downloads, builds, logs)
final class OutputBuffer {
    private var lines: [OutputLine] = []
    private var pendingBuffer: String = ""
    private var lastLineIsPartial: Bool = false
    private let lock = NSLock()
    private let ansiParser = ANSIParser.shared

    private var lastFlushEndedPartial: Bool = false

    // Streaming optimization
    private var lineCount: Int = 0
    private var hasNewContent: Bool = false

    // Returns lines to add, and whether to replace the last existing line of the UI
    struct BufferUpdate {
        let lines: [OutputLine]
        let replaceLast: Bool
        let hasNewContent: Bool
        let totalLineCount: Int
    }

    /// Append text to the buffer with streaming-optimized line handling
    func append(_ text: String, isError: Bool) {
        lock.lock()
        defer { lock.unlock() }

        hasNewContent = true

        // Combine with pending buffer
        let fullText = pendingBuffer + text
        pendingBuffer = ""

        var current = ""
        var hasCarriageReturn = false

        for char in fullText {
            if char == "\n" {
                // Commit complete line
                commitLine(current, isError: isError, replacePartial: hasCarriageReturn && lastLineIsPartial)
                current = ""
                lastLineIsPartial = false
                hasCarriageReturn = false
            } else if char == "\r" {
                // Carriage return - handle progress updates (like wget, curl)
                // This allows the same line to be updated in place
                if !current.isEmpty {
                    commitLine(current, isError: isError, replacePartial: true)
                    current = ""
                }
                hasCarriageReturn = true
            } else {
                current.append(char)
            }
        }

        // Handle remainder (partial line)
        if !current.isEmpty {
            pendingBuffer = current

            // For streaming, we still want to show partial lines
            let attributed = ansiParser.parse(current)
            let stripped = ansiParser.stripANSI(current)

            // Replace last partial line if we had one
            if lastLineIsPartial && !lines.isEmpty {
                lines.removeLast()
            }

            lines.append(OutputLine(text: stripped, attributedText: attributed, isError: isError))
            lastLineIsPartial = true
        }
    }

    private func commitLine(_ text: String, isError: Bool, replacePartial: Bool) {
        let attributed = ansiParser.parse(text)
        let stripped = ansiParser.stripANSI(text)

        // If we should replace the last partial line
        if replacePartial && lastLineIsPartial && !lines.isEmpty {
            lines.removeLast()
        }

        lines.append(OutputLine(text: stripped, attributedText: attributed, isError: isError))
        lineCount += 1
        lastLineIsPartial = false
    }

    /// Flush the buffer and return lines for UI update
    func flush() -> BufferUpdate {
        lock.lock()
        defer { lock.unlock() }

        let linesToFlush = lines
        lines.removeAll(keepingCapacity: true)

        // Determine if we should replace the last UI line
        let replace = lastFlushEndedPartial && !linesToFlush.isEmpty

        // Update state for next flush
        lastFlushEndedPartial = lastLineIsPartial

        // Reset content flag
        let hadNewContent = hasNewContent
        hasNewContent = false

        return BufferUpdate(
            lines: linesToFlush,
            replaceLast: replace,
            hasNewContent: hadNewContent,
            totalLineCount: lineCount
        )
    }

    /// Check if there's pending content without flushing
    func hasPendingContent() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !lines.isEmpty || !pendingBuffer.isEmpty
    }

    /// Get the current line count
    func getLineCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return lineCount
    }

    /// Clear all buffer state
    func clear() {
        lock.lock()
        lines.removeAll()
        pendingBuffer = ""
        lastLineIsPartial = false
        lastFlushEndedPartial = false
        lineCount = 0
        hasNewContent = false
        lock.unlock()
    }

    /// Force flush any pending partial line
    func forceFlushPending() -> OutputLine? {
        lock.lock()
        defer { lock.unlock() }

        guard !pendingBuffer.isEmpty else { return nil }

        let attributed = ansiParser.parse(pendingBuffer)
        let stripped = ansiParser.stripANSI(pendingBuffer)
        let line = OutputLine(text: stripped, attributedText: attributed, isError: false)

        pendingBuffer = ""
        lastLineIsPartial = false

        return line
    }
}
