//
//  UnifiedConfigFileSectionView.swift
//  Velo
//
//  Unified config file editor for all applications.
//

import SwiftUI

struct UnifiedConfigFileSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with path and actions
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configuration File")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(state.configPath)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.loadSectionData()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Reload")
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    if isEditing {
                        Button {
                            Task {
                                await viewModel.saveConfigFile()
                                isEditing = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                Text("Save")
                            }
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isPerformingAction)
                    }
                }
            }

            // Config file content
            if isEditing {
                TextEditor(text: $state.configFileContent)
                    .font(.custom("Menlo", size: 12))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.orange.opacity(0.5), lineWidth: 1)
                    )
                    .frame(minHeight: 400)
            } else {
                ScrollView {
                    Text(state.configFileContent.isEmpty ? "Loading configuration..." : state.configFileContent)
                        .font(.custom("Menlo", size: 12))
                        .foregroundStyle(state.configFileContent.isEmpty ? .gray : .white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(16)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                .frame(minHeight: 400)
                .onTapGesture(count: 2) {
                    isEditing = true
                }
            }

            // Edit hint
            if !isEditing {
                Text("Double-click to edit")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
    }
}
