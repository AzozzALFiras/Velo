//
//  ScriptsTab.swift
//  Velo
//
//  Intelligence Feature - Scripts Tab
//  Displays auto-scripts for automation.
//

import SwiftUI

// MARK: - Scripts Tab

struct ScriptsTab: View {

    let scripts: [AutoScript]
    var onRunScript: ((AutoScript) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if scripts.isEmpty {
                    emptyState(
                        icon: "scroll",
                        title: "No Scripts",
                        subtitle: "Velo will detect patterns and suggest scripts"
                    )
                } else {
                    ForEach(scripts) { script in
                        ScriptCard(script: script) {
                            onRunScript?(script)
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
