//
//  PHPInfoSectionProvider.swift
//  Velo
//
//  Provider for loading PHP info data.
//

import Foundation

/// Provides phpinfo() data
struct PHPInfoSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .phpinfo }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        guard app.id.lowercased() == "php" else { return }

        let baseService = SSHBaseService.shared

        // Get PHP info as HTML
        let htmlResult = await baseService.execute(
            "php -r 'phpinfo();' 2>/dev/null",
            via: session,
            timeout: 30
        )

        // Get key PHP info values
        let infoCommands = [
            ("PHP Version", "php -r 'echo PHP_VERSION;'"),
            ("Zend Engine", "php -r 'echo zend_version();'"),
            ("SAPI", "php -r 'echo php_sapi_name();'"),
            ("Config File", "php -r 'echo php_ini_loaded_file();'"),
            ("Memory Limit", "php -r 'echo ini_get(\"memory_limit\");'"),
            ("Max Execution Time", "php -r 'echo ini_get(\"max_execution_time\");'"),
            ("Upload Max Filesize", "php -r 'echo ini_get(\"upload_max_filesize\");'"),
            ("Post Max Size", "php -r 'echo ini_get(\"post_max_size\");'"),
            ("Timezone", "php -r 'echo date_default_timezone_get();'"),
            ("Display Errors", "php -r 'echo ini_get(\"display_errors\");'")
        ]

        var phpInfoData: [String: String] = [:]

        for (key, command) in infoCommands {
            let result = await baseService.execute(command, via: session)
            if result.exitCode == 0 {
                phpInfoData[key] = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        await MainActor.run {
            state.phpInfoHTML = htmlResult.output
            state.phpInfoData = phpInfoData
        }
    }
}
