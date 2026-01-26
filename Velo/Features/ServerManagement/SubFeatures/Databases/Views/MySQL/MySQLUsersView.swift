import SwiftUI

struct MySQLUsersView: View {
    @ObservedObject var viewModel: MySQLDetailViewModel
    
    @State private var showingDeleteAlert = false
    @State private var userToDelete: DatabaseUser?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Header
            HStack {
                Text("Database Users")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    Task { await viewModel.loadUsers() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
            }
            
            if viewModel.isLoadingUsers {
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
                .padding(40)
            } else if viewModel.users.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.gray.opacity(0.3))
                    Text("No users found or access denied.")
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                VStack(spacing: 1) {
                    ForEach(viewModel.users) { user in
                        MySQLUserRow(
                            user: user,
                            onDelete: {
                                userToDelete = user
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert(
            "Delete User?",
            isPresented: $showingDeleteAlert,
            presenting: userToDelete
        ) { user in
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteUser(user.username)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { user in
            Text("Are you sure you want to delete user '\(user.username)'? This action cannot be undone.")
        }
    }
}

struct MySQLUserRow: View {
    let user: DatabaseUser
    var onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "person.fill")
                .foregroundStyle(.blue.opacity(0.8))
                .frame(width: 32, height: 32)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(user.host)
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            // Permissions indicator (simplified)
            Text(user.username == "root" ? "Superuser" : "User")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(user.username == "root" ? .orange : .gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((user.username == "root" ? Color.orange : Color.gray).opacity(0.1))
                .clipShape(Capsule())
            
            // Delete Action
            if user.username != "root" && user.username != "mysql.session" && user.username != "mysql.sys" && user.username != "debian-sys-maint" {
                 Button(action: onDelete) {
                     Image(systemName: "trash")
                         .foregroundStyle(.red.opacity(0.7))
                         .font(.system(size: 12))
                         .frame(width: 24, height: 24)
                         .background(Color.red.opacity(0.1))
                         .clipShape(Circle())
                 }
                 .buttonStyle(.plain)
                 .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.01))
    }
}
