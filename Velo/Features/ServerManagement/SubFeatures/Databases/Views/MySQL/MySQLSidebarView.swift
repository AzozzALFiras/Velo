import SwiftUI

struct MySQLSidebarView: View {
    @ObservedObject var viewModel: MySQLDetailViewModel
    var onDismiss: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Close Button
            Button {
                onDismiss?()
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back to Server")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(24)
            
            // Header
            HStack(spacing: 12) {
                Image(systemName: "cylinder.split.1x2.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("MySQL")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(viewModel.isRunning ? "Running" : "Stopped")
                        .font(.caption)
                        .foregroundStyle(viewModel.isRunning ? .green : .red)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            
            // Sections
            VStack(spacing: 4) {
                ForEach(MySQLDetailSection.allCases) { section in
                    SidebarItemView(
                        title: section.rawValue,
                        icon: section.icon,
                        isSelected: viewModel.selectedSection == section
                    ) {
                        viewModel.selectedSection = section
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            // Footer Info
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Version", value: viewModel.version)
                InfoRow(label: "Config", value: viewModel.configPath.split(separator: "/").last.map(String.init) ?? "my.cnf")
            }
            .padding(24)
            .background(Color.white.opacity(0.02))
        }
        .frame(width: 240)
        .background(Color.white.opacity(0.03))
    }
}

private struct SidebarItemView: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 4, height: 4)
                }
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.gray)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
    }
}
