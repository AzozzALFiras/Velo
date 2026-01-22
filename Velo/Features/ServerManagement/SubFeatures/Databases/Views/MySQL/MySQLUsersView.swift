import SwiftUI

struct MySQLUsersView: View {
    @ObservedObject var viewModel: MySQLDetailViewModel
    
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
                        MySQLUserRow(user: user)
                    }
                }
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

struct MySQLUserRow: View {
    let user: DatabaseUser
    
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.01))
    }
}
