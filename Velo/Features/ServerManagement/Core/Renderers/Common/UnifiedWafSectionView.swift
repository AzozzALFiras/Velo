
import SwiftUI

struct UnifiedWafSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    // Filters
    @State private var statusFilter: String = "All"
    @State private var sortDescending: Bool = true
    
    // Selection
    @State private var selectedEntry: WafLogEntry?
    
    // Derived Data
    var filteredLogs: [WafLogEntry] {
        var logs = state.wafLogs
        
        // Filter
        if statusFilter != "All" {
            if statusFilter == "Errors (4xx/5xx)" {
                logs = logs.filter { $0.status.hasPrefix("4") || $0.status.hasPrefix("5") }
            } else {
                let prefix = String(statusFilter.prefix(1))
                logs = logs.filter { $0.status.hasPrefix(prefix) }
            }
        }
        
        // Sort
        if !sortDescending {
            logs.reverse()
        }
        
        return logs
    }

    var body: some View {
        VStack(spacing: 16) {
            // Control Bar
            HStack {
                Text("Traffic & WAF Logs")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Filters
                Picker("Status", selection: $statusFilter) {
                    Text("All Requests").tag("All")
                    Text("Success (2xx)").tag("2xx")
                    Text("Redirects (3xx)").tag("3xx")
                    Text("Client Errors (4xx)").tag("4xx")
                    Text("Server Errors (5xx)").tag("5xx")
                    Text("All Errors").tag("Errors (4xx/5xx)")
                }
                .frame(width: 150)
                
                Button {
                    sortDescending.toggle()
                } label: {
                    Image(systemName: sortDescending ? "arrow.down" : "arrow.up")
                        .help("Sync Time: \(sortDescending ? "Newest First" : "Oldest First")")
                }
                .buttonStyle(.plain)
                .padding(6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
                
                // Site Picker
                Picker("Site", selection: $state.currentWafSite) {
                    ForEach(state.wafSites, id: \.self) { site in
                        Text(site).tag(site)
                    }
                }
                .frame(width: 180)
                .onChange(of: state.currentWafSite) { _ in
                    Task { await viewModel.loadSectionData() }
                }
                
                Button {
                    Task { await viewModel.loadSectionData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            // Stats Overview
            HStack(spacing: 16) {
                statCard(title: "Requests", value: "\(state.wafLogs.count)", icon: "list.bullet", color: .blue)
                statCard(title: "4xx Errors", value: countStatus(prefix: "4"), icon: "exclamationmark.triangle", color: .orange)
                 statCard(title: "5xx Errors", value: countStatus(prefix: "5"), icon: "xmark.octagon", color: .red)
            }
            
            // Logs Table
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("IP Address").frame(width: 120, alignment: .leading)
                    Text("Status").frame(width: 60, alignment: .leading)
                    Text("Method").frame(width: 60, alignment: .leading)
                    Text("Path").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Time").frame(width: 160, alignment: .leading)
                }
                .font(.caption)
                .foregroundStyle(.gray)
                .padding()
                .background(Color.black.opacity(0.2))
                
                if filteredLogs.isEmpty {
                    Text("No logs found matching filters")
                        .foregroundStyle(.gray)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredLogs) { log in
                                logRow(log)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedEntry = log
                                    }
                            }
                        }
                    }
                }
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(Color.white.opacity(0.05)),
                alignment: .bottom
            )
            .overlay(
                  Rectangle()
                      .frame(height: 1)
                      .foregroundStyle(Color.white.opacity(0.05)),
                  alignment: .bottom
              )
        }
        .padding()
        .sheet(item: $selectedEntry) { entry in
            LogDetailsView(entry: entry, viewModel: viewModel)
        }
    }
    
    private func logRow(_ log: WafLogEntry) -> some View {
        let (method, path) = parseRequest(log.request)
        
        return HStack {
            Text(log.ip)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.yellow)
                .frame(width: 120, alignment: .leading)
            
            Text(log.status)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(statusColor(log.status))
                .frame(width: 60, alignment: .leading)
            
            Text(method)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.purple)
                .frame(width: 60, alignment: .leading)
            
            Text(path)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(log.time)
                .font(.caption2)
                .foregroundStyle(.gray)
                .frame(width: 160, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.02))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.white.opacity(0.05)),
            alignment: .bottom
        )
    }
    
    private func parseRequest(_ request: String) -> (String, String) {
        let parts = request.components(separatedBy: " ")
        if parts.count >= 2 {
            return (parts[0], parts[1])
        }
        return ("REQ", request)
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func countStatus(prefix: String) -> String {
        return "\(state.wafLogs.filter { $0.status.hasPrefix(prefix) }.count)"
    }
    
    private func statusColor(_ status: String) -> Color {
        if status.hasPrefix("2") { return .green }
        if status.hasPrefix("3") { return .blue }
        if status.hasPrefix("4") { return .orange }
        if status.hasPrefix("5") { return .red }
        return .white
    }
}

// MARK: - Detail Sheet

struct LogDetailsView: View {
    let entry: WafLogEntry
    let viewModel: ApplicationDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Request Details")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black.opacity(0.2))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Main Info
                    HStack(spacing: 16) {
                        detailBox(label: "IP Address", value: entry.ip, actionIcon: "doc.on.doc", action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(entry.ip, forType: .string)
                        })
                        
                        detailBox(label: "Status", value: entry.status)
                        detailBox(label: "Time", value: entry.time)
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // Request info
                    detailRow(label: "Full Request", value: entry.request)
                    detailRow(label: "User Agent", value: entry.userAgent)
                    detailRow(label: "Referrer", value: entry.referrer)
                    detailRow(label: "Response Size", value: "\(entry.bytes) bytes")
                    
                    if entry.country != "Unknown" {
                         detailRow(label: "Country", value: entry.country)
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Payload / Body")
                             .font(.caption)
                             .foregroundStyle(.gray)
                        
                        Text("Note: POST body content is not recorded in standard Nginx access logs. Enable ModSecurity or custom logging to capture payloads.")
                             .font(.caption2)
                             .foregroundStyle(.orange)
                             .padding()
                             .background(Color.orange.opacity(0.1))
                             .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Actions
                    HStack {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(entry.ip, forType: .string)
                        } label: {
                            Label("Copy IP", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            Task {
                                _ = await viewModel.blockIP(entry.ip)
                                // Ideally dismiss after delay or show success in parent
                            }
                        } label: {
                            Label("Block IP", systemImage: "hand.raised.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private func detailBox(label: String, value: String, actionIcon: String? = nil, action: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.gray)
            
            HStack {
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                
                if let icon = actionIcon, let action = action {
                    Button(action: action) {
                        Image(systemName: icon)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.gray)
            
            Text(value)
                .elementSelectable() // Helper if exists, or regular Text
                .font(.system(.body, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
        }
    }
}

extension View {
    // Helper helper
    func elementSelectable() -> some View {
        self.textSelection(.enabled)
    }
}
