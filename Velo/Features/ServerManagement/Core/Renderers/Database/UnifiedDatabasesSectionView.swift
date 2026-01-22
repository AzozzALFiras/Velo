//
//  UnifiedDatabasesSectionView.swift
//  Velo
//
//  Unified databases list view.
//

import SwiftUI

struct UnifiedDatabasesSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    @State private var searchText = ""

    var filteredDatabases: [DatabaseInfo] {
        if searchText.isEmpty {
            return state.databases
        }
        return state.databases.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Databases")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("\(state.databases.count)")
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
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                }
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .frame(width: 180)

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

            if filteredDatabases.isEmpty {
                emptyStateView
            } else {
                databasesList
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cylinder")
                .font(.system(size: 40))
                .foregroundStyle(.gray)

            Text(searchText.isEmpty ? "No databases found" : "No matching databases")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var databasesList: some View {
        VStack(spacing: 8) {
            // Header row
            HStack {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Size")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .frame(width: 100, alignment: .trailing)

                Text("Tables")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .frame(width: 80, alignment: .trailing)

                Spacer()
                    .frame(width: 80)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
                .background(Color.white.opacity(0.1))

            ForEach(filteredDatabases) { db in
                databaseRow(db)
            }
        }
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func databaseRow(_ db: DatabaseInfo) -> some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "cylinder.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: app.themeColor) ?? .blue)

                Text(db.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(db.size)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.gray)
                .frame(width: 100, alignment: .trailing)

            Text("\(db.tableCount)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.gray)
                .frame(width: 80, alignment: .trailing)

            Menu {
                Button("Browse") {
                    // TODO: Open database browser
                }
                Button("Export") {
                    // TODO: Export database
                }
                Divider()
                Button("Delete", role: .destructive) {
                    // TODO: Delete database
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.gray)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 80)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.02))
    }
}
