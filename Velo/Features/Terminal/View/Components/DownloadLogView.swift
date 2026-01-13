//
//  DownloadLogView.swift
//  Velo
//
//  View to display download logs
//

import SwiftUI

struct DownloadLogView: View {
    @Binding var logs: String
    @Binding var isPresented: Bool
    let isDownloading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(isDownloading ? "Downloading..." : "Download Complete")
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                
                if isDownloading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(VeloDesign.Colors.neonCyan)
                }
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(VeloDesign.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(VeloDesign.Colors.elevatedSurface)
            
            Divider()
                .background(VeloDesign.Colors.glassBorder)
            
            // Logs
            ScrollView {
                Text(logs)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(VeloDesign.Colors.darkSurface)
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}
