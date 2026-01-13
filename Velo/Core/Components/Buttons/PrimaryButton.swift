//
//  PrimaryButton.swift
//  Velo
//
//  Primary action button component
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false
    var isLoading: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }

                Text(title)
                    .font(TypographyTokens.body)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                isDisabled ? ColorTokens.interactiveDisabled : ColorTokens.interactive
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Continue", action: {})
        PrimaryButton(title: "Disabled", action: {}, isDisabled: true)
        PrimaryButton(title: "Loading", action: {}, isLoading: true)
    }
    .padding()
    .background(ColorTokens.layer0)
}
