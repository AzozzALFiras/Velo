//
//  InputAreaView.swift
//  Velo
//
//  AI-Powered Terminal - Command Input Area
//

import SwiftUI

// MARK: - Input Area View
/// Futuristic command input with ghost text predictions
struct InputAreaView: View {
    @ObservedObject var viewModel: TerminalViewModel
    @ObservedObject var predictionVM: PredictionViewModel
    
    @FocusState private var isFocused: Bool
    @State private var cursorBlink = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Suggestions dropdown
            if predictionVM.showingSuggestions {
                SuggestionsDropdown(
                    viewModel: predictionVM,
                    onSelect: { suggestion in
                        viewModel.acceptSuggestion(suggestion)
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Input bar
            HStack(spacing: VeloDesign.Spacing.md) {
                // Directory indicator (clickable)
                DirectoryBadge(
                    path: viewModel.currentDirectory,
                    onNavigate: { path in
                        viewModel.navigateToDirectory(path)
                    }
                )
                
                // Prompt symbol
                PromptSymbol(isExecuting: viewModel.isExecuting)
                
                // Input field with ghost text
                ZStack(alignment: .leading) {
                    // Ghost text (prediction)
                    if let prediction = predictionVM.inlinePrediction,
                       !viewModel.inputText.isEmpty,
                       prediction.lowercased().hasPrefix(viewModel.inputText.lowercased()) {
                        Text(prediction)
                            .font(VeloDesign.Typography.monoFont)
                            .foregroundColor(VeloDesign.Colors.textMuted.opacity(0.5))
                    }
                    
                    // Actual input
                    TextField("Enter command...", text: $viewModel.inputText)
                        .font(VeloDesign.Typography.monoFont)
                        .foregroundColor(VeloDesign.Colors.textPrimary)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onSubmit {
                            viewModel.executeCommand()
                        }
                }
                
                // Status indicator
                if viewModel.isExecuting {
                    ExecutingIndicator()
                } else {
                    if viewModel.lastExitCode != 0 {
                        // Error State: Button to Ask AI
                        Button(action: {
                            let lastCmd = viewModel.historyManager.recentCommands.first?.command ?? "unknown command"
                            NotificationCenter.default.post(
                                name: .askAI,
                                object: nil,
                                userInfo: ["query": "Explain why the command '\(lastCmd)' failed with exit code \(viewModel.lastExitCode)."]
                            )
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text("Ask AI (\(viewModel.lastExitCode))")
                                    .font(VeloDesign.Typography.monoSmall)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(VeloDesign.Colors.error.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(VeloDesign.Colors.error, lineWidth: 1)
                            )
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(VeloDesign.Colors.error)
                        .help("Ask AI to explain this error")
                    } else {
                        // Success State
                        ExitCodeBadge(code: viewModel.lastExitCode)
                    }
                }
            }
            .padding(.horizontal, VeloDesign.Spacing.lg)
            .padding(.vertical, VeloDesign.Spacing.md)
            .background(VeloDesign.Colors.cardBackground)
            .overlay(
                Rectangle()
                    .fill(VeloDesign.Colors.glassBorder)
                    .frame(height: 1),
                alignment: .top
            )
        }
        .animation(VeloDesign.Animation.quick, value: predictionVM.showingSuggestions)
        .onAppear {
            isFocused = true
            startCursorBlink()
        }
    }
    
    private func startCursorBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            cursorBlink.toggle()
        }
    }
}



// MARK: - Preview
#Preview {
    VStack {
        Spacer()
        
        let terminal = TerminalViewModel()
        let predictionVM = PredictionViewModel(predictionEngine: terminal.predictionEngine)
        
        InputAreaView(
            viewModel: terminal,
            predictionVM: predictionVM
        )
    }
    .background(VeloDesign.Colors.deepSpace)
}
