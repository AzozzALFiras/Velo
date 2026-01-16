//
//  DatabasesListView.swift
//  Velo
//
//  Databases Management View
//  List of databases with management options.
//

import SwiftUI

struct DatabasesListView: View {
    
    @ObservedObject var viewModel: ServerManagementViewModel
    
    // State for Search & Filter
    @State private var searchText = ""
    @State private var selectedType: Database.DatabaseType? = nil
    @State private var selectedDatabase: Database? = nil
    
    var filteredDatabases: [Database] {
        viewModel.databases.filter { db in
            let matchesSearch = searchText.isEmpty || db.name.localizedCaseInsensitiveContains(searchText)
            let matchesType = selectedType == nil || db.type == selectedType
            return matchesSearch && matchesType
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Controls: Search & Tabs
                VStack(spacing: 12) {
                    // Type Tabs (Top)
                    HStack(spacing: 0) {
                        TypeTab(title: "All", isSelected: selectedType == nil) {
                            selectedType = nil
                        }
                        
                        ForEach(Database.DatabaseType.allCases, id: \.self) { type in
                            TypeTab(title: type.rawValue, isSelected: selectedType == type) {
                                selectedType = selectedType == type ? nil : type
                            }
                        }
                        Spacer()
                    }
                    .padding(.bottom, 4)
                    .overlay(Divider(), alignment: .bottom)
                    
                    // Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(ColorTokens.textTertiary)
                        TextField("Search databases...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(8)
                    .background(ColorTokens.layer1)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(ColorTokens.borderSubtle, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // List
                VStack(spacing: 16) {
                    ForEach(filteredDatabases) { db in
                        DatabaseRow(database: db, onDelete: {
                            viewModel.deleteDatabase(db)
                        }, onOpenDetails: {
                            selectedDatabase = db
                        })
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(ColorTokens.layer0)
        // Present Details Sheet
        .sheet(item: $selectedDatabase) { db in
            if let index = viewModel.databases.firstIndex(where: { $0.id == db.id }) {
                DatabaseDetailsView(database: $viewModel.databases[index])
            }
        }
    }
}

// MARK: - Type Tab
private struct TypeTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                    .padding(.horizontal, 12)
                
                Rectangle()
                    .fill(isSelected ? ColorTokens.accentPrimary : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Database Row

private struct DatabaseRow: View {
    
    let database: Database
    let onDelete: () -> Void
    let onOpenDetails: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onOpenDetails) {
            HStack(spacing: 16) {
            
            // Icon
            ZStack {
                Circle()
                    .fill(ColorTokens.layer2)
                    .frame(width: 40, height: 40)
                
                Image(systemName: database.type.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.accentSecondary)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(database.name)
                        .font(.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Text(database.type.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ColorTokens.layer2)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                
                HStack(spacing: 8) {
                    Text(database.sizeString)
                        .font(.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                    
                    Circle()
                        .fill(ColorTokens.borderSubtle)
                        .frame(width: 4, height: 4)
                    
                    Text(database.status.rawValue.capitalized)
                        .font(.subheadline)
                        .foregroundStyle(database.status.color)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button("Backup") {}
                    .buttonStyle(SecondaryButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.red)
                        .frame(width: 30, height: 30)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .opacity(isHovered ? 1 : 0.5)
        }
        .padding(16)
        .background(ColorTokens.layer1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
             RoundedRectangle(cornerRadius: 12)
                 .strokeBorder(isHovered ? ColorTokens.accentPrimary.opacity(0.3) : ColorTokens.borderSubtle, lineWidth: 1)
        )
        .onHover { hovering in
             withAnimation(.easeInOut(duration: 0.2)) {
                 isHovered = hovering
             }
        }
    }
    .buttonStyle(.plain)
    }
}

// MARK: - Secondary Button Style
private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ColorTokens.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ColorTokens.layer2.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
