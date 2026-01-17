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
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
