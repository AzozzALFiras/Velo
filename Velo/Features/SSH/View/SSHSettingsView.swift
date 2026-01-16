//
//  SSHSettingsView.swift
//  Velo
//
//  SSH Connection Management UI
//

import SwiftUI

struct SSHSettingsView: View {
    @EnvironmentObject var sshManager: SSHManager
    @State private var showingEditor = false
    @State private var editingConnection: SSHConnection?
    @State private var showingGroupEditor = false
    @State private var showingImportAlert = false
    @State private var importCount = 0
    
    // Deletion State
    @State private var showingDeleteAlert = false
    @State private var connectionToDelete: SSHConnection?
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.lg) {
            // Header
            HStack {
                SectionHeader(title: "ssh.settings.title".localized)
                Spacer()

                // Import button
                Button(action: importFromConfig) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundColor(ColorTokens.accentPrimary)
                .help("ssh.import.hint".localized)

                // Add group
                Button(action: { showingGroupEditor = true }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundColor(ColorTokens.accentPrimary)
                .help("ssh.group.add".localized)

                // Add connection
                Button(action: { showingEditor = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .foregroundColor(ColorTokens.accentPrimary)
                .help("ssh.conn.add".localized)
            }

            // Connections list
            if sshManager.connections.isEmpty {
                EmptySSHView(onAdd: { showingEditor = true }, onImport: importFromConfig)
            } else {
                VStack(spacing: VeloDesign.Spacing.sm) {
                    // Groups
                    ForEach(sshManager.groups) { group in
                        SSHGroupSection(
                            group: group,
                            connections: sshManager.connections(in: group),
                            onEdit: { editingConnection = $0 },
                            onDelete: {
                                connectionToDelete = $0
                                showingDeleteAlert = true
                            }
                        )
                    }

                    // Ungrouped
                    let ungrouped = sshManager.ungroupedConnections()
                    if !ungrouped.isEmpty {
                        SSHGroupSection(
                            group: nil,
                            connections: ungrouped,
                            onEdit: { editingConnection = $0 },
                            onDelete: {
                                connectionToDelete = $0
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            SSHConnectionEditor(connection: nil)
        }
        .sheet(item: $editingConnection) { connection in
            SSHConnectionEditor(connection: connection)
        }
        .sheet(isPresented: $showingGroupEditor) {
            SSHGroupEditor(group: nil)
        }
        .alert("Import Complete", isPresented: $showingImportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("ssh.import.success".localized.replacingOccurrences(of: "{}", with: "\(importCount)"))
        }
        // Deletion Confirmation Alert
        .alert("Delete Connection", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { connectionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let conn = connectionToDelete {
                    SecurityManager.shared.securelyPerformAction(reason: "Confirm deletion of \(conn.name)") {
                        sshManager.deleteConnection(conn)
                    } onError: { error in
                        self.errorMessage = error
                        self.showingErrorAlert = true
                    }
                }
                connectionToDelete = nil
            }
        } message: {
            if let conn = connectionToDelete {
                Text("Are you sure you want to delete \(conn.name)? This will also remove the saved password.")
            }
        }
        // Error Alert
        .alert("Authentication Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    private func importFromConfig() {
        importCount = sshManager.importFromSSHConfig()
        showingImportAlert = true
    }
}

// MARK: - Empty State
struct EmptySSHView: View {
    let onAdd: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: VeloDesign.Spacing.md) {
            Image(systemName: "server.rack")
                .font(.system(size: 40))
                .foregroundColor(ColorTokens.textTertiary)

            Text("ssh.none".localized)
                .font(TypographyTokens.body)
                .foregroundColor(ColorTokens.textSecondary)

            HStack(spacing: VeloDesign.Spacing.md) {
                Button(action: onAdd) {
                    Label("ssh.conn.add".localized, systemImage: "plus")
                        .font(TypographyTokens.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(ColorTokens.accentPrimary)
                .padding(.horizontal, VeloDesign.Spacing.md)
                .padding(.vertical, 6)
                .background(ColorTokens.accentPrimary.opacity(0.1))
                .cornerRadius(6)

                Button(action: onImport) {
                    Label("ssh.import.hint".localized, systemImage: "square.and.arrow.down")
                        .font(TypographyTokens.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(ColorTokens.textSecondary)
                .padding(.horizontal, VeloDesign.Spacing.md)
                .padding(.vertical, 6)
                .background(ColorTokens.layer2)
                .cornerRadius(6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VeloDesign.Spacing.xl)
    }
}
