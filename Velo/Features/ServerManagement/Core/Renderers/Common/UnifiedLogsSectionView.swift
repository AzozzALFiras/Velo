//
//  UnifiedLogsSectionView.swift
//  Velo
//
//  Unified log viewer for all applications.
//

import SwiftUI

struct UnifiedLogsSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Log file selector
            if state.availableLogFiles.count > 1 {
                HStack {
                    Text("Log File:")
                        .font(.caption)
                        .foregroundStyle(.gray)

                    Picker("", selection: Binding(
                        get: { state.selectedLogFile },
                        set: { newValue in
                            state.selectedLogFile = newValue
                            Task {
                                await viewModel.loadSectionData()
                            }
                        }
                    )) {
                        ForEach(state.availableLogFiles, id: \.self) { file in
                            Text(URL(fileURLWithPath: file).lastPathComponent)
                                .tag(file)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

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
            }

            // Log content
            ScrollView {
                ScrollViewReader { proxy in
                    Text(state.logContent.isEmpty ? "No logs available" : state.logContent)
                        .font(.custom("Menlo", size: 11))
                        .foregroundStyle(state.logContent.isEmpty ? .gray : .white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .id("logBottom")
                        .onAppear {
                            proxy.scrollTo("logBottom", anchor: .bottom)
                        }
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}
