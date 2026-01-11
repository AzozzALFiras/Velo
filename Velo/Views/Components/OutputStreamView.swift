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
    
    // Preferences
    @AppStorage("isInteractiveOutputEnabled") private var isInteractiveOutputEnabled = true
    @AppStorage("isDeepFileParsingEnabled") private var isDeepFileParsingEnabled = true
    
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
                                isInteractive: isInteractiveOutputEnabled,
                                isDeepParsing: isDeepFileParsingEnabled,
                                onFileAction: { viewModel.executeFileAction($0) }
                            )
                            .id(line.id)
                        }
                        
                        // Bottom anchor & Input Area padding
                        // Extra space so the last line isn't covered by the floating input bar
                        Color.clear
                            .frame(height: 120)
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
