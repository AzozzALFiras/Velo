//
//  ChatMessageView.swift
//  Velo
//
//  Intelligence Feature - Chat Message Component
//  Displays a single chat message with optional code blocks.
//

import SwiftUI

// MARK: - Chat Message View

struct ChatMessageView: View {

    let message: AIMessage
    var onRunCommand: ((String) -> Void)?

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
            // Sender label
            HStack(spacing: 4) {
                if !message.isUser {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundStyle(ColorTokens.accentSecondary)
                }

                Text(message.isUser ? "You" : "Velo AI")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            // Message content
            VStack(alignment: .leading, spacing: 8) {
                Text(message.content)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textPrimary)

                // Code blocks
                ForEach(message.codeBlocks, id: \.self) { code in
                    InlineCodeBlock(code: code) {
                        onRunCommand?(code)
                    }
                }
            }
            .padding(10)
            .background(message.isUser ? ColorTokens.accentPrimary.opacity(0.15) : ColorTokens.layer2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

// MARK: - Inline Code Block

struct InlineCodeBlock: View {

    let code: String
    let onRun: () -> Void

    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(code)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ColorTokens.textPrimary)

            HStack(spacing: 8) {
                Button {
                    onRun()
                } label: {
                    Label("Run", systemImage: "play.fill")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.success)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                } label: {
                    Label(isCopied ? "Copied" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .padding(8)
        .background(ColorTokens.layer0)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
