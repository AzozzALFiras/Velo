//
//  DatabaseDetailsView.swift
//  Velo
//
//  Details View for a specific Database
//  Includes Tables, Users, and Operations.
//

import SwiftUI

struct DatabaseDetailsView: View {
    
    @Binding var database: Database
    @Environment(\.dismiss) var dismiss
    
    @State private var activeTab = "Tables"
    
    // Security
    @State private var errorMessage: String? = nil
    @State private var showingErrorAlert = false
    
    // Mock Data
    @State private var tables = [
        "users", "orders", "products", "transactions", "logs", "settings"
    ]
    
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
    }
    
    // MARK: - Tabs
    
    var tablesTab: some View {
        VStack(spacing: 12) {
            ForEach(tables, id: \.self) { table in
                HStack {
                    Image(systemName: "tablecells")
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text(table)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                    Text("\(Int.random(in: 10...5000)) rows")
                        .font(.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .padding(12)
                .background(ColorTokens.layer1)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    var usersTab: some View {
        VStack(spacing: 12) {
            UserRow(user: "admin", access: "Read/Write")
            UserRow(user: "readonly_service", access: "Read Only")
            UserRow(user: "backup_agent", access: "Backup")
        }
    }
    
    var operationsTab: some View {
        VStack(spacing: 16) {
            OperationCard(title: "Optimize Database", description: "Performs table optimization and cleanup.", icon: "wand.and.stars", color: .purple) {}
            OperationCard(title: "Repair Database", description: "Attempts to repair corrupt tables.", icon: "hammer.fill", color: .orange) {}
            OperationCard(title: "Export SQL Dump", description: "Download a full SQL dump of this database.", icon: "arrow.down.doc.fill", color: .blue) {}
            
            Divider().padding(.vertical, 8)
            
            Button(action: {
                SecurityManager.shared.securelyPerformAction(reason: "Delete database \(database.name)") {
                    // Action: Delete Database (Service call would go here)
                    print("Database \(database.name) deleted via details.")
                    dismiss()
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
    }
}

// MARK: - Components

private struct UserRow: View {
    let user: String
    let access: String
    
    var body: some View {
        HStack {
            Image(systemName: "person.fill")
                .foregroundStyle(ColorTokens.textTertiary)
            Text(user)
                .fontWeight(.medium)
                .foregroundStyle(ColorTokens.textPrimary)
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
