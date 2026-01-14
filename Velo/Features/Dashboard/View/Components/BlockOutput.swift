//
//  BlockOutput.swift
//  Velo
//
//  Dashboard Redesign - Command Block Output Area
//  Scrollable output with smart collapsing and inline actions
//

import SwiftUI

// MARK: - Block Output

/// Scrollable output area for command blocks with smart collapsing
struct BlockOutput: View {
    
    let block: CommandBlock
    var onAskAI: ((String) -> Void)?
    var onOpenPath: ((String) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Output lines
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(block.visibleOutput) { line in
                    OutputLineView(
                        line: line,
                        onAskAI: onAskAI,
                        onOpenPath: onOpenPath
                    )
                }
            }
            
            // Collapse indicator
            if block.shouldShowCollapse {
                collapseIndicator
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    // MARK: - Collapse Indicator
    
    @ViewBuilder
    private var collapseIndicator: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                block.toggleCollapse()
            }
        } label: {
            HStack(spacing: 8) {
                // Gradient fade line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.layer1, ColorTokens.textTertiary.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                
                // Toggle text
                HStack(spacing: 4) {
                    Image(systemName: block.isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 9, weight: .semibold))
                    
                    Text(block.isCollapsed 
                         ? "Show \(block.outputLineCount - 5) more lines" 
                         : "Collapse")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(ColorTokens.textTertiary)
                
                // Gradient fade line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.textTertiary.opacity(0.3), ColorTokens.layer1],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Output Line View

/// Single line of output with potential inline actions
private struct OutputLineView: View {
    
    let line: OutputLine
    var onAskAI: ((String) -> Void)?
    var onOpenPath: ((String) -> Void)?
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Line content
            Text(line.attributedText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(line.isError ? ColorTokens.error : ColorTokens.textPrimary)
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Inline actions for error lines
            if line.isError && isHovered {
                errorActions
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(lineBackground)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
    
    // MARK: - Error Actions
    
    @ViewBuilder
    private var errorActions: some View {
        HStack(spacing: 4) {
            InlineActionButton(
                icon: "sparkles",
                label: "Explain",
                color: ColorTokens.accentSecondary
            ) {
                onAskAI?("Explain this error: \(line.text)")
            }
            
            InlineActionButton(
                icon: "wrench.and.screwdriver",
                label: "Fix",
                color: ColorTokens.accentPrimary
            ) {
                onAskAI?("How do I fix this error: \(line.text)")
            }
        }
    }
    
    // MARK: - Background
    
    private var lineBackground: some View {
        Group {
            if line.isError {
                ColorTokens.error.opacity(isHovered ? 0.12 : 0.06)
            } else if isHovered {
                ColorTokens.layer2.opacity(0.5)
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - Inline Action Button

/// Small inline action button for error lines
private struct InlineActionButton: View {
    
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - File Path Detector

/// Utility to detect and parse file paths in output lines
enum FilePathDetector {
    
    // Common path patterns
    private static let patterns: [NSRegularExpression] = {
        let patterns = [
            // Absolute paths: /Users/foo/bar.txt
            #"(/[^\s:]+\.[a-zA-Z]+)"#,
            // Relative paths with extension: ./foo/bar.txt, ../foo/bar.txt
            #"(\.{1,2}/[^\s:]+\.[a-zA-Z]+)"#,
            // Just filename.ext when preceded by "file" or "in"
            #"(?:file|in)\s+([^\s:]+\.[a-zA-Z]+)"#
        ]
        
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: []) }
    }()
    
    /// Extract file paths from a line of text
    static func extractPaths(from text: String) -> [String] {
        var results: [String] = []
        
        for pattern in patterns {
            let range = NSRange(text.startIndex..., in: text)
            let matches = pattern.matches(in: text, options: [], range: range)
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    results.append(String(text[range]))
                }
            }
        }
        
        return results
    }
}

// MARK: - Preview

#Preview("Block Output") {
    let block = CommandBlock(
        command: "npm install",
        output: [
            OutputLine(text: "npm WARN deprecated glob@7.2.0: Glob versions prior to v9 are deprecated"),
            OutputLine(text: "npm WARN deprecated inflight@1.0.6: This module is deprecated"),
            OutputLine(text: "npm ERR! code ENOENT", isError: true),
            OutputLine(text: "npm ERR! syscall open", isError: true),
            OutputLine(text: "npm ERR! path /Users/foo/package.json", isError: true),
            OutputLine(text: "added 150 packages in 3.2s"),
            OutputLine(text: "7 packages are looking for funding"),
            OutputLine(text: "  run `npm fund` for details"),
        ],
        status: .error
    )
    
    return BlockOutput(block: block) { query in
        print("Ask AI: \(query)")
    } onOpenPath: { path in
        print("Open: \(path)")
    }
    .frame(width: 600)
    .background(ColorTokens.layer0)
}
