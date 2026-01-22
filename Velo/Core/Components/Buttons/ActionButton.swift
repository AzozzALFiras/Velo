//
//  ActionButton.swift
//  Velo
//
//  Centralized UI component for quick actions with icon and color.
//

import SwiftUI

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var isExpandable: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: isExpandable ? (isHovered ? 8 : 0) : 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                
                if !isExpandable || isHovered {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .fixedSize(horizontal: true, vertical: false)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .padding(.horizontal, isExpandable ? (isHovered ? 12 : 10) : 12)
            .padding(.vertical, 10)
            .background(color.opacity(isHovered ? 0.2 : 0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}
