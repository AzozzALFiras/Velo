//
//  UnifiedFPMProfileSectionView.swift
//  Velo
//
//  Unified PHP-FPM pool configuration view.
//

import SwiftUI

struct UnifiedFPMProfileSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // FPM Status Card
            if let fpmStatus = state.fpmStatus {
                fpmStatusCard(fpmStatus)
            }

            // Pool Configuration
            poolConfigSection
        }
    }

    private func fpmStatusCard(_ status: PHPFPMStatus) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FPM Status")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                statusMetric(title: "Pool", value: status.pool, icon: "square.grid.2x2")
                statusMetric(title: "Manager", value: status.processManager, icon: "gearshape.2")
                statusMetric(title: "Active", value: "\(status.activeProcesses)", icon: "bolt.fill")
                statusMetric(title: "Idle", value: "\(status.idleProcesses)", icon: "moon")
                statusMetric(title: "Total", value: "\(status.totalProcesses)", icon: "sum")
                statusMetric(title: "Accepted", value: "\(status.acceptedConnections)", icon: "checkmark.circle")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusMetric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: app.themeColor) ?? .purple)
                .frame(width: 32, height: 32)
                .background((Color(hex: app.themeColor) ?? .purple).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.gray)

                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var poolConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pool Configuration")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    Task {
                        await viewModel.loadSectionData()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            if state.fpmProfileContent.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray)

                    Text("Pool configuration not found")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView {
                    Text(state.fpmProfileContent)
                        .font(.custom("Menlo", size: 11))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(16)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxHeight: 400)
            }
        }
    }
}
