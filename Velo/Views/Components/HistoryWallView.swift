//
//  HistoryWallView.swift
//  Velo
//
//  AI-Powered Terminal - Command Wall Sidebar
//

import SwiftUI

// MARK: - History Wall View
/// The command wall sidebar showing recent, frequent, and AI-suggested commands
struct HistoryWallView: View {
    @ObservedObject var viewModel: HistoryViewModel
    let onRunCommand: (CommandModel) -> Void
    let onEditCommand: (CommandModel) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            WallHeader(viewModel: viewModel)
            
            // Section tabs
            SectionTabs(selectedSection: $viewModel.selectedSection)
            
            // Search bar
            SearchBar(query: $viewModel.searchQuery)
            
            // Content
            ScrollView {
                LazyVStack(spacing: VeloDesign.Spacing.sm) {
                    ForEach(viewModel.displayedCommands) { command in
                        CommandCardView(
                            command: command,
                            onRun: { onRunCommand(command) },
                            onEdit: { onEditCommand(command) },
                            onExplain: { viewModel.explainCommand(command) }
                        )
                    }
                    
                    if viewModel.displayedCommands.isEmpty {
                        EmptyStateView(section: viewModel.selectedSection)
                    }
                }
                .padding(VeloDesign.Spacing.md)
            }
            
            // Stats footer
            StatsFooter(
                todayCount: viewModel.todayCommandCount,
                totalCount: viewModel.totalCommandCount
            )
        }
        .background(VeloDesign.Colors.darkSurface)
        .overlay(
            Rectangle()
                .fill(VeloDesign.Colors.glassBorder)
                .frame(width: 1),
            alignment: .trailing
        )
        .sheet(item: $viewModel.commandExplanation) { explanation in
            ExplanationSheet(explanation: explanation) {
                viewModel.clearExplanation()
            }
        }
    }
}

// MARK: - Wall Header
struct WallHeader: View {
    @ObservedObject var viewModel: HistoryViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Command Wall")
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                
                Text("Your command history")
                    .font(VeloDesign.Typography.caption)
                    .foregroundColor(VeloDesign.Colors.textMuted)
            }
            
            Spacer()
            
            // AI suggestions indicator
            PillTag(text: "AI", color: VeloDesign.Colors.neonPurple)
        }
        .padding(VeloDesign.Spacing.md)
    }
}

// MARK: - Section Tabs
struct SectionTabs: View {
    @Binding var selectedSection: HistorySection
    
    var body: some View {
        HStack(spacing: VeloDesign.Spacing.xs) {
            ForEach(HistorySection.allCases) { section in
                SectionTab(
                    section: section,
                    isSelected: selectedSection == section
                ) {
                    withAnimation(VeloDesign.Animation.quick) {
                        selectedSection = section
                    }
                }
            }
        }
        .padding(.horizontal, VeloDesign.Spacing.md)
        .padding(.bottom, VeloDesign.Spacing.sm)
    }
}

