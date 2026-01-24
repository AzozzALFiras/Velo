//
//  SoftwareGridView.swift
//  Velo
//
//  Component: Software Grid
//  Grid of installed software with status indicators.
//

import SwiftUI

struct SoftwareGridView: View {
    
    let softwareList: [InstalledSoftware]
    var onAddTap: () -> Void
    var onSoftwareTap: ((InstalledSoftware) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onAddTap) {
                HStack {
                    Label("Applications", systemImage: "apps.ipad.landscape")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .buttonStyle(.plain)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(softwareList) { sw in
                    Button {
                        onSoftwareTap?(sw)
                    } label: {
                        ModernAppCard(software: sw)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .background(
            Color.black.opacity(0.6)
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}


private struct ModernAppCard: View {
    let software: InstalledSoftware
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                SoftwareIconView(iconURL: software.iconName, slug: software.slug)
                
                Spacer()
                
                Circle()
                    .fill(software.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .shadow(color: software.isRunning ? Color.green : Color.red, radius: 4)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(software.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(software.isRunning ? "Running" : "Stopped")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .frame(height: 110)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
