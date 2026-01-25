//
//  VersionsSectionProvider.swift
//  Velo
//
//  Provider for loading installed and available versions.
//

import Foundation

/// Provides version information for the Versions section
struct VersionsSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .versions }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        // Load available versions from API
        let capabilities = try? await ApiService.shared.fetchCapabilities()
        if let capability = capabilities?.first(where: { $0.slug.lowercased() == app.slug.lowercased() }) {
            await MainActor.run {
                state.availableVersions = capability.versions ?? []
            }
        }

        // Load installed versions if MultiVersionCapable
        let resolver = ServiceResolver.shared
        if let service = resolver.resolve(for: app.id) as? MultiVersionCapable {
            let installedVersions = await service.listInstalledVersions(via: session)
            let activeVersion = await service.getActiveVersion(via: session)

            await MainActor.run {
                state.installedVersions = installedVersions
                state.activeVersion = activeVersion ?? ""
            }
        } else {
            // For non-MultiVersionCapable services, just get current version
            if let service = resolver.resolve(for: app.id),
               let version = await service.getVersion(via: session) {
                await MainActor.run {
                    state.activeVersion = version
                    state.installedVersions = [version]
                }
            }
        }
    }
}
