//
//  ExplanationSheet.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

// MARK: - Explanation Sheet
struct ExplanationSheet: View {
    let explanation: CommandExplanation
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.lg) {
            // Header
            HStack {
                Text("Command Explanation")
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(VeloDesign.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            // Command
            Text(explanation.command)
                .font(VeloDesign.Typography.monoFont)
                .foregroundColor(VeloDesign.Colors.neonCyan)
                .padding(VeloDesign.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VeloDesign.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: VeloDesign.Radius.small))
            
            // Summary
            Text(explanation.summary)
                .font(VeloDesign.Typography.subheadline)
                .foregroundColor(VeloDesign.Colors.textSecondary)
            
            // Breakdown
            if !explanation.breakdown.isEmpty {
                VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                    Text("Breakdown")
                        .font(VeloDesign.Typography.caption)
                        .foregroundColor(VeloDesign.Colors.textMuted)
                    
                    ForEach(explanation.breakdown) { part in
                        HStack(spacing: VeloDesign.Spacing.sm) {
                            Text(part.token)
                                .font(VeloDesign.Typography.monoSmall)
                                .foregroundColor(Color(hex: part.type.color))
                            
                            Text(part.explanation)
                                .font(VeloDesign.Typography.caption)
                                .foregroundColor(VeloDesign.Colors.textSecondary)
                        }
                    }
                }
            }
            
            // Warnings
            if !explanation.warnings.isEmpty {
                VStack(alignment: .leading, spacing: VeloDesign.Spacing.xs) {
                    ForEach(explanation.warnings, id: \.self) { warning in
                        HStack(spacing: VeloDesign.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(VeloDesign.Colors.warning)
                                .font(.system(size: 10))
                            Text(warning)
                                .font(VeloDesign.Typography.caption)
                                .foregroundColor(VeloDesign.Colors.warning)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(VeloDesign.Spacing.lg)
        .frame(width: 400, height: 350)
        .background(VeloDesign.Colors.darkSurface)
    }
}
