//
//  EditorField.swift
//  Velo
//
//  Text field component for SSH editor forms
//

import SwiftUI

struct VeloEditorField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ColorTokens.textTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(TypographyTokens.mono)
                .padding(10)
                .background(ColorTokens.layer2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
}