// MARK: - Section Tab
struct SectionTab: View {
    let section: HistorySection
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: VeloDesign.Spacing.xs) {
                Image(systemName: section.icon)
                    .font(.system(size: 10))
                Text(section.rawValue)
                    .font(VeloDesign.Typography.caption)
            }
            .foregroundColor(isSelected ? VeloDesign.Colors.neonCyan : VeloDesign.Colors.textSecondary)
            .padding(.horizontal, VeloDesign.Spacing.sm)
            .padding(.vertical, VeloDesign.Spacing.xs)
            .background(
                Capsule()
                    .fill(isSelected ? VeloDesign.Colors.neonCyan.opacity(0.15) : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? VeloDesign.Colors.neonCyan.opacity(0.3) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var query: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: VeloDesign.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(VeloDesign.Colors.textMuted)
            
            TextField("Search commands...", text: $query)
                .font(VeloDesign.Typography.monoSmall)
                .textFieldStyle(.plain)
                .focused($isFocused)
            
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(VeloDesign.Colors.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(VeloDesign.Spacing.sm)
        .background(VeloDesign.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VeloDesign.Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VeloDesign.Radius.small, style: .continuous)
                .stroke(isFocused ? VeloDesign.Colors.neonCyan.opacity(0.5) : VeloDesign.Colors.glassBorder, lineWidth: 1)
        )
        .padding(.horizontal, VeloDesign.Spacing.md)
        .padding(.bottom, VeloDesign.Spacing.sm)
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let section: HistorySection
    
    var body: some View {
        VStack(spacing: VeloDesign.Spacing.md) {
            Image(systemName: section.icon)
                .font(.system(size: 32))
                .foregroundColor(VeloDesign.Colors.textMuted)
            
            Text("No commands yet")
                .font(VeloDesign.Typography.subheadline)
                .foregroundColor(VeloDesign.Colors.textSecondary)
            
            Text("Start typing to build your command wall")
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VeloDesign.Spacing.xxl)
    }
}

// MARK: - Stats Footer
struct StatsFooter: View {
    let todayCount: Int
    let totalCount: Int
    
    var body: some View {
        HStack {
            StatBadge(icon: "calendar", value: "\(todayCount)", label: "today")
            Spacer()
            StatBadge(icon: "terminal", value: "\(totalCount)", label: "total")
        }
        .padding(VeloDesign.Spacing.md)
        .background(VeloDesign.Colors.cardBackground.opacity(0.5))
        .overlay(
            Rectangle()
                .fill(VeloDesign.Colors.glassBorder)
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: VeloDesign.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(VeloDesign.Colors.textMuted)
            
            Text(value)
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(VeloDesign.Colors.textPrimary)
            
            Text(label)
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.textMuted)
        }
    }
}

// MARK: - Explanation Sheet
struct ExplanationSheet: View {
    let explanation: CommandExplanation
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.lg) {
            // Header
            HStack {
                Text("Command Explanation")
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(VeloDesign.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            // Command
            Text(explanation.command)
                .font(VeloDesign.Typography.monoFont)
                .foregroundColor(VeloDesign.Colors.neonCyan)
                .padding(VeloDesign.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VeloDesign.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: VeloDesign.Radius.small))
            
            // Summary
            Text(explanation.summary)
                .font(VeloDesign.Typography.subheadline)
                .foregroundColor(VeloDesign.Colors.textSecondary)
            
            // Breakdown
            if !explanation.breakdown.isEmpty {
                VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                    Text("Breakdown")
                        .font(VeloDesign.Typography.caption)
                        .foregroundColor(VeloDesign.Colors.textMuted)
                    
                    ForEach(explanation.breakdown) { part in
                        HStack(spacing: VeloDesign.Spacing.sm) {
                            Text(part.token)
                                .font(VeloDesign.Typography.monoSmall)
                                .foregroundColor(Color(hex: part.type.color))
                            
                            Text(part.explanation)
                                .font(VeloDesign.Typography.caption)
                                .foregroundColor(VeloDesign.Colors.textSecondary)
                        }
                    }
                }
            }
            
            // Warnings
            if !explanation.warnings.isEmpty {
                VStack(alignment: .leading, spacing: VeloDesign.Spacing.xs) {
                    ForEach(explanation.warnings, id: \.self) { warning in
                        HStack(spacing: VeloDesign.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(VeloDesign.Colors.warning)
                                .font(.system(size: 10))
                            Text(warning)
                                .font(VeloDesign.Typography.caption)
                                .foregroundColor(VeloDesign.Colors.warning)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(VeloDesign.Spacing.lg)
        .frame(width: 400, height: 350)
        .background(VeloDesign.Colors.darkSurface)
    }
}

// CommandExplanation is already Identifiable in PredictionModel.swift

// MARK: - Preview
#Preview {
    let historyManager = CommandHistoryManager()
    let viewModel = HistoryViewModel(historyManager: historyManager)
    
    HistoryWallView(
        viewModel: viewModel,
        onRunCommand: { _ in },
        onEditCommand: { _ in }
    )
    .frame(width: 320, height: 600)
}
