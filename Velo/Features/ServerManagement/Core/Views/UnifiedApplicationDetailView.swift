//
//  UnifiedApplicationDetailView.swift
//  Velo
//
//  Single view that renders all application detail views.
//

import SwiftUI

struct UnifiedApplicationDetailView: View {

    @StateObject private var viewModel: ApplicationDetailViewModel
    var onDismiss: (() -> Void)?

    /// Access renderer registry lazily to avoid MainActor deadlock during view init
    private var rendererRegistry: SectionRendererRegistry {
        SectionRendererRegistry.shared
    }

    init(app: ApplicationDefinition, session: TerminalViewModel?, onDismiss: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ApplicationDetailViewModel(app: app, session: session))
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            UnifiedSidebarView(
                app: viewModel.app,
                viewModel: viewModel,
                onDismiss: onDismiss
            )

            // Main Content
            mainContentView
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        .task {
            await viewModel.loadData()
        }
        .onChange(of: viewModel.selectedSection.id) { _ in
            Task {
                await viewModel.loadSectionData()
            }
        }
    }

    // MARK: - Main Content

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Content Header
            HStack {
                Text(viewModel.selectedSection.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Spacer()

                if viewModel.isLoading || viewModel.isPerformingAction {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }
            }
            .padding(24)

            Divider()
                .background(Color.white.opacity(0.1))

            // Section Content
            ScrollView {
                ZStack {
                    // Dynamic section content
                    rendererRegistry.view(
                        for: viewModel.selectedSection,
                        app: viewModel.app,
                        state: viewModel.state,
                        viewModel: viewModel
                    )

                    // Installation status overlay
                    if viewModel.state.isInstallingVersion {
                        installationOverlay
                    }
                }
                .padding(24)
            }

            // Feedback Messages
            if let error = viewModel.errorMessage {
                feedbackBanner(message: error, isError: true)
            }

            if let success = viewModel.successMessage {
                feedbackBanner(message: success, isError: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Installation Overlay

    private var installationOverlay: some View {
        VStack(alignment: .leading) {
            Spacer()
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Installing \(viewModel.app.name) \(viewModel.state.installingVersionName)...")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                    Text(viewModel.state.installStatus)
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.black.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Feedback Banner

    private func feedbackBanner(message: String, isError: Bool) -> some View {
        HStack {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? .red : .green)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

            Button {
                if isError {
                    viewModel.errorMessage = nil
                } else {
                    viewModel.successMessage = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(isError ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
