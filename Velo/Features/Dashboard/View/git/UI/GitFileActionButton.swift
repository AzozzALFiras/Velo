//
//  GitFileActionButton.swift
//  Velo
//
//  Git Feature - File Action Button Component
//  Small action button for git file operations (stage, view, etc.)
//

import SwiftUI

// MARK: - Git File Action Button

struct GitFileActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 22, height: 22)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
