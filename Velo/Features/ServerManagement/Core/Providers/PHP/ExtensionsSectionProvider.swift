//
//  ExtensionsSectionProvider.swift
//  Velo
//
//  Provider for loading PHP extensions.
//

import Foundation

/// Provides PHP extensions data
struct ExtensionsSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .extensions }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        guard app.id.lowercased() == "php" else { return }

        let baseService = ServerAdminService.shared

        // Get loaded extensions
        let result = await baseService.execute("php -m 2>/dev/null", via: session)

        guard result.exitCode == 0 else {
            throw SectionProviderError.loadFailed("Failed to get PHP extensions")
        }

        // Core extensions that are typically built-in
        let coreExtensions = Set([
            "core", "date", "libxml", "pcre", "reflection", "spl",
            "standard", "filter", "hash", "json", "ctype", "tokenizer"
        ])

        let loadedExtensions = result.output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("[") }
            .sorted { $0.lowercased() < $1.lowercased() }

        let extensions = loadedExtensions.map { ext in
            PHPExtensionInfo(
                name: ext,
                version: nil,
                isLoaded: true
            )
        }

        // Get available extensions that could be installed
        let availableResult = await baseService.execute(
            "apt-cache search php | grep -E '^php[0-9.]+-' | awk '{print $1}' | sort -u | head -50",
            via: session
        )

        var availableExtensions: [String] = []
        if availableResult.exitCode == 0 {
            availableExtensions = availableResult.output
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        await MainActor.run {
            state.extensions = extensions
            state.availableExtensions = availableExtensions
        }
    }
}
