//
//  ApplicationLifecycleManager.swift
//  Velo
//
//  Central coordinator for application lifecycle state.
//

import Foundation
import Combine

/// Central coordinator for application lifecycle state
@MainActor
final class ApplicationLifecycleManager: ObservableObject {
    static let shared = ApplicationLifecycleManager()

    /// Track lifecycle state for all applications by ID
    @Published private(set) var lifecycleStates: [String: ApplicationLifecycleState] = [:]

    private init() {}

    // MARK: - State Management

    /// Update lifecycle state for an application
    func updateState(for appId: String, state: ApplicationLifecycleState) {
        lifecycleStates[appId] = state
    }

    /// Refresh state for an application by querying its service
    func refreshState(
        for appId: String,
        via session: TerminalViewModel
    ) async {
        guard let service = ServiceResolver.shared.resolve(for: appId) else {
            lifecycleStates[appId] = .broken(reason: "Service not found")
            return
        }

        // Check installation
        let installed = await service.isInstalled(via: session)
        guard installed else {
            lifecycleStates[appId] = .notInstalled
            return
        }

        // Get version
        let version = await service.getVersion(via: session) ?? "unknown"

        // Check if multi-version capable
        if let multiVersionService = service as? MultiVersionCapable {
            let installedVersions = await multiVersionService.listInstalledVersions(via: session)
            let activeVersion = await multiVersionService.getActiveVersion(via: session)

            if installedVersions.count > 1 {
                lifecycleStates[appId] = .multipleVersionsInstalled(
                    versions: installedVersions,
                    active: activeVersion
                )
                return
            }
        }

        // Check if running (for controllable services)
        if let controllableService = service as? ControllableService {
            let running = await service.isRunning(via: session)
            lifecycleStates[appId] = running ? .running(version: version) : .stopped(version: version)
        } else {
            lifecycleStates[appId] = .installed(version: version)
        }
    }

    /// Register an installation (called after ServerInstallerViewModel completes)
    func registerInstallation(
        appId: String,
        version: String,
        via session: TerminalViewModel
    ) async {
        // Refresh full state after installation
        await refreshState(for: appId, via: session)
    }

    /// Observe installation for an app
    func observeInstallation(for appId: String) -> AsyncStream<InstallProgress> {
        AsyncStream { continuation in
            // This will be implemented when we add real installation pipeline
            // For now, just complete immediately
            continuation.finish()
        }
    }
}
