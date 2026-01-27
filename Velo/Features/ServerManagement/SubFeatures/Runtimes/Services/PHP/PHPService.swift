//
//  PHPService.swift
//  Velo
//
//  Public facade for all PHP operations including version management and PHP-FPM control.
//  Supports multiple PHP versions and switching between them.
//

import Foundation
import Combine

@MainActor
final class PHPService: ObservableObject, RuntimeService {
    static let shared = PHPService()

    let baseService = ServerAdminService.shared

    /// The systemd service name for the currently active PHP-FPM
    var serviceName: String {
        if let version = _cachedActiveVersion {
            return "php\(version)-fpm"
        }
        return "php-fpm"
    }

    private var _cachedActiveVersion: String?

    // Sub-components
    private let detector = PHPDetector()
    private let versionResolver = PHPVersionResolver()
    private let fpmManager = PHPFPMManager()

    private init() {}

    // MARK: - ServerModuleService

    func isInstalled(via session: TerminalViewModel) async -> Bool {
        await detector.isInstalled(via: session)
    }

    func getVersion(via session: TerminalViewModel) async -> String? {
        let version = await versionResolver.getActiveVersion(via: session)
        _cachedActiveVersion = version
        return version
    }

    func isRunning(via session: TerminalViewModel) async -> Bool {
        await fpmManager.isAnyFPMRunning(via: session)
    }

    func getStatus(via session: TerminalViewModel) async -> SoftwareStatus {
        guard await isInstalled(via: session) else {
            return .notInstalled
        }

        let version = await getVersion(via: session) ?? "installed"
        let running = await isRunning(via: session)

        return running ? .running(version: version) : .stopped(version: version)
    }

    // MARK: - MultiVersionCapable

    var versionDetectionStrategy: VersionDetectionStrategy {
        .directoryBased(path: "/etc/php", pattern: "^[0-9]")
    }

    var versionSwitchStrategy: VersionSwitchStrategy {
        .updateAlternatives(binary: "php", path: "/usr/bin")
    }

    func listAvailableVersions(via session: TerminalViewModel) async -> [String] {
        // Get from API
        do {
            let capabilities = try await ApiService.shared.fetchCapabilities()
            if let phpCap = capabilities.first(where: { $0.slug.lowercased() == "php" }) {
                return phpCap.versions?.map { $0.version } ?? []
            }
        } catch {
            print("Failed to fetch PHP versions from API: \(error)")
        }
        return []
    }

    func listInstalledVersions(via session: TerminalViewModel) async -> [String] {
        await versionResolver.getInstalledVersions(via: session)
    }

    func getActiveVersion(via session: TerminalViewModel) async -> String? {
        await versionResolver.getActiveVersion(via: session)
    }

    func switchActiveVersion(to version: String, via session: TerminalViewModel) async throws -> Bool {
        let success = await versionResolver.switchVersion(to: version, via: session)
        if !success {
            throw InstallationError.switchFailed("Failed to switch PHP version to \(version)")
        }
        return success
    }

    // MARK: - RuntimeService

    var packageManager: PackageManagerInfo? {
        PackageManagerInfo(name: "composer", binary: "composer", versionFlag: "--version")
    }

    func getInstalledVersions(via session: TerminalViewModel) async -> [String] {
        await listInstalledVersions(via: session)
    }

    func getPackageManagerStatus(via session: TerminalViewModel) async -> SoftwareStatus {
        let result = await baseService.execute("COMPOSER_ALLOW_SUPERUSER=1 which composer 2>/dev/null", via: session, timeout: 30)
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.isEmpty {
            return .notInstalled
        }

        let versionRes = await baseService.execute("COMPOSER_ALLOW_SUPERUSER=1 \(path) --version 2>/dev/null | head -n 1 | awk '{print $2}'", via: session, timeout: 30)
        let version = versionRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return .installed(version: version.isEmpty ? "installed" : version)
    }

