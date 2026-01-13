//
//  EditorField.swift
//  Velo
//
//  Text field component for SSH editor forms
//

import SwiftUI

struct EditorField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TypographyTokens.caption)
                .foregroundColor(ColorTokens.textTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(TypographyTokens.mono)
                .padding(VeloDesign.Spacing.sm)
                .background(ColorTokens.layer2)
                .cornerRadius(6)
        }
    }
}
