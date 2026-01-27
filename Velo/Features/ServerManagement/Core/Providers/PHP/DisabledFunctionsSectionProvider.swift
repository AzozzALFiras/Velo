//
//  DisabledFunctionsSectionProvider.swift
//  Velo
//
//  Provider for loading PHP disabled functions.
//

import Foundation

/// Provides PHP disabled functions data
struct DisabledFunctionsSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .disabledFunctions }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        guard app.id.lowercased() == "php" else { return }

        let baseService = ServerAdminService.shared

        // Get disabled functions from PHP config
        let result = await baseService.execute(
            "php -r \"echo ini_get('disable_functions');\" 2>/dev/null",
            via: session
        )

        var disabledFunctions: [String] = []

        if result.exitCode == 0 && !result.output.isEmpty {
            disabledFunctions = result.output
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .sorted()
        }

        await MainActor.run {
            state.disabledFunctions = disabledFunctions
        }
    }
}
