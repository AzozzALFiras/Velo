//
//  InputStatusIndicators.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

// MARK: - Prompt Symbol
struct PromptSymbol: View {
    let isExecuting: Bool
    
    var body: some View {
        Text(isExecuting ? "⏳" : "❯")
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundColor(isExecuting ? VeloDesign.Colors.warning : VeloDesign.Colors.neonGreen)
            .glow(isExecuting ? VeloDesign.Colors.warning : VeloDesign.Colors.neonGreen, radius: 8)
    }
}

// MARK: - Executing Indicator
struct ExecutingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: VeloDesign.Spacing.xs) {
            Circle()
                .fill(VeloDesign.Colors.warning)
                .frame(width: 6, height: 6)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
            
            Text("Running")
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.warning)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Exit Code Badge
struct ExitCodeBadge: View {
    let code: Int32
    
    var color: Color {
        code == 0 ? VeloDesign.Colors.success : VeloDesign.Colors.error
    }
    
    var body: some View {
        if code != 0 {
            Text("[\(code)]")
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(color)
                .padding(.horizontal, VeloDesign.Spacing.xs)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(color.opacity(0.15))
                )
        }
    }
}
