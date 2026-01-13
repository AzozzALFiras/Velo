//
//  InlineMessage.swift
//  Velo
//
//  Inline feedback messages for validation and status display
//

import SwiftUI

struct InlineMessage: View {
    let type: MessageType
    let message: String

    enum MessageType {
        case info
        case success
        case warning
        case error

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .info: return ColorTokens.info
            case .success: return ColorTokens.success
            case .warning: return ColorTokens.warning
            case .error: return ColorTokens.error
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: type.icon)
                .font(.system(size: 14))
                .foregroundColor(type.color)

            Text(message)
                .font(TypographyTokens.bodySm)
                .foregroundColor(ColorTokens.textSecondary)

            Spacer()
        }
        .padding(12)
        .background(type.color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        InlineMessage(type: .info, message: "This is an informational message")
        InlineMessage(type: .success, message: "API key format is valid")
        InlineMessage(type: .warning, message: "Host contains spaces - is this correct?")
        InlineMessage(type: .error, message: "API key cannot be empty")
    }
    .padding()
    .background(ColorTokens.layer0)
}
