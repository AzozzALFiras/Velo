//
//  TerminalTabContent.swift
//  Velo
//
//  AI-Powered Terminal - Single Tab Content
//
//

import SwiftUI

// MARK: - Terminal Tab Content
/// The main content area for a single terminal tab
struct TerminalTabContent: View {
    @ObservedObject var terminalVM: TerminalViewModel
    @ObservedObject var historyVM: HistoryViewModel
    @ObservedObject var predictionVM: PredictionViewModel
    
    @Binding var showHistorySidebar: Bool
    @Binding var showInsightPanel: Bool
    @Binding var showSettings: Bool
    @Binding var insightPanelWidth: CGFloat
    
    var body: some View {
        HStack(spacing: 0) {
            // Main Terminal Area
            VStack(spacing: 0) {
                // Terminal toolbar
                TerminalToolbar(
                    isExecuting: terminalVM.isExecuting,
                    currentDirectory: terminalVM.currentDirectory,
                    showHistorySidebar: $showHistorySidebar,
                    showInsightPanel: $showInsightPanel,
                    showSettings: $showSettings,
                    onInterrupt: terminalVM.interrupt,
                    onClear: terminalVM.clearScreen
                )
                
                ZStack(alignment: .bottom) {
                    // Output Stream logic
                    // We need to pass the VM to OutputStreamView
                    OutputStreamView(viewModel: terminalVM)
                        .padding(.top, 1) // Separator line
                    
                    // Input Area overlay (floating at bottom)
                    InputAreaView(
                        viewModel: terminalVM,
                        predictionVM: predictionVM
                    )
                    .padding(.horizontal, VeloDesign.Spacing.md)
                    .padding(.bottom, VeloDesign.Spacing.md)
                }
            }
            
            // Right: AI Insight Panel
            if showInsightPanel {
                AIInsightPanel(
                    viewModel: terminalVM,
                    historyViewModel: historyVM
                )
                .frame(width: insightPanelWidth)
                .transition(.move(edge: .trailing))
            }
        }
        }
    }

