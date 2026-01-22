//
//  UnifiedModulesSectionView.swift
//  Velo
//
//  Unified modules view for web servers.
//

import SwiftUI

struct UnifiedModulesSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    @State private var searchText = ""

    var filteredModules: [String] {
        if searchText.isEmpty {
            return state.modules
        }
        return state.modules.filter { $0.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with search
            HStack {
                Text("Compiled Modules")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("\(state.modules.count)")
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
                    TextField("Search modules...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                }
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .frame(width: 200)
            }

            if filteredModules.isEmpty {
                emptyStateView
            } else {
                modulesGrid
            }

            // Configure arguments (for Nginx)
            if !state.configureArguments.isEmpty {
                configureArgumentsSection
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.system(size: 40))
                .foregroundStyle(.gray)

            Text(searchText.isEmpty ? "No modules found" : "No matching modules")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var modulesGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
            ForEach(filteredModules, id: \.self) { module in
                moduleChip(module)
            }
        }
    }

    private func moduleChip(_ module: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: app.themeColor) ?? .green)

            Text(module)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var configureArgumentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configure Arguments")
                .font(.headline)
                .foregroundStyle(.white)

            ScrollView {
                Text(state.configureArguments.joined(separator: " \\\n    "))
                    .font(.custom("Menlo", size: 11))
                    .foregroundStyle(.white.opacity(0.8))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxHeight: 150)
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
