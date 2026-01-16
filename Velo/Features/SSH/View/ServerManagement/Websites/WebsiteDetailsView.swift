//
//  WebsiteDetailsView.swift
//  Velo
//
//  Details View for a specific Website
//  Includes Overview, Settings, and Logs tabs.
//

import SwiftUI

struct WebsiteDetailsView: View {
    
    @Binding var website: Website
    @Environment(\.dismiss) var dismiss
    
    @State private var activeTab = "Overview"
    @State private var domainEdit = ""
    @State private var pathEdit = ""
    
    // Mock Logs
    let logs = [
        "[2024-01-15 10:00:01] [INFO] Server started on port 8080",
        "[2024-01-15 10:05:23] [WARN] High memory usage detected",
        "[2024-01-15 10:12:00] [INFO] Request received /api/v1/status",
        "[2024-01-15 10:15:00] [INFO] Worker process spawned",
        "[2024-01-15 10:20:42] [ERROR] Connection timeout: db_primary",
        "[2024-01-15 10:21:00] [INFO] Auto-restarting worker..."
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Header
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.layer2)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "globe")
                        .font(.title2)
                        .foregroundStyle(ColorTokens.accentPrimary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(website.domain)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    HStack {
                        Circle()
                            .fill(website.status.color)
                            .frame(width: 8, height: 8)
                        Text(website.status.title)
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
                ForEach(["Overview", "Settings", "Logs"], id: \.self) { tab in
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
                    if activeTab == "Overview" {
                        overviewTab
                    } else if activeTab == "Settings" {
                        settingsTab
                    } else if activeTab == "Logs" {
                        logsTab
                    }
                }
                .padding(20)
            }
            
        }
        .frame(width: 500, height: 600)
        .background(ColorTokens.layer0)
        .onAppear {
            domainEdit = website.domain
            pathEdit = website.path
        }
    }
    
    // MARK: - Tabs
    
    var overviewTab: some View {
        VStack(spacing: 16) {
            InfoRow(label: "Framework", value: website.framework)
            InfoRow(label: "Port", value: "\(website.port)")
            InfoRow(label: "Path", value: website.path)
            
            Divider().background(ColorTokens.borderSubtle)
            
            HStack(spacing: 12) {
                ActionButton(title: "Restart Service", icon: "arrow.clockwise", color: .blue) {}
                ActionButton(title: "Clear Cache", icon: "trash", color: .orange) {}
            }
        }
        .padding()
        .background(ColorTokens.layer1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    var settingsTab: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Domain")
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                TextField("Domain", text: $domainEdit)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(ColorTokens.layer2)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Server Path")
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                TextField("Path", text: $pathEdit)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(ColorTokens.layer2)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            Button("Save Changes") {
                website.domain = domainEdit
                website.path = pathEdit
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 10)
        }
        .padding()
        .background(ColorTokens.layer1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    var logsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(logs, id: \.self) { log in
                Text(log)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(log.contains("[ERROR]") ? Color.red.opacity(0.1) : Color.clear)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(ColorTokens.layer1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Components

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(ColorTokens.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(ColorTokens.textPrimary)
        }
    }
}

private struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(ColorTokens.accentPrimary)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
