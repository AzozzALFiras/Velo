//
//  UnifiedUsersSectionView.swift
//  Velo
//
//  Unified database users view.
//

import SwiftUI

struct UnifiedUsersSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Database Users")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("\(state.users.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    // TODO: Add new user
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add User")
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

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

            if state.users.isEmpty {
                emptyStateView
            } else {
                usersList
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundStyle(.gray)

            Text("No users found")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var usersList: some View {
        VStack(spacing: 8) {
            // Header row
            HStack {
                Text("Username")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Host")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .frame(width: 120, alignment: .leading)

                Text("Privileges")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .frame(width: 200, alignment: .leading)

                Spacer()
                    .frame(width: 60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
                .background(Color.white.opacity(0.1))

            ForEach(state.users) { user in
                userRow(user)
            }
        }
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func userRow(_ user: DatabaseUser) -> some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: app.themeColor) ?? .blue)

                Text(user.username)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(user.host)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.gray)
                .frame(width: 120, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(user.privilegeList.prefix(2), id: \.self) { privilege in
                    Text(privilege)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                if user.privilegeList.count > 2 {
                    Text("+\(user.privilegeList.count - 2)")
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: 200, alignment: .leading)

            Menu {
                Button("Edit Privileges") {
                    // TODO: Edit user privileges
                }
                Button("Reset Password") {
                    // TODO: Reset user password
                }
                Divider()
                Button("Delete", role: .destructive) {
                    // TODO: Delete user
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.gray)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.02))
    }
}

extension DatabaseUser {
    var privilegeList: [String] {
        privileges.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
