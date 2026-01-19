//
//  DatabasesListView.swift
//  Velo
//
//  Databases Management View
//  List of databases with management options.
//

import SwiftUI
import Combine


struct DatabasesListView: View {
    
    @ObservedObject var viewModel: ServerManagementViewModel
    
    @State private var showingEditor = false
    @State private var editingDatabase: Database? = nil
    
    // State for Search & Filter
    @State private var searchText = ""
    @State private var selectedType: DatabaseType? = nil
    @State private var selectedDatabase: Database? = nil
    
    // For Deletion Confirmation
    @State private var showingDeleteAlert = false
    @State private var databaseToDelete: Database? = nil
    @State private var showingErrorAlert = false
    
    var filteredDatabases: [Database] {
        viewModel.databasesVM.databases.filter { db in
            let matchesSearch = searchText.isEmpty || db.name.localizedCaseInsensitiveContains(searchText)
            let matchesType = selectedType == nil || db.type == selectedType
            return matchesSearch && matchesType
        }
    }
    
    var body: some View {
        Group {
            // Main Content
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Tabs & Content
                VStack(spacing: 20) {
                    // Controls: Search & Tabs
                    VStack(spacing: 12) {
                        // Type Tabs (Top)
                        HStack(spacing: 0) {
                            TypeTab(title: "All", isSelected: selectedType == nil) {
                                selectedType = nil
                            }
                            
                            ForEach(DatabaseType.allCases, id: \.self) { type in
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
                    
                    // Content Area
                    contentArea
                }
            }
        }
        .background(ColorTokens.layer0)
        // Present Details Sheet
        .sheet(item: $selectedDatabase) { db in
            if let index = viewModel.databasesVM.databases.firstIndex(where: { $0.id == db.id }) {
                DatabaseDetailsView(
                    database: $viewModel.databasesVM.databases[index],
                    session: viewModel.session
                )
            }
        }
        // Present Edit Sheet
        .sheet(item: $editingDatabase) { db in
            DatabaseEditorView(viewModel: viewModel, database: db) { newDb in
                viewModel.updateDatabase(newDb)
            }
        }
        // Present Add Sheet
        .sheet(isPresented: $showingEditor) {
            DatabaseEditorView(viewModel: viewModel, database: nil) { newDb in
                Task {
                    _ = await viewModel.createRealDatabase(
                        name: newDb.name,
                        type: newDb.type,
                        username: newDb.username,
                        password: newDb.password
                    )
                }
            }
        }
        // Deletion Confirmation Alert
        .alert("Delete Database", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { databaseToDelete = nil }
            Button("Delete", role: .destructive) {
                if let db = databaseToDelete {
                    viewModel.securelyPerformAction(reason: "Confirm database deletion") {
                        Task {
                            await viewModel.deleteDatabase(db)
                        }
                    }
                }
                databaseToDelete = nil
            }
        } message: {
            if let db = databaseToDelete {
                Text("Are you sure you want to delete \(db.name)? All data will be permanently removed from the server.")
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
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Databases")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("\(viewModel.databasesVM.databases.count) databases managed on this server")
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
            .disabled(!canAddDatabase) // Disable if current type not installed
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
        .padding(.bottom, 20)
    }
    
    // MARK: - Content Area
    @ViewBuilder
    private var contentArea: some View {
        if let type = selectedType {
            // Specific Tab Selected
            if isInstalled(type) {
                // Installed -> Show List
                databaseList
            } else {
                // Not Installed -> Show Install View for this type
                DatabaseSetupView(viewModel: viewModel, targetType: type)
            }
        } else {
            // All Tab
            if viewModel.serverStatus.hasDatabase {
               databaseList
            } else {
               // No databases installed at all
               DatabaseSetupView(viewModel: viewModel, targetType: nil)
            }
        }
    }
    
    private var databaseList: some View {
        ScrollView {
            VStack(spacing: 16) {
                if filteredDatabases.isEmpty {
                    Text("No databases found")
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(.top, 40)
                } else {
                    ForEach(filteredDatabases) { db in
                        DatabaseRow(database: db, onBackup: {
                            Task {
                                if let backupPath = await viewModel.backupDatabase(db) {
                                    print("Backup saved to: \(backupPath)")
                                }
                            }
                        }, onEdit: {
                            editingDatabase = db
                            // Do NOT set showingEditor = true, as that triggers the Add sheet.
                            // The Edit sheet is triggered by editingDatabase being non-nil.
                        }, onDelete: {
                            databaseToDelete = db
                            showingDeleteAlert = true
                        }, onOpenDetails: {
                            selectedDatabase = db
                        })
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Helpers
    private func isInstalled(_ type: DatabaseType) -> Bool {
        switch type {
        case .mysql: return viewModel.databasesVM.hasMySQL
        case .postgres: return viewModel.databasesVM.hasPostgreSQL
        case .redis: return viewModel.databasesVM.hasRedis
        case .mongo: return viewModel.databasesVM.hasMongoDB
        }
    }
    
    private var canAddDatabase: Bool {
        if let type = selectedType {
            return isInstalled(type)
        }
        // If All, allow add if at least one is installed
        return viewModel.serverStatus.hasDatabase // or check individual flags
    }
}

// MARK: - Database Setup View

struct DatabaseSetupView: View {
    @ObservedObject var viewModel: ServerManagementViewModel
    var targetType: DatabaseType? // If specific tab selected
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 64))
                .foregroundStyle(ColorTokens.textTertiary)
            
            // Title
            VStack(spacing: 8) {
                Text(targetType == nil ? "No Database Installed" : "\(targetType!.rawValue) Not Installed")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Text(targetType == nil ? "Install a database to store your application data" : "Install \(targetType!.rawValue) to start using it")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            // Database Options
            HStack(spacing: 20) {
                if targetType == nil || targetType == .mysql {
                    DatabaseOptionCard(
                        name: "MySQL",
                        description: "Popular relational database",
                        color: .blue
                    ) { viewModel.installCapabilityBySlug("mysql") }
                }
                
                if targetType == nil || targetType == .postgres {
                    DatabaseOptionCard(
                        name: "PostgreSQL",
                        description: "Advanced open source DB",
                        color: .indigo
                    ) { viewModel.installCapabilityBySlug("postgresql") }
                }
                
                if targetType == nil || targetType == .redis {
                    DatabaseOptionCard(
                        name: "Redis",
                        description: "In-memory data store",
                        color: .red
                    ) { viewModel.installCapabilityBySlug("redis") }
                }
                
                if targetType == nil || targetType == .mongo {
                    DatabaseOptionCard(
                        name: "MongoDB",
                        description: "NoSQL database",
                        color: .green
                    ) { viewModel.installCapabilityBySlug("mongodb") }
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
    @ObservedObject var viewModel: ServerManagementViewModel
    let database: Database?
    let onSave: (Database) -> Void

    @State private var name: String = ""
    @State private var type: DatabaseType = .mysql
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Computed available types based on installed databases
    var availableTypes: [DatabaseType] {
        var types: [DatabaseType] = []
        if viewModel.databasesVM.hasMySQL { types.append(.mysql) }
        if viewModel.databasesVM.hasPostgreSQL { types.append(.postgres) }
        if viewModel.databasesVM.hasRedis { types.append(.redis) }
        if viewModel.databasesVM.hasMongoDB { types.append(.mongo) }
        
        // Default to all if nothing (should not happen due to Add button disabled logic, but safe fallback)
        if types.isEmpty {
            types = DatabaseType.allCases
        }
        return types
    }

    init(viewModel: ServerManagementViewModel, database: Database?, onSave: @escaping (Database) -> Void) {
        self.viewModel = viewModel
        self.database = database
        self.onSave = onSave
        _name = State(initialValue: database?.name ?? "")
        _type = State(initialValue: database?.type ?? .mysql)
        _username = State(initialValue: database?.username ?? "")
        _password = State(initialValue: database?.password ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text(database == nil ? "Add Database" : "Edit Database")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            VStack(spacing: 16) {
                VeloEditorField(label: "Database Name", placeholder: "my_database", text: $name)

                HStack(spacing: 16) {
                    VeloEditorField(label: "Username (optional)", placeholder: "db_user", text: $username)
                    VeloEditorField(label: "Password (optional)", placeholder: "••••••••", text: $password)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Database Type")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)

                    Picker("", selection: $type) {
                        ForEach(availableTypes, id: \.self) { dbType in
                            Text(dbType.rawValue).tag(dbType)
                        }
                    }
                    .pickerStyle(.segmented)

                    if database == nil {
                        Text("Only installed database types are shown")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .disabled(isSaving)

                Button(database == nil ? "Create Database" : "Save") {
                    saveDatabase()
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTokens.accentPrimary)
                .disabled(isSaving || name.isEmpty)
            }
        }
        .padding(32)
        .frame(width: 500, height: 460)
        .background(ColorTokens.layer1)
    }

    private func saveDatabase() {
        isSaving = true
        errorMessage = nil

        let newDb = Database(
            id: database?.id ?? UUID(),
            name: name,
            type: type,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            sizeBytes: database?.sizeBytes ?? 0,
            status: database?.status ?? .active
        )

        if database == nil {
            // Creating new database - use async SSH
            Task {
                let success = await viewModel.createRealDatabase(
                    name: newDb.name,
                    type: newDb.type,
                    username: newDb.username,
                    password: newDb.password
                )

                await MainActor.run {
                    isSaving = false
                    if success {
                        dismiss()
                    } else {
                        errorMessage = "Failed to create database on server"
                    }
                }
            }
        } else {
            // Editing existing - just update local state
            onSave(newDb)
            isSaving = false
            dismiss()
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
    let onBackup: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onOpenDetails: () -> Void
    @State private var isHovered = false
    @State private var isBackingUp = false
    
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
                Button(action: {
                    isBackingUp = true
                    onBackup()
                    // Reset after delay (backup runs async)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        isBackingUp = false
                    }
                }) {
                    HStack(spacing: 4) {
                        if isBackingUp {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                        Text(isBackingUp ? "Backing up..." : "Backup")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isBackingUp || database.type == .redis || database.type == .mongo)
                
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
