//
//  PostgreSQLDetector.swift
//  Velo
//
//  Handles PostgreSQL installation detection and availability checks.
//

import Foundation

struct PostgreSQLDetector {
    private let baseService = ServerAdminService.shared

    /// Check if PostgreSQL is installed on the server
    func isInstalled(via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("which psql 2>/dev/null", via: session, timeout: 10)
        return !result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
    }

    /// Get the path to the psql binary
    func getBinaryPath(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("which psql 2>/dev/null", via: session, timeout: 10)
        let path = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    /// Check if PostgreSQL server is installed (not just client)
    func isServerInstalled(via session: TerminalViewModel) async -> Bool {
        // Check for pg_ctl or postgres binary
        let result = await baseService.execute("which pg_ctl 2>/dev/null || which postgres 2>/dev/null", via: session, timeout: 10)
        return !result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
    }

    /// Check if PostgreSQL was installed via package manager
    func isPackageInstalled(via session: TerminalViewModel) async -> Bool {
        // Check Debian/Ubuntu
        let dpkgResult = await baseService.execute("dpkg -l postgresql 2>/dev/null | grep -E '^ii' | wc -l", via: session, timeout: 10)
        if let count = Int(dpkgResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)), count > 0 {
            return true
        }

        // Check RHEL/CentOS
        let rpmResult = await baseService.execute("rpm -qa | grep -E 'postgresql[0-9]*-server' | wc -l", via: session, timeout: 10)
        if let count = Int(rpmResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)), count > 0 {
            return true
        }

        return false
    }

    /// Get the PostgreSQL data directory
    func getDataDirectory(via session: TerminalViewModel) async -> String? {
        // Try to get from running cluster
        let result = await baseService.execute(
            "sudo -u postgres psql -t -c 'SHOW data_directory;' 2>/dev/null | head -1",
            via: session, timeout: 10
        )
        let path = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if !path.isEmpty && path.hasPrefix("/") {
            return path
        }

        // Default locations
        let defaultPaths = [
            "/var/lib/postgresql/*/main",
            "/var/lib/pgsql/*/data"
        ]

        for pattern in defaultPaths {
            let findResult = await baseService.execute("ls -d \(pattern) 2>/dev/null | head -1", via: session, timeout: 5)
            let foundPath = findResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !foundPath.isEmpty {
                return foundPath
            }
        }

        return nil
    }

    /// Get list of installed PostgreSQL cluster versions
    func getInstalledClusters(via session: TerminalViewModel) async -> [String] {
        // Debian/Ubuntu style
        let result = await baseService.execute("pg_lsclusters -h 2>/dev/null | awk '{print $1\"-\"$2}'", via: session, timeout: 10)
        let clusters = result.output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !clusters.isEmpty {
            return clusters
        }

        // RHEL style - check for version directories
        let rhelResult = await baseService.execute("ls -1 /usr/pgsql-*/bin/psql 2>/dev/null | grep -oE '[0-9]+' | sort -u", via: session, timeout: 10)
        return rhelResult.output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
