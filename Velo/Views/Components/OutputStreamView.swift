//
//  OutputStreamView.swift
//  Velo
//
//  AI-Powered Terminal - Real-time Output Display
//

import SwiftUI

// MARK: - Output Stream View
/// Displays terminal output with ANSI colors and auto-scroll
struct OutputStreamView: View {
    @ObservedObject var viewModel: TerminalViewModel
    @State private var autoScroll = true
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var hoveredLineId: UUID?
    
    var filteredLines: [OutputLine] {
        if searchQuery.isEmpty {
            return viewModel.outputLines
        }
        return viewModel.outputLines.filter { $0.text.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // New Command Block Header
            CommandBlockHeader(
                activeCommand: viewModel.activeCommand, 
                isExecuting: viewModel.isExecuting, 
                startTime: viewModel.commandStartTime, 
                currentDirectory: viewModel.currentDirectory,
                onInterrupt: { viewModel.interrupt() },
                onRerun: {
                    let cmd = CommandModel(
                        command: viewModel.activeCommand, 
                        output: "", 
                        exitCode: 0, 
                        workingDirectory: viewModel.currentDirectory, 
                        context: .general
                    )
                    viewModel.rerunCommand(cmd)
                },
                onClear: { viewModel.clearScreen() },
                onCopy: {
                    let output = viewModel.outputLines.map { $0.text }.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                }
            )
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredLines) { line in
                            InteractiveOutputLineView(
                                line: line,
                                searchQuery: searchQuery,
                                currentDirectory: viewModel.currentDirectory,
                                onFileAction: { viewModel.executeFileAction($0) }
                            )
                            .id(line.id)
                        }
                        
                        // Bottom anchor
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, VeloDesign.Spacing.md)
                    .padding(.vertical, VeloDesign.Spacing.sm)
                }
                .onChange(of: viewModel.outputLines.count) { _ in
                    if autoScroll {
                        // Instant scroll for performance
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.outputLines.last?.id) { _ in
                     if autoScroll {
                         proxy.scrollTo("bottom", anchor: .bottom)
                     }
                }
            }
        }
        .background(VeloDesign.Colors.cardBackground)
        .overlay(
            Group {
                if isSearching {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(filteredLines.count) matches")
                                .font(VeloDesign.Typography.caption)
                                .foregroundColor(VeloDesign.Colors.textPrimary)
                                .padding(4)
                                .background(VeloDesign.Colors.elevatedSurface)
                                .cornerRadius(4)
                        }
                        .padding()
                    }
                }
            }
        )
    }
}

// MARK: - Interactive Output Line View
/// Parses output lines to detect files and make them interactive
// MARK: - Interactive Output Line View
/// Parses output lines to detect files and make them interactive
struct InteractiveOutputLineView: View {
    let line: OutputLine
    let searchQuery: String
    let currentDirectory: String
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
    let onFileAction: (String) -> Void
    
    var body: some View {
        // Simple logic for now: check if it looks like a key-value pair or file
        if text.contains(":") && !text.contains("http") && !text.contains("://") && text.count < 100 {
            KeyValueLineView(text: text)
        } else if (text.hasPrefix("/") || text.hasPrefix("~") || text.hasPrefix(".")) && !text.contains(" ") {
            // Likely a file path
            FilePathLineView(
                path: text, 
                currentDirectory: currentDirectory, 
                onFileAction: onFileAction
            )
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
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            // Show action menu or default action
            // For now, simpler interaction: just copy or select
        }) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.caption2)
                Text(path)
                    .font(VeloDesign.Typography.monoSmall)
                    .underline(isHovered)
            }
            .foregroundColor(VeloDesign.Colors.neonPurple)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        // Use the InteractiveFileView logic if we can, but I'll simplify here since I lost the complex logic
        .overlay(
            InteractiveFileView(
                filename: path,
                currentDirectory: currentDirectory,
                onAction: onFileAction
            )
            .opacity(0.01) // Invisible trigger area overlay if needed, or just use button
        )
    }
}
