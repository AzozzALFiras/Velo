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

    var body: some View {
        // Simple logic for now: check if it looks like a key-value pair or file
        if text.contains(":") && !text.contains("http") && !text.contains("://") && text.count < 100 {
            KeyValueLineView(text: text)
        } else if isDeepParsing && isLikelyFilePath {
            // Likely a file path
            if isInteractive {
                FilePathLineView(
                    path: text, 
                    currentDirectory: currentDirectory, 
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
            Text(attributedText)
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(isError ? VeloDesign.Colors.error : VeloDesign.Colors.textPrimary)
                .lineLimit(nil)
                .textSelection(.enabled)
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

// MARK: - File Path Line View
struct FilePathLineView: View {
    let path: String
    let currentDirectory: String
    let onFileAction: (String) -> Void
    
    var body: some View {
        InteractiveFileView(
            filename: path,
            currentDirectory: currentDirectory,
            onAction: onFileAction
        )
    }
}
