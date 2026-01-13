//
//  InteractiveOutputLineView.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

// MARK: - Interactive Output Line View
/// Parses output lines to detect files and make them interactive
struct InteractiveOutputLineView: View {
    let line: OutputLine
    let searchQuery: String
    let currentDirectory: String
    let isInteractive: Bool
    let isDeepParsing: Bool
    let isSSHSession: Bool
    let sshConnectionString: String?
    let remoteWorkingDirectory: String?
    let onFileAction: (String) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: VeloDesign.Spacing.sm) {
            // Line indicator
            if line.isError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(VeloDesign.Colors.error)
            }
            
            // Interactive content
            InteractiveLineContent(
                text: line.text,
                attributedText: line.attributedText,
                isError: line.isError,
                currentDirectory: currentDirectory,
                isInteractive: isInteractive,
                isDeepParsing: isDeepParsing,
                isSSHSession: isSSHSession,
                sshConnectionString: sshConnectionString,
                remoteWorkingDirectory: remoteWorkingDirectory,
                onFileAction: onFileAction
            )
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, VeloDesign.Spacing.xs)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? VeloDesign.Colors.glassWhite : Color.clear)
        )
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Copy Line") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(line.text, forType: .string)
            }
        }
    }
}

// MARK: - Interactive Line Content
struct InteractiveLineContent: View {
    let text: String
    let attributedText: AttributedString
    let isError: Bool
    let currentDirectory: String
    let isInteractive: Bool
    let isDeepParsing: Bool
    let isSSHSession: Bool
    let sshConnectionString: String?
    let remoteWorkingDirectory: String?
    let onFileAction: (String) -> Void
    
    var isLikelyFilePath: Bool {
        // 1. Explicit paths
        if text.hasPrefix("/") || text.hasPrefix("~") || text.hasPrefix("./") || text.hasPrefix("../") { return true }
        
        // 2. Files with extensions (containing .)
        // Exclude colons (headers), urls, and very long lines
        if text.contains(".") && !text.contains(":") && !text.contains("http") && text.count < 150 {
            return true
        }
        
        // 3. Single words (could be directories or files without extension)
        // Check for spaces.
        if !text.contains(" ") && !text.contains(":") && text.count < 60 {
            return true
        }
        
        return false
    }
    
    // Is this a multi-column file list?
    var isMultiColumnFileList: Bool {
        // Must have multiple words
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard words.count > 1 else { return false }
        
        // Count how many look like explicit files (have extensions or slashes or specific chars)
        let fileLikeCount = words.filter { 
            ($0.contains(".") && !$0.hasSuffix(".")) || // Extension, ignore end-of-sentence dot
            $0.contains("/") ||
            $0.contains("_") || 
            $0.contains("-") ||
            // Also accept alphanumeric words that are clearly not English sentences if there are many of them
            ($0.rangeOfCharacter(from: .letters) != nil && $0.rangeOfCharacter(from: .decimalDigits) != nil)
        }.count
        
        // If we have many short words (like 'ls' output), it's likely a file list
        // LS output usually doesn't have "is", "the", "and" etc.
        let stopWords = ["the", "is", "at", "on", "in", "of", "and", "to", "a", "error", "warning", "failed"]
        let hasStopWords = words.contains { stopWords.contains($0.lowercased()) }
        if hasStopWords { return false }
        
        // If more than 25% look like files, or we have > 3 items and no stop words
        if Double(fileLikeCount) / Double(words.count) > 0.25 { return true }
        
        // Fallback: if we have > 2 items, no stop words, and avg length is small (file names)
        if words.count > 2 {
            let avgLength = Double(words.reduce(0) { $0 + $1.count }) / Double(words.count)
            if avgLength < 20 { return true }
        }
        
        return false
    }

