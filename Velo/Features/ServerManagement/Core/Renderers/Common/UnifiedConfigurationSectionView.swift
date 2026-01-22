//
//  UnifiedConfigurationSectionView.swift
//  Velo
//
//  Unified key-value configuration view for all applications.
//

import SwiftUI

struct UnifiedConfigurationSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Configuration Settings")
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

            if state.configValues.isEmpty {
                emptyStateView
            } else {
                configValuesGrid
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 40))
                .foregroundStyle(.gray)

            Text("No configuration values found")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var configValuesGrid: some View {
        LazyVStack(spacing: 12) {
            ForEach(state.configValues) { config in
                ConfigValueRow(
                    config: config,
                    themeColor: Color(hex: app.themeColor) ?? .blue,
                    onSave: { newValue in
                        Task {
                            await viewModel.updateConfigValue(config.key, to: newValue)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Config Value Row

struct ConfigValueRow: View {
    let config: SharedConfigValue
    let themeColor: Color
    let onSave: (String) -> Void

    @State private var isEditing = false
    @State private var editedValue: String = ""

    var body: some View {
        HStack(spacing: 16) {
            // Key info
            VStack(alignment: .leading, spacing: 4) {
                Text(config.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)

                Text(config.description)
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .lineLimit(2)
            }

            Spacer()

            // Value
            if isEditing {
                HStack(spacing: 8) {
                    TextField("", text: $editedValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .frame(width: 150)

                    Button {
                        onSave(editedValue)
                        isEditing = false
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)

                    Button {
                        isEditing = false
                        editedValue = config.value
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    editedValue = config.value
                    isEditing = true
                } label: {
                    HStack(spacing: 8) {
                        Text(config.value)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(themeColor)

                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(themeColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
