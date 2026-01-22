//
//  SettingsTabCoordinator.swift
//  Velo
//
//  Tab-based settings architecture - Main coordinator view
//

import SwiftUI

struct SettingsTabCoordinator: View {
    @Environment(\.dismiss) var dismiss
    var onClose: (() -> Void)? = nil

    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case theme = "Theme"
        case language = "Language"
        case ssh = "SSH"
        case ai = "Cloud AI"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .theme: return "paintpalette.fill"
            case .language: return "globe"
            case .ssh: return "server.rack"
            case .ai: return "sparkles"
            case .about: return "info.circle.fill"
            }
        }

        var label: String {
            switch self {
            case .general: return "settings.general".localized
            case .theme: return "settings.theme".localized
            case .language: return "settings.language".localized
            case .ssh: return "settings.ssh".localized
            case .ai: return "settings.ai".localized
            case .about: return "settings.about".localized
            }
        }
    }

    var body: some View {
        ZStack {
            ColorTokens.layer0.ignoresSafeArea()

            HStack(spacing: 0) {
                // Sidebar
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("settings.title".localized)
                            .font(TypographyTokens.displayMd)
                            .foregroundColor(ColorTokens.textPrimary)
                        Spacer()
                    }
                    .padding(VeloDesign.Spacing.lg)

                    // Tab buttons
                    VStack(spacing: VeloDesign.Spacing.xxs) {
                        ForEach(SettingsTab.allCases) { tab in
                            SettingsTabButton(
                                tab: tab,
                                isSelected: selectedTab == tab,
                                action: { selectedTab = tab }
                            )
                        }
                    }
                    .padding(.horizontal, VeloDesign.Spacing.sm)

                    Spacer()

                    // Close button at bottom
                    Button(action: {
                        if let onClose = onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    }) {
                        HStack(spacing: VeloDesign.Spacing.sm) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                            Text("common.close".localized)
                                .font(TypographyTokens.body)
                        }
                        .foregroundColor(ColorTokens.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(VeloDesign.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, VeloDesign.Spacing.sm)
                    .padding(.bottom, VeloDesign.Spacing.md)
                }
                .frame(width: 200)
                .background(ColorTokens.layer1)

                // Content
                ScrollView {
                    VStack(spacing: 0) {
                        Group {
                            switch selectedTab {
                            case .general:
                                GeneralTab()
                            case .theme:
                                ThemeTab()
                            case .language:
                                LanguageTab()
                            case .ssh:
                                SSHTab()
                            case .ai:
                                AITab()
                            case .about:
                                AboutTab()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding(VeloDesign.Spacing.xl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 800, height: 600)
    }
}

// MARK: - Tab Button Component

struct SettingsTabButton: View {
    let tab: SettingsTabCoordinator.SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VeloDesign.Spacing.md) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? ColorTokens.accentPrimary : ColorTokens.textSecondary)
                    .frame(width: 20)

                Text(tab.label)
                    .font(TypographyTokens.body)
                    .foregroundColor(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)

                Spacer()
            }
            .padding(VeloDesign.Spacing.sm)
            .background(isSelected ? ColorTokens.layer2 : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsTabCoordinator()
}

