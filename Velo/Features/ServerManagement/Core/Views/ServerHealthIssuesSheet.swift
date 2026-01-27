//
//  ServerHealthIssuesSheet.swift
//  Velo
//
//  Sheet displaying detected server health issues with auto-fix option.
//

import SwiftUI

struct ServerHealthIssuesSheet: View {
    @ObservedObject var healthService: ServerHealthCheckService
    @Binding var isPresented: Bool
    let session: TerminalViewModel?
    
    @State private var fixResult: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if healthService.isChecking {
                checkingView
            } else if healthService.isFixing {
                fixingView
            } else if healthService.detectedIssues.isEmpty {
                noIssuesView
            } else {
                issuesListView
            }
            
            Divider()
            
            // Footer Actions
            footerView
        }
        .frame(width: 550, height: 450)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "stethoscope")
                .font(.title2)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Server Health Check")
                    .font(.headline)
                
                if let date = healthService.lastCheckDate {
                    Text("Last checked: \(date.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Refresh button
            Button {
                Task {
                    if let session = session {
                        await healthService.runAllChecks(via: session)
                    }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(healthService.isChecking || healthService.isFixing)
        }
        .padding()
    }
    
    // MARK: - Checking View
    
    private var checkingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Checking server health...")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Fixing View
    
    private var fixingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text(healthService.fixProgress.isEmpty ? "Applying fixes..." : healthService.fixProgress)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
    
    // MARK: - No Issues View
    
    private var noIssuesView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Server is Healthy")
                .font(.title3)
                .fontWeight(.medium)
            Text("No issues detected")
                .foregroundStyle(.secondary)
            
            if let result = fixResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.top, 8)
            }
            Spacer()
        }
    }
    
    // MARK: - Issues List
    
    private var issuesListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedIssues) { issue in
                    IssueRowView(issue: issue)
                    
                    if issue.id != sortedIssues.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var sortedIssues: [HealthCheckIssue] {
        healthService.detectedIssues.sorted { lhs, rhs in
            let severityOrder: [HealthCheckIssue.Severity] = [.critical, .warning, .info]
            let lhsIndex = severityOrder.firstIndex(of: lhs.severity) ?? 0
            let rhsIndex = severityOrder.firstIndex(of: rhs.severity) ?? 0
            return lhsIndex < rhsIndex
        }
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            // Issue count summary
            if !healthService.detectedIssues.isEmpty {
                issueSummary
            }
            
            Spacer()
            
            // Dismiss button
            Button("Dismiss") {
                isPresented = false
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            
            // Auto-fix button
            let fixableCount = healthService.detectedIssues.filter(\.canAutoFix).count
            if fixableCount > 0 {
                Button {
                    Task {
                        if let session = session {
                            let fixed = await healthService.autoFixAll(via: session)
                            // Check if only info-level issues remain
                            let hasImportantIssues = healthService.detectedIssues.contains { 
                                $0.severity == .critical || $0.severity == .warning 
                            }
                            if !hasImportantIssues {
                                fixResult = "\(fixed) issue(s) fixed successfully!"
                                // Auto-close after short delay if all important issues fixed
                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                isPresented = false
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver")
                        Text("Auto-Fix (\(fixableCount))")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(healthService.isFixing || session == nil)
            }
        }
        .padding()
    }
    
    private var issueSummary: some View {
        HStack(spacing: 12) {
            let criticalCount = healthService.detectedIssues.filter { $0.severity == .critical }.count
            let warningCount = healthService.detectedIssues.filter { $0.severity == .warning }.count
            let infoCount = healthService.detectedIssues.filter { $0.severity == .info }.count
            
            if criticalCount > 0 {
                Label("\(criticalCount)", systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            if warningCount > 0 {
                Label("\(warningCount)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }
            if infoCount > 0 {
                Label("\(infoCount)", systemImage: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Issue Row View

private struct IssueRowView: View {
    let issue: HealthCheckIssue
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Severity Icon
            Image(systemName: issue.severity.icon)
                .font(.title3)
                .foregroundStyle(severityColor)
                .frame(width: 28)
            
            // Issue Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(issue.title)
                        .fontWeight(.medium)
                    
                    if issue.canAutoFix {
                        Text("Auto-fixable")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
                
                Text(issue.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                if let fixDesc = issue.fixDescription {
                    HStack(spacing: 4) {
                        Image(systemName: "wrench")
                            .font(.caption2)
                        Text(fixDesc)
                            .font(.caption2)
                    }
                    .foregroundStyle(.green)
                    .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
    
    private var severityColor: Color {
        switch issue.severity {
        case .critical: return .red
        case .warning: return .yellow
        case .info: return .blue
        }
    }
}

// MARK: - Preview

#Preview {
    ServerHealthIssuesSheet(
        healthService: ServerHealthCheckService.shared,
        isPresented: .constant(true),
        session: nil
    )
}
