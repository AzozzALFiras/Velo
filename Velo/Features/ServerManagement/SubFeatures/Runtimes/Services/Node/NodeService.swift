//
//  NodeService.swift
//  Velo
//
//  Service for managing Node.js installations and versions.
//

import Foundation
import Combine

@MainActor
final class NodeService: ObservableObject, RuntimeService {
    static let shared = NodeService()

    let baseService = SSHBaseService.shared
    private let detector = NodeDetector()
    private let versionResolver = NodeVersionResolver()

    var serviceName: String { "" } // Node has no systemd service

    var versionDetectionStrategy: VersionDetectionStrategy {
        versionResolver.detectionStrategy
    }

    var versionSwitchStrategy: VersionSwitchStrategy {
        versionResolver.switchStrategy
    }

    var packageManager: PackageManagerInfo? {
        PackageManagerInfo(name: "npm", binary: "npm", versionFlag: "--version")
    }

    private init() {}

    // MARK: - ServerModuleService

    func isInstalled(via session: TerminalViewModel) async -> Bool {
        await detector.isInstalled(via: session)
    }

    func getVersion(via session: TerminalViewModel) async -> String? {
        await versionResolver.getActiveVersion(via: session)
    }

    func isRunning(via session: TerminalViewModel) async -> Bool {
        return false // Node is not a service
    }

    func getStatus(via session: TerminalViewModel) async -> SoftwareStatus {
        guard await isInstalled(via: session) else { return .notInstalled }
        let version = await getVersion(via: session) ?? "installed"
        return .installed(version: version)
    }

    // MARK: - ControllableService (No-ops for Node)

    func start(via session: TerminalViewModel) async -> Bool { false }
    func stop(via session: TerminalViewModel) async -> Bool { false }
    func restart(via session: TerminalViewModel) async -> Bool { false }
    func reload(via session: TerminalViewModel) async -> Bool { false }
    func enable(via session: TerminalViewModel) async -> Bool { false }
    func disable(via session: TerminalViewModel) async -> Bool { false }

    // MARK: - MultiVersionCapable

    func listAvailableVersions(via session: TerminalViewModel) async -> [String] {
        // Get from API
        do {
            let capabilities = try await ApiService.shared.fetchCapabilities()
            if let nodeCap = capabilities.first(where: { $0.slug.lowercased() == "nodejs" }) {
                return nodeCap.versions?.map { $0.version } ?? []
            }
        } catch {
            print("Failed to fetch Node versions from API: \(error)")
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
        try await versionResolver.switchVersion(to: version, via: session)
    }

    // MARK: - RuntimeService

    func getInstalledVersions(via session: TerminalViewModel) async -> [String] {
        await listInstalledVersions(via: session)
    }

    func getPackageManagerStatus(via session: TerminalViewModel) async -> SoftwareStatus {
        guard await detector.isNpmInstalled(via: session) else {
            return .notInstalled
        }

        let result = await baseService.execute("npm --version", via: session, timeout: 5)
        let version = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? .notInstalled : .installed(version: version)
    }

    func getNPMStatus(via session: TerminalViewModel) async -> SoftwareStatus {
        await getPackageManagerStatus(via: session)
    }
}
