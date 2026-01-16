//
//  SSHStatsService.swift
//  Velo
//
//  Created by Velo Assistant
//  Specialized service for fetching server stats and software status with high efficiency.
//

import Foundation
import Combine

@MainActor
class SSHStatsService: ObservableObject {
    static let shared = SSHStatsService()
    
    private let base = SSHBaseService.shared
    
    private init() {}
    
    /// Detection of key software using granular commands to prevent timeouts
    func fetchServerStatus(via session: TerminalViewModel) async -> ServerStatus {
        var status = ServerStatus()
        
        // 1. Web Servers
        let nginxRes = await base.execute("if which nginx >/dev/null; then nginx -v 2>&1 | head -n 1; else echo 'no'; fi && if systemctl is-active nginx >/dev/null 2>&1; then echo 'active'; else echo 'no'; fi", via: session, timeout: 5)
        status.nginx = parseSingleStatus(nginxRes.output)
        
        let apacheRes = await base.execute("if which apache2 >/dev/null; then apache2 -v 2>&1 | head -n 1; else echo 'no'; fi && if systemctl is-active apache2 >/dev/null 2>&1; then echo 'active'; else echo 'no'; fi", via: session, timeout: 5)
        status.apache = parseSingleStatus(apacheRes.output)
        
        // 2. Databases
        let mysqlRes = await base.execute("if which mysql >/dev/null; then mysql --version | head -n 1; else echo 'no'; fi && if systemctl is-active mysql >/dev/null 2>&1; then echo 'active'; else echo 'no'; fi", via: session, timeout: 5)
        status.mysql = parseSingleStatus(mysqlRes.output)
        
        let pgRes = await base.execute("if which psql >/dev/null; then psql --version | head -n 1; else echo 'no'; fi && if systemctl is-active postgresql >/dev/null 2>&1; then echo 'active'; else echo 'no'; fi", via: session, timeout: 5)
        status.postgresql = parseSingleStatus(pgRes.output)
        
        // 3. Runtimes
        let phpRes = await base.execute("if which php >/dev/null; then php -v | head -n 1 | awk '{print $2}'; else echo 'no'; fi && if systemctl is-active php*-fpm >/dev/null 2>&1 || systemctl is-active php-fpm >/dev/null 2>&1; then echo 'active'; else echo 'no'; fi", via: session, timeout: 5)
        status.php = parseSingleStatus(phpRes.output)
        
        let nodeRes = await base.execute("if which node >/dev/null; then node -v | head -n 1; else echo 'no'; fi", via: session, timeout: 5)
        if !nodeRes.output.isEmpty && nodeRes.output != "no" {
            status.nodejs = .installed(version: nodeRes.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return status
    }
    
    private func parseSingleStatus(_ output: String) -> SoftwareStatus {
        let lines = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !lines.isEmpty, lines[0] != "no" else { return .notInstalled }
        
        let version = lines[0]
        let isActive = lines.count > 1 && lines[1] == "active"
        
        return isActive ? .running(version: version) : .installed(version: version)
    }
    
    /// Optimized fetch of CPU, RAM, and Disk in one batch
    func fetchSystemStats(via session: TerminalViewModel) async -> (cpu: Double, ram: Double, disk: Double, uptime: String, hostname: String, ip: String, os: String) {
        let command = """
        echo "CPU" && top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' && \
        echo "RAM" && free -m | grep Mem | awk '{print $3,$2}' && \
        echo "DISK" && df -h / | tail -1 | awk '{print $3,$2,$5}' && \
        echo "UPTIME" && uptime -p && \
        echo "HOST" && hostname && \
        echo "IP" && hostname -I | awk '{print $1}' && \
        echo "OS" && cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"'
        """
        
        let result = await base.execute(command, via: session)
        return parseStatsBatch(result.output)
    }
    
    private func parseStatusBatch(_ output: String) -> ServerStatus {
        var status = ServerStatus()
        let lines = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        
        var currentSection = ""
        for line in lines {
            if ["NGINX", "APACHE", "MYSQL", "PHP", "GIT", "NODE", "PYTHON", "COMPOSER"].contains(line) {
                currentSection = line
                continue
            }
            
            switch currentSection {
            case "NGINX": 
                if line != "no" {
                    if line == "active" { status.nginx = .running(version: "detected") }
                    else { status.nginx = .installed(version: line) }
                }
            case "APACHE": 
                if line != "no" {
                    if line == "active" { status.apache = .running(version: "detected") }
                    else { status.apache = .installed(version: line) }
                }
            case "MYSQL": 
                if line != "no" {
                    if line == "active" { status.mysql = .running(version: "detected") }
                    else { status.mysql = .installed(version: line) }
                }
            case "PHP": 
                if line != "no" {
                    if line == "active" { status.php = .running(version: "detected") }
                    else { status.php = .installed(version: line) }
                }
            case "GIT": if line != "no" { status.git = .installed(version: line) }
            case "NODE": if line != "no" { status.nodejs = .installed(version: line) }
            case "PYTHON": if line != "no" { status.python = .installed(version: line) }
            case "COMPOSER": if line == "yes" { status.composer = .installed(version: "installed") }
            default: break
            }
        }
        return status
    }
    
    private func parseStatsBatch(_ output: String) -> (cpu: Double, ram: Double, disk: Double, uptime: String, hostname: String, ip: String, os: String) {
        var cpu: Double = 0, ram: Double = 0, disk: Double = 0
        var uptime = "", hostname = "", ip = "", os = ""
        
        let lines = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        
        var currentSection = ""
        for line in lines {
            if ["CPU", "RAM", "DISK", "UPTIME", "HOST", "IP", "OS"].contains(line) {
                currentSection = line
                continue
            }
            
            switch currentSection {
            case "CPU": cpu = (Double(line) ?? 0) / 100.0
            case "RAM":
                let parts = line.components(separatedBy: " ")
                if parts.count >= 2, let used = Double(parts[0]), let total = Double(parts[1]), total > 0 {
                    ram = used / total
                }
            case "DISK":
                let parts = line.components(separatedBy: " ")
                if parts.count >= 3 {
                    let percentStr = parts[2].replacingOccurrences(of: "%", with: "")
                    disk = (Double(percentStr) ?? 0) / 100.0
                }
            case "UPTIME": uptime = line
            case "HOST": hostname = line
            case "IP": ip = line
            case "OS": os = line
            default: break
            }
        }
        return (cpu, ram, disk, uptime, hostname, ip, os)
    }
}
