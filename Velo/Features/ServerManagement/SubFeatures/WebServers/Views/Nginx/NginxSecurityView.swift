import SwiftUI

struct NginxSecurityView: View {
    @ObservedObject var viewModel: NginxDetailViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Firewall & WAF")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("Configure security rules to protect your web server.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                // Status Overview
                HStack(spacing: 20) {
                    statusCard(title: "Total Attacks Blocked", value: viewModel.securityStats.total, color: .green)
                    statusCard(title: "Last 24h Blocks", value: viewModel.securityStats.last24h, color: .blue)
                    statusCard(title: "WAF Status", value: "Active", color: .purple)
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Security Rules List
                VStack(spacing: 16) {
                    Text("Security Rules")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // CC Defense
                    ruleToggleRow(
                        title: "CC Defense",
                        description: "Mitigate HTTP flood and Challenge Collapsar attacks.",
                        key: "CC_DEFENSE",
                        actionCode: "444"
                    )
                    
                    // SQL Injection
                    ruleToggleRow(
                        title: "SQL Injection Protection",
                        description: "Filter URI parameters for common SQL injection patterns.",
                        key: "SQL_INJECTION",
                        actionCode: "403"
                    )
                    
                    // XSS
                    ruleToggleRow(
                        title: "XSS Protection",
                        description: "Block Cross-Site Scripting attempts in parameters.",
                        key: "XSS_PROTECTION",
                        actionCode: "403"
                    )
                    
                    // Scanner
                    ruleToggleRow(
                        title: "Anti-Scanner",
                        description: "Block known vulnerability scanners and botnets.",
                        key: "ANTI_SCANNER",
                        actionCode: "444"
                    )
                    
                    // UA Filter
                    ruleToggleRow(
                        title: "User-Agent Filtering",
                        description: "Block requests from blacklisted User-Agents.",
                        key: "UA_FILTER",
                        actionCode: "403"
                    )
                }
                .padding()
                .background(Color.white.opacity(0.02))
                .cornerRadius(12)
                
                // IP Setup
                VStack(alignment: .leading, spacing: 16) {
                    Text("Access Control")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack {
                        actionButton(title: "Manage IP Whitelist", icon: "list.bullet.clipboard")
                        actionButton(title: "Manage IP Blacklist", icon: "hand.raised.fill")
                    }
                }
                .padding()
                .background(Color.white.opacity(0.02))
                .cornerRadius(12)
                
            }
            .padding()
        }
        .onAppear {
            Task {
                await viewModel.loadSecurityStatus()
            }
        }
    }
    
    // MARK: - Components
    
    private func statusCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.gray)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func ruleToggleRow(title: String, description: String, key: String, actionCode: String) -> some View {
        let binding = Binding<Bool>(
            get: { viewModel.securityRulesStatus[key] ?? false },
            set: { newValue in
                Task {
                    await viewModel.toggleSecurityRule(key, enabled: newValue)
                }
            }
        )
        
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Inter", size: 14)) // Assuming font existence or generic
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            Text("Response: \(actionCode)")
                .font(.caption2)
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.1))
                .cornerRadius(4)
                .padding(.trailing, 8)
            
            Toggle("", isOn: binding)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .green))
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
    
    private func actionButton(title: String, icon: String) -> some View {
        Button {
            // Action placeholder
        } label: {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
