//
//  ServiceManagementViewModel.swift
//  Velo
//
//  ViewModel for controlling server services (start/stop/restart).
//  Handles Nginx, Apache, MySQL, PostgreSQL, PHP-FPM, and other services.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class ServiceManagementViewModel: ObservableObject {

    // MARK: - Dependencies
    weak var session: TerminalViewModel?
    private let nginxService = NginxService.shared
    private let apacheService = ApacheService.shared
    private let phpService = PHPService.shared
    private let mysqlService = MySQLService.shared
    private let postgresService = PostgreSQLService.shared
    private let baseService = ServerAdminService.shared

    // MARK: - Published State

    @Published var services: [ServiceInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Loading states for individual services
    @Published var loadingServices: Set<String> = []

    // MARK: - Init

    init(session: TerminalViewModel? = nil) {
        self.session = session
    }

    // MARK: - Data Loading

    /// Load all service statuses
    func loadServices() async {
        guard let session = session else { return }

        isLoading = true

        var serviceList: [ServiceInfo] = []

        // Check Nginx
        let nginxStatus = await nginxService.getStatus(via: session)
        if nginxStatus.isInstalled {
            serviceList.append(ServiceInfo(
                name: "Nginx",
                serviceName: "nginx",
                type: .webServer,
                status: nginxStatus,
                canReload: true
            ))
        }

        // Check Apache
        let apacheStatus = await apacheService.getStatus(via: session)
        if apacheStatus.isInstalled {
            serviceList.append(ServiceInfo(
                name: "Apache",
                serviceName: await ApacheDetector().getServiceName(via: session),
                type: .webServer,
                status: apacheStatus,
                canReload: true
            ))
        }

        // Check PHP-FPM
        let phpStatus = await phpService.getStatus(via: session)
        if phpStatus.isInstalled {
            serviceList.append(ServiceInfo(
                name: "PHP-FPM",
                serviceName: "php-fpm",
                type: .runtime,
                status: phpStatus,
                canReload: true
            ))
        }

        // Check MySQL
        let mysqlStatus = await mysqlService.getStatus(via: session)
        if mysqlStatus.isInstalled {
            let mysqlServiceName = await MySQLDetector().getServiceName(via: session)
            serviceList.append(ServiceInfo(
                name: mysqlServiceName == "mariadb" ? "MariaDB" : "MySQL",
                serviceName: mysqlServiceName,
                type: .database,
                status: mysqlStatus,
                canReload: false
            ))
        }

        // Check PostgreSQL
        let pgStatus = await postgresService.getStatus(via: session)
        if pgStatus.isInstalled {
            serviceList.append(ServiceInfo(
                name: "PostgreSQL",
                serviceName: "postgresql",
                type: .database,
                status: pgStatus,
                canReload: true
            ))
        }

        // Check Redis
        let redisStatus = await checkServiceStatus("redis-server", via: session)
        if redisStatus.isInstalled {
            serviceList.append(ServiceInfo(
                name: "Redis",
                serviceName: "redis-server",
                type: .cache,
                status: redisStatus,
                canReload: false
            ))
        }

        services = serviceList
        isLoading = false
    }

    /// Refresh all service statuses
    func refresh() async {
        await loadServices()
    }

    // MARK: - Service Control

    /// Start a service
    func startService(_ service: ServiceInfo) async -> Bool {
        guard let session = session else { return false }

        loadingServices.insert(service.serviceName)
        defer { loadingServices.remove(service.serviceName) }

        let success: Bool

        switch service.serviceName {
        case "nginx":
            success = await nginxService.start(via: session)
        case "apache2", "httpd":
            success = await apacheService.start(via: session)
        case "php-fpm":
            success = await phpService.start(via: session)
        case "mysql", "mariadb", "mysqld":
            success = await mysqlService.start(via: session)
        case "postgresql":
            success = await postgresService.start(via: session)
        default:
            let result = await baseService.execute("sudo systemctl start \(service.serviceName)", via: session, timeout: 30)
            success = result.exitCode == 0
        }

        if success {
            await updateServiceStatus(service)
        }

        return success
    }

    /// Stop a service
    func stopService(_ service: ServiceInfo) async -> Bool {
        guard let session = session else { return false }

        loadingServices.insert(service.serviceName)
        defer { loadingServices.remove(service.serviceName) }

        let success: Bool

        switch service.serviceName {
        case "nginx":
            success = await nginxService.stop(via: session)
        case "apache2", "httpd":
            success = await apacheService.stop(via: session)
        case "php-fpm":
            success = await phpService.stop(via: session)
        case "mysql", "mariadb", "mysqld":
            success = await mysqlService.stop(via: session)
        case "postgresql":
            success = await postgresService.stop(via: session)
        default:
            let result = await baseService.execute("sudo systemctl stop \(service.serviceName)", via: session, timeout: 30)
            success = result.exitCode == 0
        }

        if success {
            await updateServiceStatus(service)
        }

        return success
    }

    /// Restart a service
    func restartService(_ service: ServiceInfo) async -> Bool {
        guard let session = session else { return false }

        loadingServices.insert(service.serviceName)
        defer { loadingServices.remove(service.serviceName) }

        let success: Bool

        switch service.serviceName {
        case "nginx":
            success = await nginxService.restart(via: session)
        case "apache2", "httpd":
            success = await apacheService.restart(via: session)
        case "php-fpm":
            success = await phpService.restart(via: session)
        case "mysql", "mariadb", "mysqld":
            success = await mysqlService.restart(via: session)
        case "postgresql":
            success = await postgresService.restart(via: session)
        default:
            let result = await baseService.execute("sudo systemctl restart \(service.serviceName)", via: session, timeout: 30)
            success = result.exitCode == 0
        }

        if success {
            await updateServiceStatus(service)
        }

        return success
    }

    /// Reload a service configuration
    func reloadService(_ service: ServiceInfo) async -> Bool {
        guard let session = session, service.canReload else { return false }

        loadingServices.insert(service.serviceName)
        defer { loadingServices.remove(service.serviceName) }

        let success: Bool

        switch service.serviceName {
        case "nginx":
            success = await nginxService.reload(via: session)
        case "apache2", "httpd":
            success = await apacheService.reload(via: session)
        case "php-fpm":
            success = await phpService.reload(via: session)
        default:
            let result = await baseService.execute("sudo systemctl reload \(service.serviceName)", via: session, timeout: 30)
            success = result.exitCode == 0
        }

        return success
    }

    /// Enable a service to start on boot
    func enableService(_ service: ServiceInfo) async -> Bool {
        guard let session = session else { return false }

        let result = await baseService.execute("sudo systemctl enable \(service.serviceName)", via: session, timeout: 30)
        return result.exitCode == 0
    }

    /// Disable a service from starting on boot
    func disableService(_ service: ServiceInfo) async -> Bool {
        guard let session = session else { return false }

        let result = await baseService.execute("sudo systemctl disable \(service.serviceName)", via: session, timeout: 30)
        return result.exitCode == 0
    }

    // MARK: - Private Helpers

    private func checkServiceStatus(_ serviceName: String, via session: TerminalViewModel) async -> SoftwareStatus {
        let whichResult = await baseService.execute("which \(serviceName) 2>/dev/null || systemctl list-units --type=service | grep \(serviceName)", via: session, timeout: 10)
        if whichResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            return .notInstalled
        }

        let statusResult = await baseService.execute("systemctl is-active \(serviceName) 2>/dev/null", via: session, timeout: 10)
        let isActive = statusResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "active"

        let versionResult = await baseService.execute("\(serviceName) --version 2>&1 | head -1 | grep -oE '[0-9]+\\.[0-9]+'", via: session, timeout: 10)
        let version = versionResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        return isActive ? .running(version: version.isEmpty ? "installed" : version) : .stopped(version: version.isEmpty ? "installed" : version)
    }

    private func updateServiceStatus(_ service: ServiceInfo) async {
        guard let session = session else { return }
        guard let index = services.firstIndex(where: { $0.serviceName == service.serviceName }) else { return }

        let newStatus: SoftwareStatus

        switch service.serviceName {
        case "nginx":
            newStatus = await nginxService.getStatus(via: session)
        case "apache2", "httpd":
            newStatus = await apacheService.getStatus(via: session)
        case "php-fpm":
            newStatus = await phpService.getStatus(via: session)
        case "mysql", "mariadb", "mysqld":
            newStatus = await mysqlService.getStatus(via: session)
        case "postgresql":
            newStatus = await postgresService.getStatus(via: session)
        default:
            newStatus = await checkServiceStatus(service.serviceName, via: session)
        }

        services[index].status = newStatus
    }

    // MARK: - Computed Properties

    var runningServices: [ServiceInfo] {
        services.filter { $0.status.isRunning }
    }

    var stoppedServices: [ServiceInfo] {
        services.filter { $0.status.isInstalled && !$0.status.isRunning }
    }

    func isServiceLoading(_ service: ServiceInfo) -> Bool {
        loadingServices.contains(service.serviceName)
    }
}

// MARK: - Supporting Types

struct ServiceInfo: Identifiable {
    let id = UUID()
    let name: String
    let serviceName: String
    let type: ServiceType
    var status: SoftwareStatus
    let canReload: Bool

    var isRunning: Bool {
        status.isRunning
    }

    var version: String? {
        status.version
    }
}

