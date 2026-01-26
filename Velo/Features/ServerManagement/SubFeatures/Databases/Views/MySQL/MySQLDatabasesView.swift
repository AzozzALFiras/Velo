import SwiftUI

struct MySQLDatabasesView: View {
    @ObservedObject var viewModel: MySQLDetailViewModel
    
    @State private var showingAddSheet = false
    @State private var newDbName = ""
    @State private var newDbCharSet = "utf8mb4"
    @State private var newDbCollate = "utf8mb4_unicode_ci"
    
    // Deletion
    @State private var showingDeleteAlert = false
    @State private var dbToDelete: Database?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Header
            HStack {
                Text("Databases")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    Task { await viewModel.loadDatabases() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
                
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            
            if viewModel.isLoadingDatabases {
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
                .padding(40)
            } else if viewModel.databases.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.largeTitle)
                        .foregroundStyle(.gray.opacity(0.3))
                    Text("No databases found.")
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                VStack(spacing: 1) {
                    ForEach(viewModel.databases, id: \.name) { db in
                        MySQLDatabaseRow(
                            database: db,
                            onDelete: {
                                dbToDelete = db
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            addDatabaseSheet
        }
        .alert(
            "Delete Database?",
            isPresented: $showingDeleteAlert,
            presenting: dbToDelete
        ) { db in
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteDatabase(db.name)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { db in
            Text("Are you sure you want to delete '\(db.name)'? This action cannot be undone.")
        }
    }
    
    private var addDatabaseSheet: some View {
        VStack(spacing: 20) {
            Text("Create Database")
                .font(.headline)
            
            TextField("Database Name", text: $newDbName)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") { showingAddSheet = false }
                Spacer()
                Button("Create") {
                    if !newDbName.isEmpty {
                        Task {
                            await viewModel.createDatabase(name: newDbName)
                            showingAddSheet = false
                            newDbName = ""
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newDbName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct MySQLDatabaseRow: View {
    let database: Database
    var onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "cylinder.split.1x2.fill")
                .foregroundStyle(.indigo.opacity(0.8))
                .frame(width: 32, height: 32)
                .background(Color.indigo.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(database.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(formatSize(database.sizeBytes))
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            // Actions
            if !isSystemDatabase(database.name) {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.7))
                        .font(.system(size: 12))
                        .frame(width: 24, height: 24)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Text("SYSTEM")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.01))
    }
    
    private func isSystemDatabase(_ name: String) -> Bool {
        let sys = ["information_schema", "mysql", "performance_schema", "sys"]
        return sys.contains(name.lowercased())
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
