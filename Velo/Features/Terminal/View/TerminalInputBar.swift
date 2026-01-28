//
//  TerminalInputBar.swift
//  Velo
//
//  Enhanced Terminal Input Bar with Autocomplete
//  Shell-like UX with inline suggestions and smart completions
//

import SwiftUI

// MARK: - Terminal Input Bar

struct TerminalInputBar: View {

    // Bindings
    @Binding var inputText: String
    @Binding var isExecuting: Bool

    // Autocomplete state
    let inlineSuggestion: String?
    let showingAutocomplete: Bool
    let completions: [CompletionItem]
    let selectedIndex: Int
    let inputMode: TerminalInputMode

    // Context information
    let currentDirectory: String
    let isGitRepository: Bool
    let hasDocker: Bool
    let isSSHActive: Bool

    // Actions
    var onExecute: () -> Void
    var onShowFiles: () -> Void
    var onShowHistory: () -> Void
    var onShowShortcuts: () -> Void
    var onAskAI: (String) -> Void
    var onAcceptSuggestion: () -> Void
    var onNavigateUp: () -> Void
    var onNavigateDown: () -> Void
    var onSelectCompletion: (CompletionItem) -> Void
    var onDismissAutocomplete: () -> Void

    // Internal state
    @FocusState private var isInputFocused: Bool
    @State private var showToolbar = false

    var body: some View {
        VStack(spacing: 0) {
            // Autocomplete dropdown (above input)
            if showingAutocomplete && !completions.isEmpty && !isExecuting {
                AutocompleteDropdown(
                    completions: completions,
                    selectedIndex: selectedIndex,
                    onSelect: onSelectCompletion
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 60)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 12) {
                // Directory Badge - tap to show files
                // Directory Badge - tap to show files
                // HIDE when SSH is active to reduce redundancy (as requested)
                if !isSSHActive {
                    Button(action: onShowFiles) {
                        HStack(spacing: 5) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 9))
                            Text(displayDirectory)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                        }
                        .foregroundStyle(ColorTokens.accentPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(ColorTokens.accentPrimary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Input mode indicator (for password/interactive prompts)
                if inputMode != .normal {
                    InputModeIndicator(mode: inputMode, promptDescription: "")
                }

                // Prompt indicator
                Text(promptSymbol)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(promptColor)

                // Input field with inline suggestion
                ZStack(alignment: .leading) {
                    // Ghost text layer (inline suggestion)
                    if let suggestion = inlineSuggestion, !suggestion.isEmpty, !inputText.isEmpty, !isExecuting {
                        let ghostText = getGhostText(input: inputText, suggestion: suggestion)
                        if !ghostText.isEmpty {
                            HStack(spacing: 0) {
                                Text(inputText)
                                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                                    .opacity(0)

                                Text(ghostText)
                                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                                    .foregroundStyle(ColorTokens.textTertiary.opacity(0.5))
                            }
                        }
                    }

                    // Actual text field with keyboard handling
                    TextField(placeholderText, text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(inputMode == .password ? ColorTokens.textTertiary : ColorTokens.textPrimary)
                        .focused($isInputFocused)
                        .onSubmit { onExecute() }
                        .onKeyPress(.tab) {
                            // Tab accepts the inline suggestion
                            if inlineSuggestion != nil && !inlineSuggestion!.isEmpty {
                                onAcceptSuggestion()
                                return .handled
                            }
                            return .ignored
                        }
                        .onKeyPress(.rightArrow) {
                            // Right arrow accepts suggestion when there's a suggestion
                            if inlineSuggestion != nil && !inlineSuggestion!.isEmpty {
                                onAcceptSuggestion()
                                return .handled
                            }
                            return .ignored
                        }
                        .onKeyPress(.upArrow) {
                            // Up arrow navigates suggestions
                            if showingAutocomplete {
                                onNavigateUp()
                                return .handled
                            }
                            return .ignored
                        }
                        .onKeyPress(.downArrow) {
                            // Down arrow navigates suggestions
                            if showingAutocomplete {
                                onNavigateDown()
                                return .handled
                            }
                            return .ignored
                        }
                        .onKeyPress(.escape) {
                            // Escape dismisses autocomplete
                            if showingAutocomplete {
                                onDismissAutocomplete()
                                return .handled
                            }
                            return .ignored
                        }
                }

                // Keyboard hints (when typing)
                if !inputText.isEmpty && !isExecuting && inlineSuggestion != nil {
                    HStack(spacing: 8) {
                        KeyboardHint(key: "Tab", action: "accept")
                        KeyboardHint(key: "\u{2191}\u{2193}", action: "navigate")
                    }
                    .transition(.opacity)
                }

                // Quick actions (compact)
                HStack(spacing: 6) {
                    MiniActionButton(icon: "clock.arrow.circlepath", action: onShowHistory)
                    MiniActionButton(icon: "bolt.fill", action: onShowShortcuts)
                    MiniActionButton(icon: "sparkles", isPrimary: true) { onAskAI("") }
                }

                // Execute button
                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 28, height: 28)
                } else {
                    Button(action: onExecute) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(inputText.isEmpty ? ColorTokens.textTertiary : ColorTokens.accentPrimary)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 50) // Fixed height 50pt
            .background(ColorTokens.layer0)
        }
        .animation(.easeOut(duration: 0.15), value: showingAutocomplete)
    }

    // MARK: - Computed Properties

    private var displayDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var display = currentDirectory.replacingOccurrences(of: home, with: "~")

        // Show only last folder name for brevity
        if let lastComponent = display.components(separatedBy: "/").last, !lastComponent.isEmpty {
            return lastComponent
        }
        return display
    }

    private var promptSymbol: String {
        switch inputMode {
        case .normal: return "❯"
        case .interactive: return "?"
        case .password: return "\u{1F512}" // Lock symbol
        case .multiline: return "..."
        }
    }

    private var promptColor: Color {
        if isExecuting {
            return ColorTokens.warning
        }
        switch inputMode {
        case .normal: return isSSHActive ? ColorTokens.accentSecondary : ColorTokens.accentPrimary
        case .interactive: return .blue
        case .password: return .orange
        case .multiline: return .green
        }
    }

    private var placeholderText: String {
        switch inputMode {
        case .normal: return "commandBar.placeholder".localized
        case .interactive: return "Enter response..."
        case .password: return "Enter password..."
        case .multiline: return "Continue input..."
        }
    }

    private func getGhostText(input: String, suggestion: String) -> String {
        if suggestion.lowercased().hasPrefix(input.lowercased()) {
            return String(suggestion.dropFirst(input.count))
        }
        return ""
    }
}

// MARK: - Mini Action Button

private struct MiniActionButton: View {
    let icon: String
    var isPrimary: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isPrimary ? ColorTokens.accentSecondary : ColorTokens.textSecondary)
                .frame(width: 26, height: 26)
                .background(isHovered ? ColorTokens.layer2 : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
