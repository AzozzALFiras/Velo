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



