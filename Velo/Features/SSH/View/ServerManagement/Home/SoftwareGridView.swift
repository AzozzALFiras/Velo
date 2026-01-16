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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Applications", systemImage: "apps.ipad.landscape")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.3))
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(softwareList) { sw in
                    ModernAppCard(software: sw)
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
                Image(systemName: software.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
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
