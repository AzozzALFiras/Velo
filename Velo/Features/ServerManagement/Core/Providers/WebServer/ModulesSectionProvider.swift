//
//  ModulesSectionProvider.swift
//  Velo
//
//  Provider for loading web server modules (Nginx/Apache).
//

import Foundation

/// Provides modules data for web servers
struct ModulesSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .modules }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        let baseService = ServerAdminService.shared

        switch app.id.lowercased() {
        case "nginx":
            try await loadNginxModules(state: state, session: session, baseService: baseService)
        case "apache", "apache2":
            try await loadApacheModules(state: state, session: session, baseService: baseService)
        default:
            break
        }
    }

    private func loadNginxModules(state: ApplicationState, session: TerminalViewModel, baseService: ServerAdminService) async throws {
        // Get nginx compile-time modules
        let result = await baseService.execute("nginx -V 2>&1", via: session)

        var modules: [String] = []
        var configureArguments: [String] = []

        // Parse --with-* flags for modules
        let output = result.output

        // Extract configure arguments
        if let configureRange = output.range(of: "configure arguments:(.+)", options: .regularExpression) {
            let configureString = String(output[configureRange])
                .replacingOccurrences(of: "configure arguments:", with: "")
                .trimmingCharacters(in: .whitespaces)

            configureArguments = configureString
                .components(separatedBy: " ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            // Extract module names
            modules = configureArguments.compactMap { arg -> String? in
                if arg.hasPrefix("--with-") {
                    var moduleName = arg.replacingOccurrences(of: "--with-", with: "")
                    moduleName = moduleName.replacingOccurrences(of: "_module", with: "")
                    return moduleName
                } else if arg.hasPrefix("--add-module=") || arg.hasPrefix("--add-dynamic-module=") {
                    // External module
                    let parts = arg.components(separatedBy: "=")
                    if parts.count > 1 {
                        return URL(fileURLWithPath: parts[1]).lastPathComponent
                    }
                }
                return nil
            }
        }

        // Also check for dynamically loaded modules
        let dynamicResult = await baseService.execute(
            "ls /etc/nginx/modules-enabled/*.conf 2>/dev/null | xargs -I {} basename {} .conf",
            via: session
        )

        if dynamicResult.exitCode == 0 {
            let dynamicModules = dynamicResult.output
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            modules.append(contentsOf: dynamicModules)
        }

        await MainActor.run {
            state.modules = Array(Set(modules)).sorted()
            state.configureArguments = configureArguments
        }
    }

    private func loadApacheModules(state: ApplicationState, session: TerminalViewModel, baseService: ServerAdminService) async throws {
        // Get Apache loaded modules
        let result = await baseService.execute("apache2ctl -M 2>/dev/null || httpd -M 2>/dev/null", via: session)

        var modules: [String] = []

        if result.exitCode == 0 {
            let lines = result.output.components(separatedBy: .newlines)
            for line in lines {
                // Parse lines like "  rewrite_module (shared)"
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.contains("_module") {
                    let parts = trimmed.components(separatedBy: .whitespaces)
                    if let moduleName = parts.first {
                        modules.append(moduleName.replacingOccurrences(of: "_module", with: ""))
                    }
                }
            }
        }

        await MainActor.run {
            state.modules = modules.sorted()
        }
    }
}
