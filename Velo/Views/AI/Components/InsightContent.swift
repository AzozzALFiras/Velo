//
//  InsightContent.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

// MARK: - Suggestions Content
struct SuggestionsContent: View {
    @ObservedObject var viewModel: TerminalViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
            // Quick actions
            InsightSection(title: "Quick Actions") {
                VStack(spacing: VeloDesign.Spacing.sm) {
                    QuickActionCard(
                        icon: "arrow.clockwise",
                        title: "Repeat Last",
                        subtitle: "Run previous command again",
                        color: VeloDesign.Colors.info
                    ) {
                        if let last = viewModel.historyManager.recentCommands.first {
                            viewModel.rerunCommand(last)
                        }
                    }
                    
                    QuickActionCard(
                        icon: "trash",
                        title: "Clear Screen",
                        subtitle: "Clear all output",
                        color: VeloDesign.Colors.warning
                    ) {
                        viewModel.clearScreen()
                    }
                }
            }
            
            // AI Recommendations
            InsightSection(title: "Recommended") {
                if viewModel.predictionEngine.suggestions.isEmpty {
                    EmptyInsightView(message: "Start typing to get suggestions")
                } else {
                    VStack(spacing: VeloDesign.Spacing.xs) {
                        ForEach(viewModel.predictionEngine.suggestions.prefix(5)) { suggestion in
                            RecommendationRow(
                                suggestion: suggestion,
                                onSelect: { viewModel.acceptSuggestion(suggestion) }
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Context Content
struct ContextContent: View {
    @ObservedObject var viewModel: TerminalViewModel
    @ObservedObject var historyViewModel: HistoryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
            // Current context
            InsightSection(title: "Current Context") {
                VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                    ContextRow(
                        icon: "folder",
                        label: "Directory",
                        value: (viewModel.currentDirectory as NSString).lastPathComponent
                    )
                    
                    ContextRow(
                        icon: "terminal",
                        label: "Commands Today",
                        value: "\(historyViewModel.todayCommandCount)"
                    )
                    
                    ContextRow(
                        icon: "checkmark.circle",
                        label: "Last Exit Code", 
                        value: "\(viewModel.lastExitCode)"
                    )
                }
            }
            
            // Active patterns
            InsightSection(title: "Active Patterns") {
                VStack(spacing: VeloDesign.Spacing.xs) {
                    PatternRow(pattern: "git workflow", frequency: 15)
                    PatternRow(pattern: "npm development", frequency: 8)
                    PatternRow(pattern: "file operations", frequency: 5)
                }
            }
        }
    }
}

// MARK: - Learn Content
struct LearnContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
            InsightSection(title: "Tips & Tricks") {
                VStack(spacing: VeloDesign.Spacing.sm) {
                    TipCard(
                        emoji: "⌨️",
                        title: "Keyboard Shortcuts",
                        description: "Press ↑/↓ to navigate history"
                    )
                    
                    TipCard(
                        emoji: "⇥",
                        title: "Tab Completion",
                        description: "Press Tab to accept predictions"
                    )
                    
                    TipCard(
                        emoji: "🔍",
                        title: "Smart Search",
                        description: "Use ⌘F to search output"
                    )
                }
            }
            
            InsightSection(title: "Did You Know?") {
                Text("Velo learns from your command patterns to provide smarter suggestions over time.")
                    .font(VeloDesign.Typography.caption)
                    .foregroundColor(VeloDesign.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Supporting Views
struct InsightSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
            Text(title)
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.textMuted)
                .textCase(.uppercase)
            
            content()
        }
    }
}

struct EmptyInsightView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(VeloDesign.Typography.caption)
            .foregroundColor(VeloDesign.Colors.textMuted)
            .frame(maxWidth: .infinity)
            .padding(VeloDesign.Spacing.lg)
    }
}
