//
//  ServerLogsView.swift
//  Velo
//
//  Global Activity Logs View for Server Management.
//

import SwiftUI

struct ServerLogsView: View {
    @ObservedObject var viewModel: ServerManagementViewModel
    @StateObject private var logService = ServerLogService.shared
    
    @State private var selectedLogType = "System"
    @State private var logs: [String] = []
    @State private var isLoading = false
    
    let logTypes = ["System", "Nginx", "Apache", "MySQL", "PHP"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Selector
            HStack(spacing: 20) {
                ForEach(logTypes, id: \.self) { type in
                    Button(action: { 
                        selectedLogType = type
                        fetchLogs()
                    }) {
                        VStack(spacing: 8) {
                            Text(type)
                                .font(.system(size: 14, weight: selectedLogType == type ? .semibold : .regular))
                                .foregroundStyle(selectedLogType == type ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                            
                            Rectangle()
                                .fill(selectedLogType == type ? ColorTokens.accentPrimary : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: fetchLogs) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Refresh Logs")
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 12)
            .background(ColorTokens.layer0)
            
            Divider().background(ColorTokens.borderSubtle)
            
            // Log Content
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Analyzing logs...")
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(logs.indices, id: \.self) { index in
                            Text(logs[index])
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(logColor(for: logs[index]))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(index % 2 == 0 ? Color.white.opacity(0.02) : Color.clear)
                        }
                        
                        if logs.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 32))
                                    .foregroundStyle(ColorTokens.textTertiary)
                                Text("No logs found for \(selectedLogType)")
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .background(Color.black.opacity(0.2))
            }
        }
    }
    
    private func fetchLogs() {
        guard let session = viewModel.session else { return }
        
        isLoading = true
        Task {
            let path: String
            switch selectedLogType {
            case "Nginx": path = "/var/log/nginx/error.log"
            case "Apache": path = "/var/log/apache2/error.log"
            case "MySQL": path = "/var/log/mysql/error.log"
            case "PHP": path = "/var/log/php-fpm.log"
            default: path = "/var/log/syslog"
            }
            
            let fetchedLogs = await logService.fetchLogs(path: path, lines: 100, via: session)
            
            await MainActor.run {
                self.logs = fetchedLogs
                self.isLoading = false
            }
        }
    }
    
    private func logColor(for line: String) -> Color {
        let lower = line.lowercased()
        if lower.contains("error") || lower.contains("fail") || lower.contains("fatal") {
            return .red
        }
        if lower.contains("warn") {
            return .orange
        }
        if lower.contains("info") {
            return .blue
        }
        if lower.contains("success") || lower.contains("active") {
            return .green
        }
        return ColorTokens.textSecondary
    }
}