    var body: some View {
        // Simple logic for now: check if it looks like a key-value pair or file
        if text.contains(":") && !text.contains("http") && !text.contains("://") && text.count < 100 {
            KeyValueLineView(text: text)
        } else if isDeepParsing && isMultiColumnFileList {
            if isInteractive {
                TokenizedFileListView(
                    text: text,
                    currentDirectory: currentDirectory,
                    isSSHSession: isSSHSession,
                    sshConnectionString: sshConnectionString,
                    remoteWorkingDirectory: remoteWorkingDirectory,
                    onFileAction: onFileAction
                )
            } else {
                Text(text)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
            }
        } else if isDeepParsing && isLikelyFilePath {
            // Likely a file path
            if isInteractive {
                FilePathLineView(
                    path: text,
                    currentDirectory: currentDirectory,
                    isSSHSession: isSSHSession,
                    sshConnectionString: sshConnectionString,
                    remoteWorkingDirectory: remoteWorkingDirectory,
                    onFileAction: onFileAction
                )
            } else {
                // Non-interactive path
                Text(text)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
            }
        } else {
            // Standard text (or ANSI parsed)
            HStack(alignment: .top, spacing: 8) {
                Text(attributedText)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(isError ? VeloDesign.Colors.error : VeloDesign.Colors.textPrimary)
                    .lineLimit(nil)
                    .textSelection(.enabled)
                
                if isError {
                    Button(action: {
                        NotificationCenter.default.post(
                            name: .askAI,
                            object: nil,
                            userInfo: ["query": "Explain this error: \(text)"]
                        )
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("Ask AI")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(VeloDesign.Colors.neonPurple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VeloDesign.Colors.neonPurple.opacity(0.1))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(VeloDesign.Colors.neonPurple.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Key Value Line View
struct KeyValueLineView: View {
    let text: String
    
    var body: some View {
        let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            HStack(spacing: 4) {
                Text(parts[0] + ":")
                    .font(VeloDesign.Typography.monoSmall.weight(.medium))
                    .foregroundColor(VeloDesign.Colors.neonCyan)
                
                Text(parts[1])
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textSecondary)
            }
        } else {
            Text(text)
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(VeloDesign.Colors.textPrimary)
        }
    }
}

// MARK: - Tokenized File List View
struct TokenizedFileListView: View {
    let text: String
    let currentDirectory: String
    let isSSHSession: Bool
    let sshConnectionString: String?
    let remoteWorkingDirectory: String?
    let onFileAction: (String) -> Void
    
    // Split by spaces but preserve structure for render
    // actually, to keep alignment, we'll try to find word ranges
    
    var body: some View {
        HStack(spacing: 0) {
            // Use regex to parse words and whitespace to preserve exact layout
            let tokens = parseLine(text)
            
            ForEach(tokens) { token in
                if token.isWhitespace {
                    Text(token.text)
                        .font(VeloDesign.Typography.monoSmall)
                        .fixedSize(horizontal: true, vertical: false)
                } else {
                    // It's a "word" - interact with it
                    InteractiveFileView(
                        filename: token.text,
                        currentDirectory: currentDirectory,
                        onAction: onFileAction,
                        isSSHSession: isSSHSession,
                        sshConnectionString: sshConnectionString,
                        remoteWorkingDirectory: remoteWorkingDirectory,
                        style: .inline
                    )
                }
            }
        }
    }
    
    struct Token: Identifiable {
        let id = UUID()
        let text: String
        let isWhitespace: Bool
    }
    
    private func parseLine(_ line: String) -> [Token] {
        var tokens: [Token] = []
        let scanner = Scanner(string: line)
        scanner.charactersToBeSkipped = nil
        
        while !scanner.isAtEnd {
            // Scanner cannot easily split by regex while keeping delimiters in Swift < 5.7 conveniently
            // So we manually iterate
            // But for simplicity, let's use a simpler approach:
            
            // Find next whitespace
            if let whitespace = scanner.scanCharacters(from: .whitespaces) {
                tokens.append(Token(text: whitespace, isWhitespace: true))
            } else if let word = scanner.scanUpToCharacters(from: .whitespaces) {
                tokens.append(Token(text: word, isWhitespace: false))
            } else {
                // Should not happen if not at end
                _ = scanner.scanCharacter()
            }
        }
        return tokens
    }
    
    }


// MARK: - File Path Line View
struct FilePathLineView: View {
    let path: String
    let currentDirectory: String
    let isSSHSession: Bool
    let sshConnectionString: String?
    let remoteWorkingDirectory: String?
    let onFileAction: (String) -> Void
    
    var body: some View {
        InteractiveFileView(
            filename: path,
            currentDirectory: currentDirectory,
            onAction: onFileAction,
            isSSHSession: isSSHSession,
            sshConnectionString: sshConnectionString,
            remoteWorkingDirectory: remoteWorkingDirectory
        )
    }
}


