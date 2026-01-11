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

