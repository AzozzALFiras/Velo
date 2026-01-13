//
//  SettingsComponents.swift
//  Velo
//
//  Settings UI Helper Components
//

import SwiftUI

// MARK: - Glass Card Modifier
struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(VeloDesign.Colors.cardBackground.opacity(0.5))
            .cornerRadius(VeloDesign.Radius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: VeloDesign.Radius.medium)
                    .stroke(VeloDesign.Colors.glassBorder, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}

// MARK: - Secure Field Row
struct SecureFieldRow: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(VeloDesign.Typography.monoFont)
                .foregroundColor(VeloDesign.Colors.textPrimary)
            
            SecureField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(VeloDesign.Typography.monoSmall)
                .padding(8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(VeloDesign.Colors.glassBorder, lineWidth: 1)
                )
        }
    }
}
