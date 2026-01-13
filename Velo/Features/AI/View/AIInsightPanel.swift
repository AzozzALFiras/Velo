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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            InsightHeader()
            
            // Tab selector
            InsightTabSelector(selectedTab: $viewModel.activeInsightTab)
            
            // Content
            if viewModel.activeInsightTab == .chat {
                ChatContent(service: viewModel.aiService, terminalVM: viewModel)
                    .padding(VeloDesign.Spacing.md)
            } else {
                ScrollView {
                    VStack(spacing: VeloDesign.Spacing.md) {
                        switch viewModel.activeInsightTab {
                        case .suggestions:
                            SuggestionsContent(viewModel: viewModel)
                        case .context:
                            ContextContent(viewModel: viewModel, historyViewModel: historyViewModel)
                        case .chat:
                            EmptyView() // Handled above
                        }
                    }
                    .padding(VeloDesign.Spacing.md)
                }
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



