//
//  FileInfoPopover.swift
//  Velo
//
//  Intelligence Feature - File Info Popover
//  Displays detailed file information in a popover.
//

import SwiftUI

// MARK: - File Info Popover

struct FileInfoPopover: View {
    let item: FileItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(item.isDirectory ? VeloDesign.Colors.neonCyan : ColorTokens.textTertiary)
                Text(item.name)
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
            }

            Divider()
                .background(VeloDesign.Colors.glassBorder)

            VStack(alignment: .leading, spacing: 6) {
                infoRow(label: "Type", value: item.isDirectory ? "Folder" : "File")
                infoRow(label: "Location", value: item.path)
                if let size = item.size {
                    infoRow(label: "Size", value: formattedSize(size))
                }
            }
        }
        .padding()
        .frame(width: 300)
        .background(VeloDesign.Colors.darkSurface)
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ColorTokens.textTertiary)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ColorTokens.textSecondary)
                .lineLimit(3)
        }
    }

    private func formattedSize(_ size: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
