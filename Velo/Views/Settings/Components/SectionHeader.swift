//
//  SectionHeader.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title.uppercased())
            .font(VeloDesign.Typography.monoSmall)
            .foregroundColor(VeloDesign.Colors.textSecondary)
            .padding(.leading, 4)
    }
}
