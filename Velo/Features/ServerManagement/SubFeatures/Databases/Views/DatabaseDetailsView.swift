//
//  DatabaseDetailsView.swift
//  Velo
//
//  Details View for a specific Database
//  Includes Tables, Users, and Operations.
//

import SwiftUI
import UniformTypeIdentifiers

struct DatabaseDetailsView: View {
    
    @Binding var database: Database
    @Environment(\.dismiss) var dismiss
    
    // ViewModel
    @StateObject private var viewModel: DatabaseDetailsViewModel
    
    @State private var activeTab = "Tables"
    
    // Security
    @State private var errorMessage: String? = nil
    @State private var showingErrorAlert = false
    
    // Init to inject dependencies
    init(database: Binding<Database>, session: TerminalViewModel?) {
        _database = database
        _viewModel = StateObject(wrappedValue: DatabaseDetailsViewModel(database: database.wrappedValue, session: session))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Header
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                    .fill(ColorTokens.layer2)
                    .frame(width: 48, height: 48)
                    
                    Image(systemName: database.type.icon)
                        .font(.title2)
                        .foregroundStyle(ColorTokens.accentSecondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(database.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    HStack {
                        Text(database.type.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ColorTokens.layer2)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(ColorTokens.textTertiary)
                        
                        Text(database.sizeString)
                            .font(.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(ColorTokens.accentPrimary)
            }
            .padding(20)
            .background(ColorTokens.layer1)
            
            Divider()
                .background(ColorTokens.borderSubtle)
            
            // Tabs
            HStack(spacing: 24) {
                ForEach(["Tables", "Users", "Operations"], id: \.self) { tab in
                    Button(action: { activeTab = tab }) {
                        VStack(spacing: 6) {
                            Text(tab)
                                .font(.system(size: 14, weight: activeTab == tab ? .medium : .regular))
                                .foregroundStyle(activeTab == tab ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                            
                            Rectangle()
                                .fill(activeTab == tab ? ColorTokens.accentPrimary : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .background(ColorTokens.layer0)
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    if activeTab == "Tables" {
                        tablesTab
                    } else if activeTab == "Users" {
                        usersTab
                    } else if activeTab == "Operations" {
                        operationsTab
                    }
                }
                .padding(20)
            }
            
        }
        .frame(width: 500, height: 600)
        .background(ColorTokens.layer0)
        .alert("Authentication Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .task {
            // Reload data when view appears
            await viewModel.loadData()
        }
    }
    
    // MARK: - Tabs
    
    var tablesTab: some View {
        VStack(spacing: 12) {
            if viewModel.tables.isEmpty && !viewModel.isLoading {
                Text("No tables found")
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding()
            } else {
                ForEach(viewModel.tables) { table in
                    HStack {
                        Image(systemName: "tablecells")
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text(table.name)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        
                        Text(table.sizeString)
                            .font(.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .padding(.trailing, 8)
                        
                        Text("\(table.rows) rows")
                            .font(.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .padding(12)
                    .background(ColorTokens.layer1)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    var usersTab: some View {
        VStack(spacing: 12) {
            if viewModel.users.isEmpty && !viewModel.isLoading {
                Text("No users found")
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding()
            } else {
                ForEach(viewModel.users) { user in
                    UserRow(user: user.username, host: user.host, access: user.privileges)
                }
            }
        }
    }
    
    // Operations Feedback
    @State private var operationAlert: AlertItem?

    var operationsTab: some View {
        VStack(spacing: 16) {
            OperationCard(title: "Optimize Database", description: "Performs table optimization and cleanup.", icon: "wand.and.stars", color: .purple) {
                Task {
                    let success = await viewModel.optimizeDatabase()
                    operationAlert = AlertItem(
                        title: success ? "Optimization Complete" : "Optimization Failed",
                        message: success ? "Database tables have been optimized." : "Could not optimize the database."
                    )
                }
            }
            
            OperationCard(title: "Repair Database", description: "Attempts to repair corrupt tables.", icon: "hammer.fill", color: .orange) {
                Task {
                    let success = await viewModel.repairDatabase()
                    operationAlert = AlertItem(
                        title: success ? "Repair Complete" : "Repair Failed",
                        message: success ? "Database repair process finished." : "Could not repair the database."
                    )
                }
            }
            
            OperationCard(title: "Export SQL Dump", description: "Download a full SQL dump of this database.", icon: "arrow.down.doc.fill", color: .blue) {
                Task {
                    // 1. Generate Remote Dump
                    guard let remotePath = await viewModel.exportDatabase() else {
                        operationAlert = AlertItem(title: "Export Failed", message: "Could not create SQL dump on server.")
                        return
                    }
                    
                    // 2. Ask user for save location
                    await MainActor.run {
                        let panel = NSSavePanel()
                        panel.nameFieldStringValue = (remotePath as NSString).lastPathComponent
                        panel.allowedContentTypes = [.init(filenameExtension: "sql")!]
                        panel.prompt = "Download"
                        panel.title = "Save Database Dump"
                        
                        panel.begin { response in
                            if response == .OK, let url = panel.url {
                                // 3. Start Download & Cleanup
                                Task {
                                    await viewModel.downloadAndCleanup(remotePath: remotePath, to: url)
                                    // Alert is handled by Terminal success toast mostly, but we can show completion alert if desired.
                                    // For now relying on standard Velo download feedback.
                                }
                            } else {
                                // User cancelled - clean up the remote file
                                Task {
                                     await viewModel.deleteRemoteFile(remotePath)
                                }
                            }
                        }
                    }
                }
            }
            
            Divider().padding(.vertical, 8)
            
            Button(action: {
                SecurityManager.shared.securelyPerformAction(reason: "Delete database \(database.name)") {
                    Task {
                        _ = await viewModel.deleteDatabase()
                        dismiss()
                    }
                } onError: { error in
                    self.errorMessage = error
                    self.showingErrorAlert = true
                }
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Database")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .alert(item: $operationAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }
}

struct AlertItem: Identifiable {
    var id = UUID()
    var title: String
    var message: String
}

// MARK: - Components

private struct UserRow: View {
    let user: String
    let host: String
    let access: String
    
    var body: some View {
        HStack {
            Image(systemName: "person.fill")
                .foregroundStyle(ColorTokens.textTertiary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user)
                    .fontWeight(.medium)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("@" + host)
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            
            Spacer()
            
            Text(access)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ColorTokens.layer2)
                .clipShape(Capsule())
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(12)
        .background(ColorTokens.layer1)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct OperationCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.medium)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(12)
            .background(ColorTokens.layer1)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isHovered ? color.opacity(0.3) : ColorTokens.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
