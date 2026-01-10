//
//  AIInsightPanel.swift
//  Velo
//
//  AI-Powered Terminal - AI Intelligence Sidebar
//

import SwiftUI

// MARK: - AI Insight Panel
/// Right sidebar with AI-powered insights and suggestions
struct AIInsightPanel: View {
    @ObservedObject var viewModel: TerminalViewModel
    @ObservedObject var historyViewModel: HistoryViewModel
    
    @State private var selectedInsightTab: InsightTab = .suggestions
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            InsightHeader()
            
            // Tab selector
            InsightTabSelector(selectedTab: $selectedInsightTab)
            
            // Content
            ScrollView {
                VStack(spacing: VeloDesign.Spacing.md) {
                    switch selectedInsightTab {
                    case .suggestions:
                        SuggestionsContent(viewModel: viewModel)
                    case .context:
                        ContextContent(viewModel: viewModel, historyViewModel: historyViewModel)
                    case .learn:
                        LearnContent()
                    }
                }
                .padding(VeloDesign.Spacing.md)
            }
        }
        .background(VeloDesign.Colors.darkSurface)
        .overlay(
            Rectangle()
                .fill(VeloDesign.Colors.glassBorder)
                .frame(width: 1),
            alignment: .leading
        )
    }
}

// MARK: - Insight Header
struct InsightHeader: View {
    var body: some View {
        HStack {
            HStack(spacing: VeloDesign.Spacing.sm) {
                Image(systemName: "brain")
                    .font(.system(size: 14))
                    .foregroundColor(VeloDesign.Colors.neonPurple)
                    .glow(VeloDesign.Colors.neonPurple, radius: 8)
                
                Text("AI Insights")
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
            }
            
            Spacer()
            
            // Status indicator
            CapabilityBadge()
        }
        .padding(VeloDesign.Spacing.md)
    }
}

// MARK: - Capability Badge
struct CapabilityBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(VeloDesign.Colors.neonGreen)
                .frame(width: 6, height: 6)
            Text("Active")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(VeloDesign.Colors.neonGreen)
        }
        .padding(.horizontal, VeloDesign.Spacing.sm)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(VeloDesign.Colors.neonGreen.opacity(0.1))
        )
    }
}

// MARK: - Insight Tab Selector
struct InsightTabSelector: View {
    @Binding var selectedTab: InsightTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(InsightTab.allCases) { tab in
                InsightTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(VeloDesign.Animation.quick) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, VeloDesign.Spacing.md)
        .padding(.bottom, VeloDesign.Spacing.sm)
    }
}

// MARK: - Insight Tab Button
struct InsightTabButton: View {
    let tab: InsightTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                Text(tab.rawValue)
                    .font(.system(size: 10))
            }
            .foregroundColor(isSelected ? VeloDesign.Colors.neonPurple : VeloDesign.Colors.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, VeloDesign.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VeloDesign.Radius.small)
                    .fill(isSelected ? VeloDesign.Colors.neonPurple.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Insight Tab
enum InsightTab: String, CaseIterable, Identifiable {
    case suggestions = "Suggest"
    case context = "Context"
    case learn = "Learn"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .suggestions: return "lightbulb"
        case .context: return "scope"
        case .learn: return "book"
        }
    }
}

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

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: VeloDesign.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VeloDesign.Typography.caption)
                        .foregroundColor(VeloDesign.Colors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(VeloDesign.Colors.textMuted)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(VeloDesign.Colors.textMuted)
            }
            .padding(VeloDesign.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VeloDesign.Radius.small)
                    .fill(isHovered ? VeloDesign.Colors.elevatedSurface : VeloDesign.Colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct RecommendationRow: View {
    let suggestion: CommandSuggestion
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: VeloDesign.Spacing.sm) {
                Image(systemName: suggestion.source.icon)
                    .font(.system(size: 10))
                    .foregroundColor(VeloDesign.Colors.neonPurple)
                
                Text(suggestion.command)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, VeloDesign.Spacing.sm)
            .padding(.vertical, VeloDesign.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: VeloDesign.Radius.small)
                    .fill(isHovered ? VeloDesign.Colors.elevatedSurface : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ContextRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(VeloDesign.Colors.textMuted)
                .frame(width: 16)
            
            Text(label)
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(VeloDesign.Colors.textPrimary)
        }
    }
}

struct PatternRow: View {
    let pattern: String
    let frequency: Int
    
    var body: some View {
        HStack {
            Text(pattern)
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.textPrimary)
            
            Spacer()
            
            Text("\(frequency)×")
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(VeloDesign.Colors.neonPurple)
        }
        .padding(.vertical, 2)
    }
}

struct TipCard: View {
    let emoji: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: VeloDesign.Spacing.sm) {
            Text(emoji)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VeloDesign.Typography.caption)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(VeloDesign.Colors.textMuted)
            }
        }
        .padding(VeloDesign.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VeloDesign.Radius.small)
                .fill(VeloDesign.Colors.cardBackground)
        )
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
