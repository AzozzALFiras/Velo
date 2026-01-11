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
