//
//  ChatTab.swift
//  Velo
//
//  Intelligence Feature - Chat Tab
//  AI chat interface with message display and input.
//

import SwiftUI

// MARK: - Chat Tab

struct ChatTab: View {

    let aiMessages: [AIMessage]
    @Binding var chatInput: String
    var onSendMessage: ((String) -> Void)?
    var onRunCommand: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollView {
                LazyVStack(spacing: 12) {
                    if aiMessages.isEmpty {
                        chatEmptyState
                    } else {
                        ForEach(aiMessages) { message in
                            ChatMessageView(
                                message: message,
                                onRunCommand: onRunCommand
                            )
                        }
                    }
                }
                .padding(12)
            }

            Divider()
                .background(ColorTokens.borderSubtle)

            // Input
            chatInputArea
        }
    }

    private var chatEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(ColorTokens.accentSecondary.opacity(0.5))

            Text("Ask me anything")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)

            Text("Get help with commands, errors, or scripts")
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var chatInputArea: some View {
        HStack(spacing: 8) {
            TextField("Ask AI...", text: $chatInput)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ColorTokens.layer2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit {
                    sendMessage()
                }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(chatInput.isEmpty ? ColorTokens.textTertiary : ColorTokens.accentPrimary)
            }
            .buttonStyle(.plain)
            .disabled(chatInput.isEmpty)
        }
        .padding(12)
    }

    private func sendMessage() {
        guard !chatInput.isEmpty else { return }
        onSendMessage?(chatInput)
        chatInput = ""
    }
}
