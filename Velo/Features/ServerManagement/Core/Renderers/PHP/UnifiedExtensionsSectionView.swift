//
//  UnifiedExtensionsSectionView.swift
//  Velo
//
//  Unified PHP extensions view.
//

import SwiftUI

struct UnifiedExtensionsSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    @State private var searchText = ""

    var filteredExtensions: [PHPExtensionInfo] {
        if searchText.isEmpty {
            return state.extensions
        }
        return state.extensions.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with search
            HStack {
                Text("Loaded Extensions")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("\(state.extensions.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)

                Spacer()

                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)
                    TextField("Search extensions...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                }
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .frame(width: 200)

                Button {
                    Task {
                        await viewModel.loadSectionData()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            if filteredExtensions.isEmpty {
                emptyStateView
            } else {
                extensionsGrid
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 40))
                .foregroundStyle(.gray)

            Text(searchText.isEmpty ? "No extensions loaded" : "No matching extensions")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var extensionsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
            ForEach(filteredExtensions) { ext in
                extensionChip(ext)
            }
        }
    }

    private func extensionChip(_ ext: PHPExtensionInfo) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ext.isLoaded ? Color.green : Color.gray)
                .frame(width: 6, height: 6)

            Text(ext.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            if let version = ext.version {
                Text(version)
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
