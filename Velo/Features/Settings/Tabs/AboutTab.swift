//
//  AboutTab.swift
//  Velo
//
//  About Velo - Version info, updates, developer, and social links
//

import SwiftUI

struct AboutTab: View {
    // Updates
    @State private var isCheckingUpdate = false
    @State private var updateStatus: UpdateStatus?

    struct UpdateStatus {
        let isUpdateAvailable: Bool
        let message: String
        let updateURL: String
    }

    // Social Links
    private let githubURL = URL(string: "https://github.com/azozzalfiras")!
    private let xURL = URL(string: "https://x.com/dev_3zozz")!
    private let websiteURL = URL(string: "https://dev.3zozz.com")!

    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.xl) {
            // Header
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.xs) {
                Text("about.title".localized)
                    .font(TypographyTokens.displayMd)
                    .foregroundColor(ColorTokens.textPrimary)

                Text("about.subtitle".localized)
                    .font(TypographyTokens.bodySm)
                    .foregroundColor(ColorTokens.textSecondary)
            }

            // App Version & Updates
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                SectionHeader(title: "about.version".localized)

                VStack(spacing: VeloDesign.Spacing.md) {
                    HStack {
                        Image(systemName: "cube.box.fill")
                            .font(.system(size: 24))
                            .foregroundColor(ColorTokens.accentPrimary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Velo Terminal")
                                .font(TypographyTokens.subheading)
                                .foregroundColor(ColorTokens.textPrimary)

                            Text("v\(ApiService.shared.appVersion)")
                                .font(TypographyTokens.monoSm)
                                .foregroundColor(ColorTokens.textTertiary)
                        }

                        Spacer()

                        Button(action: checkUpdate) {
                            if isCheckingUpdate {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("about.checkUpdate".localized)
                                    .font(TypographyTokens.bodySm)
                                    .foregroundColor(ColorTokens.accentPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(ColorTokens.accentPrimary.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isCheckingUpdate)
                    }

                    if let status = updateStatus {
                        Divider()
                            .background(ColorTokens.borderSubtle)

                        HStack {
                            Image(systemName: status.isUpdateAvailable ? "arrow.up.circle.fill" : "checkmark.circle.fill")
                                .foregroundColor(status.isUpdateAvailable ? ColorTokens.warning : ColorTokens.success)

                            Text(status.message)
                                .font(TypographyTokens.bodySm)
                                .foregroundColor(ColorTokens.textSecondary)

                            if status.isUpdateAvailable {
                                Spacer()

                                Link("Update", destination: URL(string: status.updateURL) ?? websiteURL)
                                    .font(TypographyTokens.bodySm)
                                    .foregroundColor(ColorTokens.accentSecondary)
                            }
                        }
                    }
                }
                .padding(VeloDesign.Spacing.md)
                .elevated(.low)
            }

            // Developer
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                SectionHeader(title: "about.developer".localized)

                HStack {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ColorTokens.accentSecondary)

                    Text("Azozz ALFiras")
                        .font(TypographyTokens.subheading)
                        .foregroundColor(ColorTokens.textPrimary)

                    Spacer()

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ColorTokens.success)
                }
                .padding(VeloDesign.Spacing.md)
                .elevated(.low)
            }

            // Connect
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                SectionHeader(title: "about.connect".localized)

                VStack(spacing: VeloDesign.Spacing.sm) {
                    LinkRow(
                        icon: .system("globe"),
                        title: "Website",
                        url: websiteURL,
                        color: ColorTokens.success
                    )

                    LinkRow(
                        icon: .asset("GitHub"),
                        title: "GitHub",
                        url: githubURL,
                        color: .white
                    )

                    LinkRow(
                        icon: .asset("X"),
                        title: "X (Twitter)",
                        url: xURL,
                        color: ColorTokens.accentPrimary
                    )
                }
                .padding(VeloDesign.Spacing.md)
                .elevated(.low)
            }

            Spacer()
        }
    }

    // MARK: - Update Check

    private func checkUpdate() {
        isCheckingUpdate = true

        Task {
            do {
                let info = try await ApiService.shared.checkForUpdates()
                await MainActor.run {
                    isCheckingUpdate = false
                    if info.latestVersion != ApiService.shared.appVersion {
                        updateStatus = UpdateStatus(
                            isUpdateAvailable: true,
                            message: "about.updateAvailable".localized.replacingOccurrences(of: "{}", with: info.latestVersion),
                            updateURL: info.pageUpdate
                        )
                    } else {
                        updateStatus = UpdateStatus(
                            isUpdateAvailable: false,
                            message: "about.latestVersion".localized,
                            updateURL: ""
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingUpdate = false
                    updateStatus = UpdateStatus(
                        isUpdateAvailable: false,
                        message: "about.updateFailed".localized,
                        updateURL: ""
                    )
                }
            }
        }
    }
}

#Preview {
    AboutTab()
        .frame(width: 600, height: 600)
        .background(ColorTokens.layer0)
}
