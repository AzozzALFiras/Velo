//
//  TerminalWallView.swift
//  Velo
//
//  AI-Powered Terminal - Main Wall Interface
//

import SwiftUI

// MARK: - Terminal Wall View
/// The main terminal interface with a futuristic 3-column wall layout (Tabbed)
struct TerminalWallView: View {
    // Shared State Management
    @StateObject private var historyManager = CommandHistoryManager()
    @StateObject private var tabManager: TabManager
    
    // ViewModels for non-session specific panels
    @StateObject private var historyVM: HistoryViewModel
    @StateObject private var predictionVM: PredictionViewModel
    
    // UI State
    @State private var showHistorySidebar = true
    @State private var showInsightPanel = true
    @State private var sidebarWidth: CGFloat = 320
    @State private var insightPanelWidth: CGFloat = 280
    @State private var showSettings = false
    
    // Preferences
    @AppStorage("autoOpenHistory") private var autoOpenHistory = true
    @AppStorage("autoOpenAIPanel") private var autoOpenAIPanel = true
    
    init() {
        let history = CommandHistoryManager()
        let tabs = TabManager(historyManager: history)
        
        _historyManager = StateObject(wrappedValue: history)
        _tabManager = StateObject(wrappedValue: tabs)
        
        _historyVM = StateObject(wrappedValue: HistoryViewModel(historyManager: history))
        // Note: Prediction might belong to individual tabs contextually, 
        // but for now we can share the engine or re-instantiate.
        // Let's assume shared prediction logic based on history.
        _predictionVM = StateObject(wrappedValue: PredictionViewModel(predictionEngine: PredictionEngine(historyManager: history)))
    }
    
    // Update State
    @State private var requiredUpdate: VeloUpdateInfo? = nil
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Left: Command History Wall (Shared across tabs)
                if showHistorySidebar {
                    HistoryWallView(
                        viewModel: historyVM,
                        onRunCommand: { command in
                            tabManager.activeSession?.rerunCommand(command)
                        },
                        onEditCommand: { command in
                            tabManager.activeSession?.editCommand(command)
                        }
                    )
                    .frame(width: sidebarWidth)
                    .transition(.move(edge: .leading))
                }
                
                // Center: Tabbed Interface
                VStack(spacing: 0) {
                    // Tab Bar
                    TabBarView(tabManager: tabManager, showSettings: $showSettings)
                    
                    // Active Tab Content
                    if let session = tabManager.activeSession {
                        TerminalTabContent(
                            terminalVM: session,
                            historyVM: historyVM,
                            predictionVM: predictionVM,
                            showHistorySidebar: $showHistorySidebar,
                            showInsightPanel: $showInsightPanel,
                            showSettings: $showSettings,
                            insightPanelWidth: $insightPanelWidth
                        )
                        .id(session.id) // Ensure complete view rebuild on tab switch to avoid state pollution
                    } else {
                        // Empty state (shouldn't happen with default tab)
                        Text("No Active Session")
                            .foregroundColor(VeloDesign.Colors.textMuted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(VeloDesign.Colors.deepSpace)
            .overlay(
                Group {
                    if showSettings {
                        ZStack {
                            Color.black.opacity(0.6)
                                .ignoresSafeArea()
                                .onTapGesture { showSettings = false }
                            
                            SettingsView(onClose: {
                                withAnimation(VeloDesign.Animation.smooth) {
                                    showSettings = false
                                }
                            })
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                        }
                    }
                }
            )
            
            // Required Update Overlay
            if let update = requiredUpdate {
                ZStack {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                    
                    VStack(spacing: VeloDesign.Spacing.lg) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(VeloDesign.Colors.neonCyan)
                            .shadow(color: VeloDesign.Colors.neonCyan.opacity(0.5), radius: 20)
                        
                        VStack(spacing: 8) {
                            Text("Update Required")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("A new version (v\(update.latestVersion)) of Velo is required to continue using the services.")
                                .font(VeloDesign.Typography.subheadline)
                                .foregroundColor(VeloDesign.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Release Notes:")
                                .font(VeloDesign.Typography.monoSmall)
                                .foregroundColor(VeloDesign.Colors.neonPurple)
                            
                            Text(update.releaseNotes)
                                .font(VeloDesign.Typography.caption)
                                .foregroundColor(VeloDesign.Colors.textPrimary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(VeloDesign.Colors.cardBackground)
                                .cornerRadius(10)
                        }
                        .frame(width: 400)
                        
                        Link(destination: URL(string: update.pageUpdate) ?? URL(string: "https://velo.3zozz.com")!) {
                            Text("Update Velo Now")
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 15)
                                .background(VeloDesign.Colors.neonCyan)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .padding(.top)
                    }
                    .padding(40)
                    .glassCard()
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(VeloDesign.Animation.smooth, value: showHistorySidebar)
        .animation(VeloDesign.Animation.smooth, value: showInsightPanel)
        .animation(VeloDesign.Animation.smooth, value: requiredUpdate != nil)
        // The sheet modifier is replaced by the overlay in the provided snippet.
        // .sheet(isPresented: $showSettings) {
        //      SettingsView()
        // }

        .onAppear {
            showHistorySidebar = autoOpenHistory
            showInsightPanel = autoOpenAIPanel
            setupKeyboardHandlers()
        }
        .onReceive(NotificationCenter.default.publisher(for: .askAI)) { notification in
            // 1. Ensure panel is visible
            if !showInsightPanel {
                withAnimation(VeloDesign.Animation.smooth) {
                    showInsightPanel = true
                }
            }
            
            // 2. Extract query and dispatch to active session
            if let query = notification.userInfo?["query"] as? String {
                Task {
                    // Give recursion/animation a moment to settle
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    tabManager.activeSession?.askAI(query: query)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requiredUpdateDetected)) { notification in
            if let update = notification.object as? VeloUpdateInfo {
                withAnimation(.spring()) {
                    requiredUpdate = update
                }
            }
        }
    }
    
    private func setupKeyboardHandlers() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Handle keyboard shortcuts
            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                case 0x23: // ⌘K - Clear
                    tabManager.activeSession?.clearScreen()
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
                    tabManager.activeSession?.acceptPrediction()
                    return nil
                }
            }
            
            // Handle Up/Down for history
            if let session = tabManager.activeSession, !session.isExecuting {
                switch event.keyCode {
                case 0x7E: // Up arrow
                    if predictionVM.showingSuggestions {
                        predictionVM.moveSelectionUp()
                    } else {
                        session.navigateHistoryUp()
                    }
                    return nil
                case 0x7D: // Down arrow
                    if predictionVM.showingSuggestions {
                        predictionVM.moveSelectionDown()
                    } else {
                        session.navigateHistoryDown()
                    }
                    return nil
                default:
                    break
                }
            }
            
            // Ctrl+C to interrupt
            if event.modifierFlags.contains(.control) && event.keyCode == 0x08 {
                tabManager.activeSession?.interrupt()
                return nil
            }
            
            return event
        }
    }
}





// MARK: - Preview
#Preview {
    TerminalWallView()
        .frame(width: 1200, height: 700)
}
