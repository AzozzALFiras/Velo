//
//  UnifiedPHPInfoSectionView.swift
//  Velo
//
//  Unified PHP info view.
//

import SwiftUI

struct UnifiedPHPInfoSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Key PHP Info
            infoCardsSection

            // Full phpinfo() output
            fullPhpInfoSection
        }
    }

    private var infoCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PHP Configuration")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(state.phpInfoData.keys.sorted()), id: \.self) { key in
                    if let value = state.phpInfoData[key] {
                        infoCard(title: key, value: value)
                    }
                }
            }
        }
    }

    private func infoCard(title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForKey(title))
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: app.themeColor) ?? .purple)
                .frame(width: 32, height: 32)
                .background((Color(hex: app.themeColor) ?? .purple).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.gray)

                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func iconForKey(_ key: String) -> String {
        switch key.lowercased() {
        case let k where k.contains("version"): return "number"
        case let k where k.contains("memory"): return "memorychip"
        case let k where k.contains("time"): return "clock"
        case let k where k.contains("upload"): return "arrow.up.doc"
        case let k where k.contains("file"): return "doc.text"
        case let k where k.contains("zone"): return "globe"
        case let k where k.contains("error"): return "exclamationmark.triangle"
        case let k where k.contains("sapi"): return "server.rack"
        case let k where k.contains("zend"): return "cpu"
        default: return "info.circle"
        }
    }

    private var fullPhpInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Full PHP Info Output")
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

            if state.phpInfoHTML.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)

                    Text("Loading PHP info...")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView {
                    Text(state.phpInfoHTML)
                        .font(.custom("Menlo", size: 10))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(16)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxHeight: 500)
            }
        }
    }
}
