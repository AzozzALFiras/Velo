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
    let session: TerminalViewModel?
    @Environment(\.dismiss) var dismiss
    
    @State private var activeTab = "Overview"
    @State private var domainEdit = ""
    @State private var pathEdit = ""
    
    // Security
    @State private var errorMessage: String? = nil
    @State private var showingErrorAlert = false
    
    // Logs
    @State private var logs: [String] = ["Loading logs..."]
    @State private var isLoadingLogs = false
    @EnvironmentObject var aggregator: ServerServiceAggregator
    let logService = ServerLogService.shared
    
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
                    Button(action: { 
                        activeTab = tab 
                        if tab == "Logs" {
                            fetchRealLogs()
                        }
                    }) {
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
        .alert("Authentication Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
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
                ActionButton(title: "Clear Cache", icon: "trash", color: .orange) {
                    SecurityManager.shared.securelyPerformAction(reason: "Clear cache for \(website.domain)") {
                        // Action: Clear Cache
                        print("Cache cleared for \(website.domain)")
                    } onError: { error in
                        self.errorMessage = error
                        self.showingErrorAlert = true
                    }
                }
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
            if isLoadingLogs {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(logs, id: \.self) { log in
                    Text(log)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(log.contains("[ERROR]") || log.contains("error") ? Color.red.opacity(0.1) : Color.clear)
                        .cornerRadius(4)
                }
                
                if logs.isEmpty {
                    Text("No logs available")
                        .font(.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                
                Button(action: fetchRealLogs) {
                    Label("Refresh Logs", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .padding()
        .background(ColorTokens.layer1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func fetchRealLogs() {
        guard let session = session else { return }
        
        isLoadingLogs = true
        Task {
            // Determine log path based on web server
            // Using Nginx as primary, placeholder for now
            let logPath = "/var/log/nginx/error.log" 
            let fetchedLogs = await logService.fetchLogs(path: logPath, via: session)
            
            await MainActor.run {
                self.logs = fetchedLogs
                self.isLoadingLogs = false
            }
        }
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
