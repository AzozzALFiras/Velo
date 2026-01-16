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
    
    @State private var showingEditor = false
    @State private var editingDatabase: Database? = nil
    
    // State for Search & Filter
    @State private var searchText = ""
    @State private var selectedType: Database.DatabaseType? = nil
    @State private var selectedDatabase: Database? = nil
    
    // For Deletion Confirmation
    @State private var showingDeleteAlert = false
    @State private var databaseToDelete: Database? = nil
    @State private var showingErrorAlert = false
    
    var filteredDatabases: [Database] {
        viewModel.databases.filter { db in
            let matchesSearch = searchText.isEmpty || db.name.localizedCaseInsensitiveContains(searchText)
            let matchesType = selectedType == nil || db.type == selectedType
            return matchesSearch && matchesType
        }
    }
    
    var body: some View {
        Group {
            // Check if any database is installed
            if viewModel.serverStatus.hasDatabase {
                databasesContent
            } else {
                DatabaseSetupView(viewModel: viewModel)
            }
        }
        .background(ColorTokens.layer0)
        // Present Details Sheet
        .sheet(item: $selectedDatabase) { db in
            if let index = viewModel.databases.firstIndex(where: { $0.id == db.id }) {
                DatabaseDetailsView(database: $viewModel.databases[index])
            }
        }
        // Present Editor Sheet
        .sheet(isPresented: $showingEditor) {
            DatabaseEditorView(database: editingDatabase) { newDb in
                if let _ = editingDatabase {
                    viewModel.updateDatabase(newDb)
                } else {
                    viewModel.addDatabase(newDb)
                }
            }
        }
        // Deletion Confirmation Alert
        .alert("Delete Database", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { databaseToDelete = nil }
            Button("Delete", role: .destructive) {
                if let db = databaseToDelete {
                    viewModel.securelyPerformAction(reason: "Confirm database deletion") {
                        viewModel.deleteDatabase(db)
                    }
                }
                databaseToDelete = nil
            }
        } message: {
            if let db = databaseToDelete {
                Text("Are you sure you want to delete \(db.name)? All data will be permanently removed.")
            }
        }
        // Authentication Error Alert
        .alert("Authentication Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .onChange(of: viewModel.errorMessage) { newValue in
            if newValue != nil {
                showingErrorAlert = true
            }
        }
        // Installation Progress Overlay
        .overlay(alignment: .bottomTrailing) {
            if viewModel.showInstallOverlay {
                InstallationStatusOverlay(viewModel: viewModel)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Databases Content
    @ViewBuilder
    private var databasesContent: some View {
        VStack(spacing: 0) {
            // Header with Add Button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Databases")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("\(viewModel.databases.count) databases managed on this server")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    editingDatabase = nil
                    showingEditor = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add Database")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ColorTokens.accentPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 20)

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
                    
                    // List
                    VStack(spacing: 16) {
                        ForEach(filteredDatabases) { db in
                            DatabaseRow(database: db, onEdit: {
                                editingDatabase = db
                                showingEditor = true
                            }, onDelete: {
                                databaseToDelete = db
                                showingDeleteAlert = true
                            }, onOpenDetails: {
                                selectedDatabase = db
                            })
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

// MARK: - Database Setup View

struct DatabaseSetupView: View {
    @ObservedObject var viewModel: ServerManagementViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 64))
                .foregroundStyle(ColorTokens.textTertiary)
            
            // Title
            VStack(spacing: 8) {
                Text("No Database Installed")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Text("Install a database to store your application data")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            // Database Options
            HStack(spacing: 20) {
                DatabaseOptionCard(
                    name: "MySQL",
                    description: "Popular relational database",
                    color: .blue
                ) {
                    viewModel.installCapabilityBySlug("mysql")
                }
                
                DatabaseOptionCard(
                    name: "MariaDB",
                    description: "MySQL-compatible fork",
                    color: .orange
                ) {
                    viewModel.installCapabilityBySlug("mariadb")
                }
                
                DatabaseOptionCard(
                    name: "PostgreSQL",
                    description: "Advanced open source DB",
                    color: .indigo
                ) {
                    viewModel.installCapabilityBySlug("postgresql")
                }
                
                DatabaseOptionCard(
                    name: "Redis",
                    description: "In-memory data store",
                    color: .red
                ) {
                    viewModel.installCapabilityBySlug("redis")
                }
            }
            
            Spacer()
        }
        .padding(32)
    }
}

// MARK: - Database Option Card

private struct DatabaseOptionCard: View {
    let name: String
    let description: String
    let color: Color
    let onInstall: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onInstall) {
            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "cylinder.split.1x2")
                        .font(.system(size: 28))
                        .foregroundStyle(color)
                }
                
                // Name & Description
                VStack(spacing: 4) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                // Install Button
                Text("Install")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(color)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(20)
            .frame(width: 180)
            .background(ColorTokens.layer1)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isHovered ? color.opacity(0.5) : ColorTokens.borderSubtle, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Database Editor View

struct DatabaseEditorView: View {
    @Environment(\.dismiss) var dismiss
    let database: Database?
    let onSave: (Database) -> Void
    
    @State private var name: String = ""
    @State private var type: Database.DatabaseType = .mysql
    @State private var username: String = ""
    @State private var password: String = ""
    
    init(database: Database?, onSave: @escaping (Database) -> Void) {
        self.database = database
        self.onSave = onSave
        _name = State(initialValue: database?.name ?? "")
        _type = State(initialValue: database?.type ?? .mysql)
        _username = State(initialValue: database?.username ?? "")
        _password = State(initialValue: database?.password ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(database == nil ? "Add Database" : "Edit Database")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(ColorTokens.textPrimary)
            
            VStack(spacing: 16) {
                VeloEditorField(label: "Database Name", placeholder: "my_database", text: $name)
                
                HStack(spacing: 16) {
                    VeloEditorField(label: "Username", placeholder: "db_user", text: $username)
                    VeloEditorField(label: "Password", placeholder: "••••••••", text: $password)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Database Type")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)
                    
                    Picker("", selection: $type) {
                        ForEach(Database.DatabaseType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(ColorTokens.textSecondary)
                
                Button("Save") {
                    let newDb = Database(
                        id: database?.id ?? UUID(),
                        name: name,
                        type: type,
                        username: username.isEmpty ? nil : username,
                        password: password.isEmpty ? nil : password,
                        sizeBytes: database?.sizeBytes ?? 0,
                        status: database?.status ?? .active
                    )
                    onSave(newDb)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTokens.accentPrimary)
            }
        }
        .padding(32)
        .frame(width: 500, height: 420)
        .background(ColorTokens.layer1)
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
    let onEdit: () -> Void
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
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color.blue)
                        .frame(width: 30, height: 30)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                
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
