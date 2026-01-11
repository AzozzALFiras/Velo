//
//  LinkRow.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

struct LinkRow: View {
    let icon: IconSource
    let title: String
    let url: URL
    let color: Color
    
    @State private var isHovered = false
    
    var body: some View {
        Link(destination: url) {
            HStack {
                Group {
                    switch icon {
                    case .system(let name):
                        Image(systemName: name)
                            .resizable()
                    case .asset(let name):
                        Image(name)
                            .resizable()
                    }
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundColor(color)
                
                Text(title)
                    .font(VeloDesign.Typography.subheadline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundColor(VeloDesign.Colors.textMuted)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? VeloDesign.Colors.glassHighlight : Color.clear)
            )
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
