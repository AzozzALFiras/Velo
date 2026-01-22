//
//  UnifiedSecuritySectionView.swift
//  Velo
//
//  Unified security/WAF view for web servers.
//

import SwiftUI

struct UnifiedSecuritySectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Security Stats
            statsCard

            // Security Rules Status
            rulesStatusSection
        }
    }

    private var statsCard: some View {
        HStack(spacing: 24) {
            statItem(title: "Total Blocked", value: state.securityStats.total, icon: "shield.lefthalf.filled", color: .orange)
            statItem(title: "Last 24h", value: state.securityStats.last24h, icon: "clock", color: .blue)
        }
        .padding(20)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
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
    }

    private var rulesStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Security Features")
                .font(.headline)
                .foregroundStyle(.white)

            if state.securityRulesStatus.isEmpty {
                emptySecurityView
            } else {
                ForEach(Array(state.securityRulesStatus.keys.sorted()), id: \.self) { key in
                    securityRuleRow(name: key, isEnabled: state.securityRulesStatus[key] ?? false)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptySecurityView: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.slash")
                .font(.system(size: 40))
                .foregroundStyle(.gray)

            Text("No security features detected")
                .font(.subheadline)
                .foregroundStyle(.gray)

            Text("Consider installing ModSecurity or similar WAF")
                .font(.caption)
                .foregroundStyle(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func securityRuleRow(name: String, isEnabled: Bool) -> some View {
        HStack {
            Image(systemName: isEnabled ? "checkmark.shield.fill" : "shield.slash")
                .foregroundStyle(isEnabled ? .green : .gray)
                .frame(width: 24)

            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            Text(isEnabled ? "Enabled" : "Disabled")
                .font(.caption)
                .foregroundStyle(isEnabled ? .green : .gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((isEnabled ? Color.green : Color.gray).opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
