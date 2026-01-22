//
//  UnifiedBackupSectionView.swift
//  Velo
//
//  Unified database backup view.
//

import SwiftUI

struct UnifiedBackupSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Backup & Restore")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()
            }

            // Backup section
            VStack(spacing: 12) {
                Image(systemName: "externaldrive.badge.timemachine")
                    .font(.system(size: 40))
                    .foregroundStyle(.gray)

                Text("Database backup functionality")
                    .font(.subheadline)
                    .foregroundStyle(.gray)

                Text("Coming soon")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(40)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