    func getComposerStatus(via session: TerminalViewModel) async -> SoftwareStatus {
        await getPackageManagerStatus(via: session)
    }

    // MARK: - ControllableService

    func start(via session: TerminalViewModel) async -> Bool {
        await fpmManager.startActiveFPM(via: session)
    }

    func stop(via session: TerminalViewModel) async -> Bool {
        await fpmManager.stopActiveFPM(via: session)
    }

    func restart(via session: TerminalViewModel) async -> Bool {
        await fpmManager.restartActiveFPM(via: session)
    }

    func reload(via session: TerminalViewModel) async -> Bool {
        await fpmManager.reloadActiveFPM(via: session)
    }

    func enable(via session: TerminalViewModel) async -> Bool {
        await fpmManager.enableActiveFPM(via: session)
    }

    func disable(via session: TerminalViewModel) async -> Bool {
        await fpmManager.disableActiveFPM(via: session)
    }

    // MARK: - Version Management

    /// Switch the default PHP version
    func switchVersion(to version: String, via session: TerminalViewModel) async -> Bool {
        await versionResolver.switchVersion(to: version, via: session)
    }

    /// Start FPM for a specific version
    func startFPM(version: String, via session: TerminalViewModel) async -> Bool {
        await fpmManager.startFPM(version: version, via: session)
    }

    /// Stop FPM for a specific version
    func stopFPM(version: String, via session: TerminalViewModel) async -> Bool {
        await fpmManager.stopFPM(version: version, via: session)
    }

    /// Get status of all FPM instances
    func getAllFPMStatus(via session: TerminalViewModel) async -> [String: Bool] {
        await fpmManager.getAllFPMStatus(via: session)
    }

    // MARK: - PHP Configuration

    /// Get PHP configuration value
    func getConfigValue(_ key: String, via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("php -r \"echo ini_get('\(key)');\" 2>/dev/null", via: session, timeout: 10)
        let value = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// Get list of disabled functions
    func getDisabledFunctions(via session: TerminalViewModel) async -> [String] {
        guard let value = await getConfigValue("disable_functions", via: session) else {
            return []
        }
        return value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Get list of loaded extensions
    func getLoadedExtensions(via session: TerminalViewModel) async -> [String] {
        let result = await baseService.execute("php -m 2>/dev/null", via: session, timeout: 15)
        return result.output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("[") }
    }

    /// Check if a specific extension is loaded
    func isExtensionLoaded(_ extension: String, via session: TerminalViewModel) async -> Bool {
        let extensions = await getLoadedExtensions(via: session)
        return extensions.contains { $0.lowercased() == `extension`.lowercased() }
    }

    // MARK: - PHP Info

    /// Get PHP info summary
    func getInfo(via session: TerminalViewModel) async -> PHPInfo {
        let version = await getVersion(via: session)
        let extensions = await getLoadedExtensions(via: session)
        let disabledFunctions = await getDisabledFunctions(via: session)
        let installedVersions = await getInstalledVersions(via: session)

        let configPath = await getConfigFilePath(via: session)
        let fpmStatus = await getAllFPMStatus(via: session)

        return PHPInfo(
            version: version,
            installedVersions: installedVersions,
            loadedExtensions: extensions,
            disabledFunctions: disabledFunctions,
            configPath: configPath,
            fpmStatus: fpmStatus
        )
    }

    /// Get PHP configuration file path
    func getConfigFilePath(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("php --ini 2>/dev/null | grep 'Loaded Configuration File' | awk '{print $4}'", via: session, timeout: 10)
        let path = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return path.isEmpty || path == "(none)" ? nil : path
    }
}

// MARK: - Supporting Types

struct PHPInfo {
    let version: String?
    let installedVersions: [String]
    let loadedExtensions: [String]
    let disabledFunctions: [String]
    let configPath: String?
    let fpmStatus: [String: Bool]
}
