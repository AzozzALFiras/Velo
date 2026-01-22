//
//  AutocompleteView.swift
//  Velo
//
//  Autocomplete UI Components
//  Inline ghost text suggestions and dropdown menu
//

import SwiftUI

// MARK: - Inline Suggestion Text Field
/// A text field that shows ghost text suggestions inline (like fish shell)
struct InlineSuggestionTextField: View {

    @Binding var text: String
    let placeholder: String
    let suggestion: String?
    let isExecuting: Bool

    var onSubmit: () -> Void
    var onTab: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            // Ghost text layer (suggestion)
            if let suggestion = suggestion, !suggestion.isEmpty, !text.isEmpty {
                let ghostText = getGhostText(input: text, suggestion: suggestion)
                if !ghostText.isEmpty {
                    HStack(spacing: 0) {
                        // Invisible text to position the ghost text
                        Text(text)
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .opacity(0)

                        // Ghost text (completion)
                        Text(ghostText)
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundStyle(ColorTokens.textTertiary.opacity(0.5))
                    }
                }
            }

            // Actual text field
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(ColorTokens.textPrimary)
                .focused($isFocused)
                .onSubmit { onSubmit() }
        }
    }

    private func getGhostText(input: String, suggestion: String) -> String {
        // If suggestion starts with input, show the remaining part
        if suggestion.lowercased().hasPrefix(input.lowercased()) {
            return String(suggestion.dropFirst(input.count))
        }
        return ""
    }
}

// MARK: - Autocomplete Dropdown
struct AutocompleteDropdown: View {

    let completions: [CompletionItem]
    let selectedIndex: Int
    var onSelect: (CompletionItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(completions.enumerated()), id: \.element.id) { index, item in
                AutocompleteRow(
                    item: item,
                    isSelected: index == selectedIndex
                )
                .onTapGesture {
                    onSelect(item)
                }
            }
        }
        .padding(.vertical, 4)
        .background(ColorTokens.layer1)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorTokens.border, lineWidth: 1)
        )
    }
}

// MARK: - Autocomplete Row
struct AutocompleteRow: View {

    let item: CompletionItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Type icon
            Image(systemName: iconForType(item.type))
                .font(.system(size: 11))
                .foregroundStyle(colorForType(item.type))
                .frame(width: 16)

            // Main text
            Text(item.displayText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(1)

            Spacer()

            // Description
            if let description = item.description {
                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            // Directory indicator
            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? ColorTokens.accentPrimary.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }

    private func iconForType(_ type: CompletionType) -> String {
        switch type {
        case .command: return "terminal"
        case .directory: return "folder.fill"
        case .file: return "doc.fill"
        case .gitBranch: return "arrow.triangle.branch"
        case .gitCommand: return "arrow.triangle.branch"
        case .npmScript: return "shippingbox"
        case .dockerCommand: return "cube"
        case .sshHost: return "network"
        case .environment: return "gearshape"
        case .history: return "clock.arrow.circlepath"
        }
    }

    private func colorForType(_ type: CompletionType) -> Color {
        switch type {
        case .command: return .blue
        case .directory: return .yellow
        case .file: return .gray
        case .gitBranch, .gitCommand: return .orange
        case .npmScript: return .red
        case .dockerCommand: return .cyan
        case .sshHost: return .green
        case .environment: return .purple
        case .history: return .secondary
        }
    }
}

// MARK: - Suggestion Dropdown (for CommandSuggestion)
struct SuggestionDropdown: View {

    let suggestions: [CommandSuggestion]
    let selectedIndex: Int
    var onSelect: (CommandSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                SuggestionRow(
                    suggestion: suggestion,
                    isSelected: index == selectedIndex
                )
                .onTapGesture {
                    onSelect(suggestion)
                }
            }
        }
        .padding(.vertical, 4)
        .background(ColorTokens.layer1)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorTokens.border, lineWidth: 1)
        )
    }
}

// MARK: - Suggestion Row
struct SuggestionRow: View {

    let suggestion: CommandSuggestion
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Source icon
            Image(systemName: suggestion.icon)
                .font(.system(size: 11))
                .foregroundStyle(colorForSource(suggestion.source))
                .frame(width: 16)

            // Command text
            Text(suggestion.command)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(1)

            Spacer()

            // Description
            if let description = suggestion.description {
                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? ColorTokens.accentPrimary.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }

    private func colorForSource(_ source: CommandSuggestion.SuggestionSource) -> Color {
        switch source {
        case .history: return .secondary
        case .filesystem: return .yellow
        case .ai: return .purple
        case .builtin: return .blue
        }
    }
}

// MARK: - Keyboard Hint
struct KeyboardHint: View {

    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(ColorTokens.textSecondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(ColorTokens.layer2)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Text(action)
                .font(.system(size: 9))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }
}

// MARK: - Input Mode Indicator
struct InputModeIndicator: View {

    let mode: TerminalInputMode
    let promptDescription: String

    var body: some View {
        if mode != .normal {
            HStack(spacing: 6) {
                Image(systemName: iconForMode)
                    .font(.system(size: 10))

                Text(promptDescription.isEmpty ? modeLabel : promptDescription)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(colorForMode)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorForMode.opacity(0.15))
            .clipShape(Capsule())
        }
    }

    private var iconForMode: String {
        switch mode {
        case .normal: return "terminal"
        case .interactive: return "questionmark.circle"
        case .password: return "lock.fill"
        case .multiline: return "text.alignleft"
        }
    }

    private var modeLabel: String {
        switch mode {
        case .normal: return "Normal"
        case .interactive: return "Interactive"
        case .password: return "Password"
        case .multiline: return "Multi-line"
        }
    }

    private var colorForMode: Color {
        switch mode {
        case .normal: return .primary
        case .interactive: return .blue
        case .password: return .orange
        case .multiline: return .green
        }
    }
}
