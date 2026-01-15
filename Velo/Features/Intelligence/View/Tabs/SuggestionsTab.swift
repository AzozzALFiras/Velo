//
//  SuggestionsTab.swift
//  Velo
//
//  Intelligence Feature - Suggestions Tab
//  Displays AI-generated command suggestions.
//

import SwiftUI

// MARK: - Suggestions Tab

struct SuggestionsTab: View {

    let suggestions: [SuggestionItem]
    var onRunCommand: ((String) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if suggestions.isEmpty {
                    emptyState(
                        icon: "lightbulb",
                        title: "intelligence.suggestions.empty.title".localized,
                        subtitle: "intelligence.suggestions.empty.subtitle".localized
                    )
                } else {
                    Text("intelligence.suggestions.workflow".localized)
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(suggestions) { suggestion in
                        SuggestionCard(suggestion: suggestion) {
                            onRunCommand?(suggestion.command)
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(ColorTokens.textTertiary)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
