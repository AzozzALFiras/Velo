//
//  UnifiedSidebarView.swift
//  Velo
//
//  Dynamic sidebar generated from ApplicationDefinition.sections.
//

import SwiftUI

struct UnifiedSidebarView: View {
    let app: ApplicationDefinition
    @ObservedObject var viewModel: ApplicationDetailViewModel
    var onDismiss: (() -> Void)?

    private var themeColor: Color {
        Color(hex: app.themeColor) ?? .green
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Navigation Items
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(app.sortedSections) { section in
                        sidebarItem(section: section)
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer()

            // Footer with version info
            footerView
        }
        .frame(width: 260)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(Color.white.opacity(0.08)),
            alignment: .trailing
        )
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            HStack(spacing: 12) {
                // App icon
                SoftwareIconView(
                    iconURL: app.iconURL?.absoluteString ?? "",
                    slug: app.name.lowercased(),
                    color: themeColor,
                    size: 32
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.headline)
                        .foregroundStyle(.white)

                    if !viewModel.state.version.isEmpty {
                        Text(viewModel.state.version)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
            }

            Spacer()

            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(20)
    }

    // MARK: - Sidebar Item

    private func sidebarItem(section: SectionDefinition) -> some View {
        let isSelected = section.id == viewModel.selectedSection.id
        let isDisabled = section.requiresRunning && !viewModel.state.isRunning

        return Button {
            if !isDisabled {
                viewModel.selectedSection = section
                Task {
                    await viewModel.loadSectionData()
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 14))
                    .frame(width: 20)

                Text(section.name)
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                if isDisabled {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }

                if isSelected {
                    Capsule()
                        .fill(themeColor)
                        .frame(width: 3, height: 16)
                }
            }
            .foregroundStyle(isSelected ? .white : (isDisabled ? .gray.opacity(0.5) : .gray))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color.white.opacity(0.08) : Color.clear
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(isDisabled ? "Requires \(app.name) to be running" : section.name)
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack {
                // Status indicator
                Circle()
                    .fill(viewModel.state.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .shadow(color: viewModel.state.isRunning ? .green : .red, radius: 3)

                Text(viewModel.state.isRunning ? "Running" : "Stopped")
                    .font(.caption)
                    .foregroundStyle(.gray)

                Spacer()

                Text(app.category.displayName)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }
}
