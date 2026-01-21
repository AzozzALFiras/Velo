//
//  SectionProviderRegistry.swift
//  Velo
//
//  Central registry for section data providers.
//

import Foundation
import Combine

/// Central registry that maps SectionProviderType to provider instances
@MainActor
final class SectionProviderRegistry {
    static let shared = SectionProviderRegistry()

    private var providers: [SectionProviderType: any SectionProvider] = [:]

    private init() {
        registerDefaultProviders()
    }

    /// Register a provider for a specific section type
    func register<P: SectionProvider>(_ provider: P) {
        providers[P.providerType] = provider
    }

    /// Get the provider for a specific section type
    func provider(for type: SectionProviderType) -> (any SectionProvider)? {
        providers[type]
    }

    /// Load data for a section
    func loadData(
        for section: SectionDefinition,
        app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        guard let provider = providers[section.providerType] else {
            throw SectionProviderError.notSupported(section.providerType)
        }
        try await provider.loadData(for: app, state: state, session: session)
    }

    /// Check if a provider is registered for a type
    func hasProvider(for type: SectionProviderType) -> Bool {
        providers[type] != nil
    }

    /// Register all default providers
    private func registerDefaultProviders() {
        // Common providers
        register(ServiceSectionProvider())
        register(LogsSectionProvider())
        register(ConfigFileSectionProvider())
        register(ConfigurationSectionProvider())
        register(VersionsSectionProvider())
        register(StatusSectionProvider())

        // Web server providers
        register(ModulesSectionProvider())
        register(SecuritySectionProvider())
        register(SitesSectionProvider())

        // PHP providers
        register(ExtensionsSectionProvider())
        register(DisabledFunctionsSectionProvider())
        register(FPMProfileSectionProvider())
        register(PHPInfoSectionProvider())

        // Database providers
        register(DatabasesSectionProvider())
        register(UsersSectionProvider())
    }
}
