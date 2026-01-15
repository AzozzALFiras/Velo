//
//  IntelligencePanel.swift
//  Velo
//
//  Intelligence Feature - Main Panel Entry Point
//  AI Chat, Errors, Suggestions, Auto-Scripts, History, Files
//

import SwiftUI

// MARK: - Intelligence Panel

/// Right panel for AI chat, errors, suggestions, and auto-scripts
struct IntelligencePanel: View {

    // State
    @Binding var selectedTab: IntelligenceTab
    @State private var chatInput: String = ""
    @State private var isExpanded: Bool = false
    @State private var historySearchText: String = ""

    // Data
    @ObservedObject var historyManager: CommandHistoryManager
    var aiMessages: [AIMessage] = []
    var recentErrors: [ErrorItem] = []
    var suggestions: [SuggestionItem] = []
    var scripts: [AutoScript] = []
    var currentDirectory: String = ""
    var isSSH: Bool = false
    var sshConnectionString: String? = nil
    var parsedTerminalItems: [String] = []

    // Upload state for progress indicator
    var isUploading: Bool = false
    var uploadFileName: String = ""
    var uploadStartTime: Date? = nil
    var uploadProgress: Double = 0.0

    // Actions
    var onSendMessage: ((String) -> Void)?
    var onRunCommand: ((String) -> Void)?
    var onExplainError: ((ErrorItem) -> Void)?
    var onFixError: ((ErrorItem) -> Void)?
    var onRunScript: ((AutoScript) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onEditFile: ((String) -> Void)?
    var onChangeDirectory: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs
            panelHeader

            Divider()
                .background(ColorTokens.border)

            // Content based on selected tab
            Group {
                switch selectedTab {
                case .chat:
                    ChatTab(
                        aiMessages: aiMessages,
                        chatInput: $chatInput,
                        onSendMessage: onSendMessage,
                        onRunCommand: onRunCommand
                    )
                case .history:
                    HistoryTab(
                        historyManager: historyManager,
                        searchText: $historySearchText,
                        onRunCommand: onRunCommand
                    )
                case .files:
                    FilesTab(
                        currentDirectory: currentDirectory,
                        isSSH: isSSH,
                        sshConnectionString: sshConnectionString,
                        parsedTerminalItems: parsedTerminalItems,
                        isUploading: isUploading,
                        uploadFileName: uploadFileName,
                        uploadStartTime: uploadStartTime,
                        uploadProgress: uploadProgress,
                        onEditFile: onEditFile,
                        onChangeDirectory: onChangeDirectory,
                        onRunCommand: onRunCommand
                    )
                case .errors:
                    ErrorsTab(
                        recentErrors: recentErrors,
                        onExplainError: onExplainError,
                        onFixError: onFixError
                    )
                case .suggestions:
                    SuggestionsTab(
                        suggestions: suggestions,
                        onRunCommand: onRunCommand
                    )
                case .scripts:
                    ScriptsTab(
                        scripts: scripts,
                        onRunScript: onRunScript
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ColorTokens.layer1)
    }

    // MARK: - Header

    private var panelHeader: some View {
        VStack(spacing: 0) {
            // Title row
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.accentSecondary)

                    Text("Intelligence")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                }

                Spacer()

                // Expand button
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Tab bar
            HStack(spacing: 2) {
                ForEach(IntelligenceTab.allCases) { tab in
                    IntelligenceTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        hasNotification: tabHasNotification(tab)
                    ) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    private func tabHasNotification(_ tab: IntelligenceTab) -> Bool {
        switch tab {
        case .errors: return !recentErrors.isEmpty
        case .suggestions: return !suggestions.isEmpty
        default: return false
        }
    }
}

// MARK: - Preview

#Preview {
    IntelligencePanel(
        selectedTab: .constant(.chat),
        historyManager: CommandHistoryManager(),
        aiMessages: [
            AIMessage(content: "How do I revert the last commit?", isUser: true),
            AIMessage(
                content: "To revert the last commit, you can use:",
                isUser: false,
                codeBlocks: ["git reset --soft HEAD~1"]
            )
        ],
        recentErrors: [
            ErrorItem(message: "npm ERR! ENOENT", command: "npm install", timestamp: Date().addingTimeInterval(-120))
        ],
        suggestions: [
            SuggestionItem(command: "git push origin main", reason: "You have 1 commit ahead")
        ],
        scripts: [
            AutoScript(name: "Deploy Script", commands: ["git pull", "npm install", "npm run build"])
        ],
        parsedTerminalItems: []
    )
    .frame(width: 300, height: 600)
}
