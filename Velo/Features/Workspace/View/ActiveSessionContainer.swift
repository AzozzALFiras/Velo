//
//  ActiveSessionContainer.swift
//  Velo
//
//  Root Feature - Active Session Container
//  A container that observes the active session to ensure the UI re-renders on session property changes.
//

import SwiftUI

// MARK: - Active Session Container

/// A container that observes the active session to ensure the UI re-renders on session property changes
struct ActiveSessionContainer: View {
    @ObservedObject var session: TerminalViewModel
    var contextManager: ContextManager
    @ObservedObject var historyManager: CommandHistoryManager

    var aiMessages: [AIMessage]
    var recentErrors: [ErrorItem]
    var suggestions: [SuggestionItem]
    var scripts: [AutoScript]

    @Binding var showIntelligencePanel: Bool
    @Binding var selectedIntelligenceTab: IntelligenceTab
    @Binding var inputText: String
    @Binding var isExecuting: Bool

    var executeCommand: () -> Void
    var handleBlockAction: (CommandBlock, BlockAction) -> Void
    var retryBlock: (CommandBlock) -> Void
    var askAI: (String) -> Void
    var editFile: (String) -> Void
    var gitSync: () -> Void
    var showBranchSwitcher: () -> Void
    @Binding var showShortcuts: Bool

    var sendAIMessage: (String) -> Void
    var runCommand: (String) -> Void
    var explainError: (ErrorItem) -> Void
    var fixError: (ErrorItem) -> Void
    var runScript: (AutoScript) -> Void

    private var currentDirectory: String {
        if session.isSSHActive, let remoteDir = session.remoteWorkingDirectory {
            return remoteDir
        }
        return session.currentDirectory
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Workspace
                WorkspaceLayout(
                    contextManager: contextManager,
                    blocks: session.blocks,
                    inputText: $inputText,
                    isExecuting: $isExecuting,
                    currentDirectory: currentDirectory,
                    onExecute: executeCommand,
                    onBlockAction: handleBlockAction,
                    onRetryBlock: retryBlock,
                    onAskAI: askAI,
                    onOpenPath: { path in
                        editFile(path)
                    },
                    onSync: gitSync,
                    onBranchSwitch: showBranchSwitcher,
                    onShowShortcuts: { showShortcuts = true },
                    onShowFiles: {
                        selectedIntelligenceTab = .files
                        withAnimation { showIntelligencePanel = true }
                    },
                    onShowHistory: {
                        selectedIntelligenceTab = .history
                        withAnimation { showIntelligencePanel = true }
                    }
                )

                // Intelligence Panel
                if showIntelligencePanel {
                    Divider()
                        .background(ColorTokens.border)

                    IntelligencePanel(
                        selectedTab: $selectedIntelligenceTab,
                        historyManager: historyManager,
                        aiMessages: aiMessages,
                        recentErrors: recentErrors,
                        suggestions: suggestions,
                        scripts: scripts,
                        currentDirectory: currentDirectory,
                        isSSH: session.isSSHActive,
                        sshConnectionString: session.activeSSHConnectionString,
                        parsedTerminalItems: session.parsedDirectoryItems,
                        isUploading: session.isUploading,
                        uploadFileName: session.uploadFileName,
                        uploadStartTime: session.uploadStartTime,
                        uploadProgress: session.uploadProgress,
                        onSendMessage: sendAIMessage,
                        onRunCommand: runCommand,
                        onExplainError: explainError,
                        onFixError: fixError,
                        onRunScript: runScript,
                        onEditFile: { path in
                            editFile(path)
                        },
                        onChangeDirectory: { path in
                            session.currentDirectory = path
                            Task { await contextManager.updateContext(for: path) }
                        }
                    )
                    .frame(width: 340)
                    .transition(.move(edge: .trailing))
                }
            }

            // Integrated Command Bar spanning both columns
            TerminalInputBar(
                inputText: $inputText,
                isExecuting: $isExecuting,
                currentDirectory: currentDirectory,
                isGitRepository: contextManager.isGitRepository,
                hasDocker: contextManager.isDockerProject,
                onExecute: executeCommand,
                onShowFiles: {
                    selectedIntelligenceTab = .files
                    withAnimation { showIntelligencePanel = true }
                },
                onShowHistory: {
                    selectedIntelligenceTab = .history
                    withAnimation { showIntelligencePanel = true }
                },
                onShowShortcuts: { showShortcuts = true },
                onAskAI: askAI
            )
        }
        .transition(.opacity)
        // Toast overlay for upload/download notifications
        .overlay(alignment: .bottom) {
            if session.showToast {
                HStack(spacing: 8) {
                    Image(systemName: session.toastIsSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(session.toastIsSuccess ? ColorTokens.success : ColorTokens.error)

                    Text(session.toastMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.85))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                .padding(.bottom, 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: session.showToast)
            }
        }
    }
}
