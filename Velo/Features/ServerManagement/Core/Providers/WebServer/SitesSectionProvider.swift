//
//  SitesSectionProvider.swift
//  Velo
//
//  Provider for loading web server sites/virtual hosts.
//

import Foundation

/// Provides sites/virtual hosts data for web servers
struct SitesSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .sites }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        let resolver = ServiceResolver.shared

        guard let webService = resolver.resolveWebServer(for: app.id) else {
            throw SectionProviderError.serviceNotFound(app.id)
        }

        // Use the existing service method to fetch sites
        // Sites are handled by the WebServerService protocol
        // The view will call the service directly for site operations
    }
}
