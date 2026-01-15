//
//  HistoryTab.swift
//  Velo
//
//  Intelligence Feature - History Tab
//  Command history browser with search and favorites.
//

import SwiftUI

// MARK: - History Tab

struct HistoryTab: View {

    @ObservedObject var historyManager: CommandHistoryManager
    @Binding var searchText: String
    var onRunCommand: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)

                TextField("intelligence.history.search".localized, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ColorTokens.layer2)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // Favorites Section
                    if !historyManager.favoriteCommands.isEmpty && searchText.isEmpty {
                        IntelligenceSectionHeader(title: "intelligence.history.favorites".localized, icon: "star.fill", color: ColorTokens.warning)

                        ForEach(historyManager.favoriteCommands) { command in
                            HistoryRow(command: command, historyManager: historyManager) {
                                onRunCommand?(command.command)
                            }
                        }

                        Divider()
                            .padding(.vertical, 8)
                    }

                    // Recent Section
                    IntelligenceSectionHeader(title: "intelligence.history.recent".localized, icon: "clock", color: ColorTokens.accentPrimary)

                    let commands = searchText.isEmpty ? historyManager.recentCommands : historyManager.search(query: searchText)

                    if commands.isEmpty {
                        Text("intelligence.history.none".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(commands) { command in
                            HistoryRow(command: command, historyManager: historyManager) {
                                onRunCommand?(command.command)
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
    }
}
