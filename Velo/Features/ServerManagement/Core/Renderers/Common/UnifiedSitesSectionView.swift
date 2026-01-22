//
//  UnifiedSitesSectionView.swift
//  Velo
//
//  Unified sites/virtual hosts view for web servers.
//

import SwiftUI

struct UnifiedSitesSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Configured Sites")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    // TODO: Add new site sheet
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Site")
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            // Sites list
            VStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 40))
                    .foregroundStyle(.gray)

                Text("Sites management coming soon")
                    .font(.subheadline)
                    .foregroundStyle(.gray)

                Text("Use the existing Sites view for now")
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
