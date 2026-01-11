//
//  TerminalWallView.swift
//  Velo
//
//  AI-Powered Terminal - Main Wall Interface
//

import SwiftUI

// MARK: - Terminal Wall View
/// The main terminal interface with a futuristic 3-column wall layout
struct TerminalWallView: View {
    @StateObject private var terminalVM = TerminalViewModel()
    @StateObject private var historyVM: HistoryViewModel
    @StateObject private var predictionVM: PredictionViewModel
    
    @State private var showHistorySidebar = true
    @State private var showInsightPanel = true
    @State private var sidebarWidth: CGFloat = 320
    @State private var insightPanelWidth: CGFloat = 280
    @State private var showSettings = false
    
    // Preferences
    @AppStorage("autoOpenHistory") private var autoOpenHistory = true
    @AppStorage("autoOpenAIPanel") private var autoOpenAIPanel = true
    
    init() {
        let terminalVM = TerminalViewModel()
        _terminalVM = StateObject(wrappedValue: terminalVM)
        _historyVM = StateObject(wrappedValue: HistoryViewModel(historyManager: terminalVM.historyManager))
        _predictionVM = StateObject(wrappedValue: PredictionViewModel(predictionEngine: terminalVM.predictionEngine))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left: Command History Wall
            if showHistorySidebar {
                HistoryWallView(
                    viewModel: historyVM,
                    onRunCommand: { command in
                        terminalVM.rerunCommand(command)
                    },
                    onEditCommand: { command in
                        terminalVM.editCommand(command)
                    }
                )
                .frame(width: sidebarWidth)
                .transition(.move(edge: .leading))
            }
            
            // Center: Main Terminal
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
                
                // Output area
                OutputStreamView(viewModel: terminalVM)
                
                // Input area
                InputAreaView(
                    viewModel: terminalVM,
                    predictionVM: predictionVM
                )
            }
            .frame(maxWidth: .infinity)
            
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
        .background(VeloDesign.Colors.deepSpace)
        .animation(VeloDesign.Animation.smooth, value: showHistorySidebar)
        .animation(VeloDesign.Animation.smooth, value: showInsightPanel)
        .sheet(isPresented: $showSettings) {
             SettingsView()
        }

        .onAppear {
            showHistorySidebar = autoOpenHistory
            showInsightPanel = autoOpenAIPanel
            setupKeyboardHandlers()
        }
    }
    
    private func setupKeyboardHandlers() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Handle keyboard shortcuts
            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                case 0x23: // ⌘K - Clear
                    terminalVM.clearScreen()
                    return nil
                case 0x0C: // ⌘Q handled by system
                    break
                default:
                    break
                }
            }
            
            // Handle Tab for autocomplete
            if event.keyCode == 0x30 && !event.modifierFlags.contains(.shift) {
                if predictionVM.inlinePrediction != nil {
                    terminalVM.acceptPrediction()
                    return nil
                }
            }
            
            // Handle Up/Down for history
            if !terminalVM.isExecuting {
                switch event.keyCode {
                case 0x7E: // Up arrow
                    if predictionVM.showingSuggestions {
                        predictionVM.moveSelectionUp()
                    } else {
                        terminalVM.navigateHistoryUp()
                    }
                    return nil
                case 0x7D: // Down arrow
                    if predictionVM.showingSuggestions {
                        predictionVM.moveSelectionDown()
                    } else {
                        terminalVM.navigateHistoryDown()
                    }
                    return nil
                default:
                    break
                }
            }
            
            // Ctrl+C to interrupt
            if event.modifierFlags.contains(.control) && event.keyCode == 0x08 {
                terminalVM.interrupt()
                return nil
            }
            
            return event
        }
    }
}

// MARK: - Terminal Toolbar
struct TerminalToolbar: View {
    let isExecuting: Bool
    let currentDirectory: String
    @Binding var showHistorySidebar: Bool
    @Binding var showInsightPanel: Bool
    @Binding var showSettings: Bool
    let onInterrupt: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        HStack(spacing: VeloDesign.Spacing.md) {
            // Sidebar toggles
            ToolbarButton(
                icon: "sidebar.left",
                isActive: showHistorySidebar,
                color: VeloDesign.Colors.neonCyan
            ) {
                showHistorySidebar.toggle()
            }
            
            Divider()
                .frame(height: 16)
            
            // App title
            HStack(spacing: VeloDesign.Spacing.sm) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 14))
                    .foregroundColor(VeloDesign.Colors.neonCyan)
                
                Text("Velo")
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
            }
            
            Spacer()
            
            // Current path
            Text(displayPath)
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(VeloDesign.Colors.textMuted)
                .lineLimit(1)
            
            Spacer()
            
            // Actions
            if isExecuting {
                ToolbarButton(
                    icon: "stop.fill",
                    isActive: true,
                    color: VeloDesign.Colors.error
                ) {
                    onInterrupt()
                }
            }
            
            ToolbarButton(
                icon: "trash",
                isActive: false,
                color: VeloDesign.Colors.textSecondary
            ) {
                onClear()
            }
            
            ToolbarButton(
                icon: "gearshape.fill",
                isActive: showSettings,
                color: VeloDesign.Colors.textSecondary
            ) {
                showSettings.toggle()
            }
            
            Divider()
                .frame(height: 16)
            
            ToolbarButton(
                icon: "sidebar.right",
                isActive: showInsightPanel,
                color: VeloDesign.Colors.neonPurple
            ) {
                showInsightPanel.toggle()
            }
        }
        .padding(.horizontal, VeloDesign.Spacing.lg)
        .padding(.vertical, VeloDesign.Spacing.sm)
        .background(VeloDesign.Colors.cardBackground)
        .overlay(
            Rectangle()
                .fill(VeloDesign.Colors.glassBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    var displayPath: String {
        let home = NSHomeDirectory()
        if currentDirectory.hasPrefix(home) {
            return "~" + currentDirectory.dropFirst(home.count)
        }
        return currentDirectory
    }
}

// MARK: - Toolbar Button
struct ToolbarButton: View {
    let icon: String
    let isActive: Bool
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isActive ? color : VeloDesign.Colors.textSecondary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill((isActive || isHovered) ? color.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}



// MARK: - Preview
#Preview {
    TerminalWallView()
        .frame(width: 1200, height: 700)
}
