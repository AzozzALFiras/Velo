//
//  ErrorsTab.swift
//  Velo
//
//  Intelligence Feature - Errors Tab
//  Displays recent errors with AI explain and fix actions.
//

import SwiftUI

// MARK: - Errors Tab

struct ErrorsTab: View {

    let recentErrors: [ErrorItem]
    var onExplainError: ((ErrorItem) -> Void)?
    var onFixError: ((ErrorItem) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if recentErrors.isEmpty {
                    emptyState(
                        icon: "checkmark.circle",
                        title: "intelligence.errors.empty.title".localized,
                        subtitle: "intelligence.errors.empty.subtitle".localized
                    )
                } else {
                    ForEach(recentErrors) { error in
                        ErrorCard(
                            error: error,
                            onExplain: { onExplainError?(error) },
                            onFix: { onFixError?(error) }
                        )
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
