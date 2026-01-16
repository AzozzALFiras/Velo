//
//  SSHServerCommandService.swift
//  Velo
//
//  Service for executing server management commands via SSH
//  Provides real-time server data for Server Management UI
//

import Foundation
import Combine

// MARK: - Command Result

struct SSHCommandResult {
    let command: String
    let output: String
    let exitCode: Int32
    let executionTime: TimeInterval
    
    var isSuccess: Bool { exitCode == 0 }
}

// MARK: - Server Stats Parsed

struct ParsedServerStats {
    var cpuUsage: Double = 0
    var ramUsage: Double = 0
    var ramTotal: Int = 0
    var ramUsed: Int = 0
    var diskUsage: Double = 0
    var diskTotal: String = ""
    var diskUsed: String = ""
    var uptime: String = ""
    var hostname: String = ""
    var ipAddress: String = ""
    var osName: String = ""
}

// MARK: - Service Status

struct ParsedServiceStatus: Identifiable {
    let id = UUID()
    let name: String
    let isRunning: Bool
    let description: String
}

// MARK: - SSH Server Command Service

@MainActor
final class SSHServerCommandService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SSHServerCommandService()
    
    // MARK: - Published State
    @Published var lastCommandOutput: String = ""
    @Published var isExecuting: Bool = false
    
    // MARK: - Logging
    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [SSHService] \(message)")
    }
    
    /// Execute a command via the active SSH session and capture output
    func executeCommand(_ command: String, via session: TerminalViewModel, timeout: Int = 20) async -> SSHCommandResult {
        log("Executing: \(command)")
        let startTime = Date()
        
        // Clear previous output tracking
        let previousLineCount = session.outputLines.count
        
        // Send command to SSH session
        session.terminalEngine.sendInput("\(command)\n")
        
        // Wait for output (with timeout)
        var output = ""
        var attempts = 0
        let maxAttempts = timeout // Each attempt = 100ms
        var stableCount = 0
        var lastOutputLength = 0
        
        while attempts < maxAttempts {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            // Check for new output
            let newLines = session.outputLines.dropFirst(previousLineCount)
            let newOutput = newLines.map { $0.text }.joined(separator: "\n")
            
            // Always update output so we have the latest even on timeout
            output = newOutput
            
            // Check if output is stable (no new data for 2 cycles) after getting some output
            if newOutput.count == lastOutputLength && !newOutput.isEmpty {
                stableCount += 1
                if stableCount >= 2 {
                    // Output stable, check for prompt
                    let lastLine = session.outputLines.last?.text ?? ""
                    if lastLine.contains("#") || lastLine.contains("$") {
                        break
                    }
                }
            } else {
                stableCount = 0
                lastOutputLength = newOutput.count
            }
            
            // Also break early if we detect prompt
            if !newOutput.isEmpty {
                let lastLine = session.outputLines.last?.text ?? ""
                if (lastLine.hasSuffix("#") || lastLine.hasSuffix("$ ")) && attempts > 1 {
                    break
                }
            }
            
            attempts += 1
        }
        
        // Clean the output
        output = stripTerminalEscapes(output)
        
        let executionTime = Date().timeIntervalSince(startTime)
        log("Completed in \(String(format: "%.2f", executionTime))s, output length: \(output.count)")
        
        return SSHCommandResult(
            command: command,
            output: output,
            exitCode: 0,
            executionTime: executionTime
        )
    }
    
    /// Strip terminal escape sequences including title sequences
    private func stripTerminalEscapes(_ text: String) -> String {
        var result = text
        
        // Remove OSC (Operating System Command) sequences like ]0;title
        result = result.replacingOccurrences(of: "\\]0;[^\\u{07}\\u{1B}]*[\\u{07}]?", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "]0;[^\u{07}\u{1B}]*", with: "", options: .regularExpression)
        
        // Remove ANSI CSI sequences
        result = result.replacingOccurrences(of: "\\u{1B}\\[[0-9;?]*[A-Za-z]", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[A-Za-z]", with: "", options: .regularExpression)
        
        // Remove bare escape characters
        result = result.replacingOccurrences(of: "\u{1B}", with: "")
        result = result.replacingOccurrences(of: "\u{07}", with: "") // Bell character
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Server Status Detection
    
    /// Fetch complete server status - all software checked SEQUENTIALLY
    func fetchServerStatus(via session: TerminalViewModel) async -> ServerStatus {
        log("🔍 Checking server software status (sequential)...")
        var status = ServerStatus()
        
        // Web Servers (check one at a time)
        status.nginx = await checkSoftwareStatus("nginx", service: "nginx", via: session)
        status.apache = await checkSoftwareStatus("apache2", service: "apache2", via: session)
        // LiteSpeed uses different detection
        let lsResult = await executeCommand("ls /usr/local/lsws/bin/lshttpd 2>/dev/null && echo 'installed'", via: session, timeout: 10)
        if cleanOutput(lsResult.output).contains("installed") {
            status.litespeed = .installed(version: "detected")
        }
        
        // Databases
        status.mysql = await checkSoftwareStatus("mysql", service: "mysql", via: session)
        status.mariadb = await checkSoftwareStatus("mariadb", service: "mariadb", via: session)
        status.postgresql = await checkSoftwareStatus("psql", service: "postgresql", via: session)
        status.redis = await checkSoftwareStatus("redis-server", service: "redis-server", via: session)
        
        // Runtimes
        status.php = await checkPHPStatus(via: session)
        status.python = await checkSoftwareStatus("python3", service: nil, via: session)
        status.nodejs = await checkNodeStatus(via: session)
        
        // Tools
        status.composer = await checkToolStatus("composer", via: session)
        status.npm = await checkToolStatus("npm", via: session)
        status.git = await checkToolStatus("git", via: session)
        
        log("✅ Server status check complete")
        log("   Web: nginx=\(status.nginx.isInstalled), apache=\(status.apache.isInstalled)")
        log("   DB: mysql=\(status.mysql.isInstalled), pgsql=\(status.postgresql.isInstalled)")
        log("   Runtime: php=\(status.php.isInstalled), node=\(status.nodejs.isInstalled)")
        
        return status
    }
    
    /// Check if a software is installed and optionally if its service is running
    private func checkSoftwareStatus(_ binary: String, service: String?, via session: TerminalViewModel) async -> SoftwareStatus {
        // First check if binary exists using 'which'
        let whichResult = await executeCommand("which \(binary) 2>/dev/null", via: session, timeout: 10)
        let binaryPath = cleanOutput(whichResult.output)
        
        guard !binaryPath.isEmpty && binaryPath.hasPrefix("/") else {
            // Binary not found, try checking if service exists
            if let serviceName = service {
                let serviceResult = await executeCommand("systemctl list-unit-files | grep '\(serviceName)' | head -1 2>/dev/null", via: session, timeout: 10)
                if !cleanOutput(serviceResult.output).isEmpty {
                    // Service exists but binary not in path - get version from service
                    return await getServiceVersion(serviceName, via: session)
                }
            }
            return .notInstalled
        }
        
        // Get version from binary
        var version = "installed"
        let versionResult = await executeCommand("\(binary) --version 2>/dev/null | head -1", via: session, timeout: 10)
        let versionOutput = cleanOutput(versionResult.output)
        
        // Extract version number
        if let match = versionOutput.range(of: "[0-9]+\\.[0-9]+", options: .regularExpression) {
            version = String(versionOutput[match])
        } else if !versionOutput.isEmpty && versionOutput.count < 50 {
            version = versionOutput
        }
        
        // If no service to check, just return installed
        guard let serviceName = service else {
            return .installed(version: version)
        }
        
        // Check if service is running
        let statusResult = await executeCommand("systemctl is-active \(serviceName) 2>/dev/null", via: session, timeout: 10)
        let isActive = cleanOutput(statusResult.output) == "active"
        
        return isActive ? .running(version: version) : .stopped(version: version)
    }
    
    /// Get version from a service
    private func getServiceVersion(_ service: String, via session: TerminalViewModel) async -> SoftwareStatus {
        let statusResult = await executeCommand("systemctl is-active \(service) 2>/dev/null", via: session, timeout: 10)
        let isActive = cleanOutput(statusResult.output) == "active"
        return isActive ? .running(version: "detected") : .stopped(version: "detected")
    }
    
    /// Special handling for PHP (php-fpm or php-cli)
    private func checkPHPStatus(via session: TerminalViewModel) async -> SoftwareStatus {
        // Try php command first
        let phpResult = await executeCommand("php -v 2>/dev/null | head -1 | awk '{print $2}'", via: session, timeout: 10)
        let version = cleanOutput(phpResult.output)
        
        guard !version.isEmpty && version.first?.isNumber == true else {
            return .notInstalled
        }
        
        // Check if php-fpm is running
        let fpmResult = await executeCommand("systemctl is-active php*-fpm 2>/dev/null | head -1", via: session, timeout: 10)
        let isActive = cleanOutput(fpmResult.output) == "active"
        
        return isActive ? .running(version: version) : .installed(version: version)
    }
    
    /// Special handling for Node.js
    private func checkNodeStatus(via session: TerminalViewModel) async -> SoftwareStatus {
        let nodeResult = await executeCommand("node -v 2>/dev/null", via: session, timeout: 10)
        var version = cleanOutput(nodeResult.output)
        
        guard !version.isEmpty else {
            return .notInstalled
        }
        
        // Remove 'v' prefix if present
        if version.hasPrefix("v") {
            version = String(version.dropFirst())
        }
        
        return .installed(version: version)
    }
    
    /// Check tool availability (composer, npm, git)
    private func checkToolStatus(_ tool: String, via session: TerminalViewModel) async -> SoftwareStatus {
        let result = await executeCommand("\(tool) --version 2>/dev/null | head -1", via: session, timeout: 10)
        let output = cleanOutput(result.output)
        
        guard !output.isEmpty && !output.contains("not found") else {
            return .notInstalled
        }
        
        // Extract version from output
        var version = output
        if let match = output.range(of: "[0-9]+\\.[0-9]+", options: .regularExpression) {
            version = String(output[match])
        }
        
        return .installed(version: version)
    }
    
    // MARK: - Server Stats
    
    /// Fetch comprehensive server stats
    func fetchServerStats(via session: TerminalViewModel) async -> ParsedServerStats {
        log("Fetching server stats...")
        var stats = ParsedServerStats()
        
        // 1. CPU Load
        let loadResult = await executeCommand("cat /proc/loadavg", via: session)
        if let load = parseLoadAverage(loadResult.output) {
            stats.cpuUsage = load
            log("CPU Load: \(load)")
        }
        
        // 2. Memory
        let memResult = await executeCommand("free -m | grep Mem", via: session)
        let (used, total) = parseMemory(memResult.output)
        stats.ramUsed = used
        stats.ramTotal = total
        stats.ramUsage = total > 0 ? Double(used) / Double(total) : 0
        log("RAM: \(used)MB / \(total)MB (\(Int(stats.ramUsage * 100))%)")
        
        // 3. Disk
        let diskResult = await executeCommand("df -h / | tail -1", via: session)
        let (diskUsed, diskTotal, diskPercent) = parseDisk(diskResult.output)
        stats.diskUsed = diskUsed
        stats.diskTotal = diskTotal
        stats.diskUsage = diskPercent
        log("Disk: \(diskUsed) / \(diskTotal) (\(Int(diskPercent * 100))%)")
        
        // 4. Uptime
        let uptimeResult = await executeCommand("uptime -p", via: session)
        stats.uptime = cleanOutput(uptimeResult.output)
        log("Uptime: \(stats.uptime)")
        
        // 5. Hostname
        let hostnameResult = await executeCommand("hostname", via: session)
        stats.hostname = cleanOutput(hostnameResult.output)
        log("Hostname: \(stats.hostname)")
        
        // 6. IP
        let ipResult = await executeCommand("hostname -I | awk '{print $1}'", via: session)
        stats.ipAddress = cleanOutput(ipResult.output)
        log("IP: \(stats.ipAddress)")
        
        // 7. OS
        let osResult = await executeCommand("cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"'", via: session)
        stats.osName = cleanOutput(osResult.output)
        log("OS: \(stats.osName)")
        
        return stats
    }
    
    // MARK: - Installed Packages
    
    /// Fetch installed packages (Debian/Ubuntu)
    func fetchInstalledPackages(via session: TerminalViewModel) async -> [InstalledSoftware] {
        log("Fetching installed packages...")
        
        // Get key packages that are commonly managed
        let keyPackages = ["nginx", "apache2", "php", "mysql-server", "mariadb-server", 
                          "postgresql", "redis-server", "nodejs", "docker", "docker.io",
                          "python3", "composer", "npm", "git"]
        
        var installed: [InstalledSoftware] = []
        
        for pkg in keyPackages {
            let result = await executeCommand("dpkg -l | grep -E '^ii\\s+\(pkg)' | head -1", via: session)
            if !result.output.isEmpty && result.output.contains("ii") {
                let parts = result.output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 3 {
                    let name = parts[1]
                    let version = parts[2]
                    
                    // Check if service is running
                    var serviceName = name
                    
                    // Map package names to service names
                    let serviceMap = [
                        "mysql-server": "mysql",
                        "mariadb-server": "mariadb", 
                        "redis-server": "redis-server",
                        "postgresql": "postgresql",
                        "apache2": "apache2",
                        "nginx": "nginx"
                    ]
                    
                    if let mappedName = serviceMap[name] {
                        serviceName = mappedName
                    }
                    
                    let statusResult = await executeCommand("systemctl is-active \(serviceName) 2>/dev/null || echo 'inactive'", via: session)
                    let isRunning = cleanOutput(statusResult.output).contains("active")
                    
                    installed.append(InstalledSoftware(
                        name: name,
                        version: version,
                        iconName: iconForPackage(name),
                        isRunning: isRunning
                    ))
                    log("Found: \(name) v\(version) (\(isRunning ? "running" : "stopped"))")
                }
            }
        }
        
        log("Total installed packages found: \(installed.count)")
        return installed
    }
    
    // MARK: - Running Services
    
    /// Fetch running services
    func fetchRunningServices(via session: TerminalViewModel) async -> [ParsedServiceStatus] {
        log("Fetching running services...")
        
        let result = await executeCommand("systemctl list-units --type=service --state=running --no-pager --no-legend | head -20", via: session)
        
        var services: [ParsedServiceStatus] = []
        let lines = result.output.components(separatedBy: .newlines)
        
        for line in lines {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 4, parts[0].hasSuffix(".service") {
                let name = parts[0].replacingOccurrences(of: ".service", with: "")
                let description = parts.dropFirst(4).joined(separator: " ")
                services.append(ParsedServiceStatus(
                    name: name,
                    isRunning: true,
                    description: description
                ))
            }
        }
        
        log("Found \(services.count) running services")
        return services
    }
    
    // MARK: - Websites (Nginx & Apache)
    
    /// Fetch nginx sites - uses single command to avoid output pollution
    func fetchNginxSites(via session: TerminalViewModel) async -> [Website] {
        log("Fetching Nginx sites...")
        
        // Single command to list all site files
        let result = await executeCommand("ls -1 /etc/nginx/sites-enabled/ 2>/dev/null", via: session, timeout: 10)
        let output = cleanOutput(result.output)
        
        guard !output.isEmpty && !output.contains("cannot access") else {
            log("No Nginx sites-enabled directory or empty")
            return []
        }
        
        var sites: [Website] = []
        
        // Parse only valid config file names
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let siteName = line.trimmingCharacters(in: .whitespaces)
            
            // Skip invalid entries
            guard isValidSiteConfig(siteName) else {
                log("Skipping invalid site entry: \(siteName)")
                continue
            }
            
            // Get site details with a single grep command
            let configResult = await executeCommand(
                "grep -E '^[^#]*(server_name|root|listen)' /etc/nginx/sites-enabled/'\(siteName)' 2>/dev/null | head -10",
                via: session, timeout: 10
            )
            
            let config = parseSiteConfig(configResult.output, siteName: siteName, framework: "Nginx")
            sites.append(config)
            log("Found Nginx site: \(config.domain)")
        }
        
        log("Total Nginx sites: \(sites.count)")
        return sites
    }
    
    /// Fetch Apache sites
    func fetchApacheSites(via session: TerminalViewModel) async -> [Website] {
        log("Fetching Apache sites...")
        
        // Check Apache sites-enabled directory
        let result = await executeCommand("ls -1 /etc/apache2/sites-enabled/ 2>/dev/null", via: session, timeout: 10)
        let output = cleanOutput(result.output)
        
        guard !output.isEmpty && !output.contains("cannot access") else {
            log("No Apache sites-enabled directory or empty")
            return []
        }
        
        var sites: [Website] = []
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let siteName = line.trimmingCharacters(in: .whitespaces)
            
            guard isValidSiteConfig(siteName) else {
                continue
            }
            
            // Get Apache virtual host details 
            let configResult = await executeCommand(
                "grep -E '^[^#]*(ServerName|DocumentRoot|<VirtualHost)' /etc/apache2/sites-enabled/'\(siteName)' 2>/dev/null | head -10",
                via: session, timeout: 10
            )
            
            var domain = siteName.replacingOccurrences(of: ".conf", with: "")
            var path = "/var/www/html"
            var port = 80
            
            let configLines = configResult.output.components(separatedBy: .newlines)
            for configLine in configLines {
                let trimmed = configLine.trimmingCharacters(in: .whitespaces)
                
                if trimmed.contains("ServerName") {
                    let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 2 {
                        domain = parts[1]
                    }
                }
                if trimmed.contains("DocumentRoot") {
                    let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 2 {
                        path = parts[1].replacingOccurrences(of: "\"", with: "")
                    }
                }
                if trimmed.contains("<VirtualHost") {
                    if let portMatch = trimmed.range(of: ":(\\d+)", options: .regularExpression) {
                        let portStr = trimmed[portMatch].dropFirst() // Remove ':'
                        port = Int(portStr) ?? 80
                    }
                }
            }
            
            sites.append(Website(
                domain: domain,
                path: path,
                status: .running,
                port: port,
                framework: "Apache"
            ))
            log("Found Apache site: \(domain)")
        }
        
        log("Total Apache sites: \(sites.count)")
        return sites
    }
    
    /// Validate that a filename is a valid site config (not garbage from terminal)
    private func isValidSiteConfig(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        
        // Must not be empty
        guard !trimmed.isEmpty else { return false }
        
        // Must not contain terminal garbage
        let invalidPatterns = ["@", "#", "$", "root", "grep", "ls ", "dpkg", "echo", "total ", "drwx", "-bash", "inactive"]
        for pattern in invalidPatterns {
            if trimmed.contains(pattern) { return false }
        }
        
        // Must be reasonable length
        guard trimmed.count < 100 else { return false }
        
        // Must look like a filename (alphanumeric, dots, dashes, underscores)
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        guard trimmed.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else { return false }
        
        // Skip 'default' unless it's a real config
        if trimmed == "default" { return false }
        
        return true
    }
    
    /// Parse site config output into Website model
    private func parseSiteConfig(_ output: String, siteName: String, framework: String) -> Website {
        var domain = siteName.replacingOccurrences(of: ".conf", with: "")
        var path = "/var/www/\(domain)"
        var port = 80
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.contains("server_name") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 && parts[1] != "_" && parts[1] != ";" {
                    domain = parts[1].replacingOccurrences(of: ";", with: "")
                }
            }
            if trimmed.contains("root") && !trimmed.contains("root@") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    path = parts[1].replacingOccurrences(of: ";", with: "")
                }
            }
            if trimmed.contains("listen") {
                if let portMatch = trimmed.range(of: "\\d+", options: .regularExpression) {
                    port = Int(trimmed[portMatch]) ?? 80
                }
            }
        }
        
        return Website(
            domain: domain,
            path: path,
            status: .running,
            port: port,
            framework: framework
        )
    }
    
    // MARK: - Files
    
    /// Fetch files and directories at the given path
    func fetchFiles(at path: String, via session: TerminalViewModel) async -> [ServerFileItem] {
        log("Fetching files at: \(path)")
        
        // Use ls -la to get file details
        let result = await executeCommand("ls -la '\(path)' 2>/dev/null", via: session, timeout: 30)
        
        var files: [ServerFileItem] = []
        let lines = result.output.components(separatedBy: .newlines)
        
        for line in lines {
            // Skip empty lines, total line, and prompt remnants
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("total"),
                  !trimmed.contains("@"),
                  !trimmed.contains("#"),
                  !trimmed.contains("$") else { continue }
            
            // Parse ls -la format: drwxr-xr-x 2 root root 4096 Jan 10 12:00 dirname
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 9 else { continue }
            
            let permissions = parts[0]
            let owner = parts[2]
            let group = parts[3]
            let sizeStr = parts[4]
            // Date parts: Jan 10 12:00 or Jan 10 2024
            let dateStr = "\(parts[5]) \(parts[6]) \(parts[7])"
            // Name is everything after the 8th field (to handle filenames with spaces)
            let name = parts.dropFirst(8).joined(separator: " ")
            
            // Skip . and .. entries
            guard name != "." && name != ".." else { continue }
            
            // Determine if directory
            let isDirectory = permissions.hasPrefix("d")
            
            // Convert symbolic permissions to octal
            let octalPermissions = symbolicToOctal(permissions)
            
            // Parse size
            let size = Int64(sizeStr) ?? 0
            
            // Parse date
            let date = parseLsDate(dateStr)
            
            files.append(ServerFileItem(
                name: name,
                isDirectory: isDirectory,
                sizeBytes: size,
                permissions: octalPermissions,
                modificationDate: date,
                owner: "\(owner):\(group)"
            ))
        }
        
        log("Found \(files.count) files at \(path)")
        return files
    }
    
    private func symbolicToOctal(_ symbolic: String) -> String {
        // drwxr-xr-x -> 755
        guard symbolic.count >= 10 else { return "644" }
        
        func tripleToOctal(_ chars: String) -> Int {
            var val = 0
            let arr = Array(chars)
            if arr.count >= 1 && arr[0] != "-" { val += 4 }
            if arr.count >= 2 && arr[1] != "-" { val += 2 }
            if arr.count >= 3 && arr[2] != "-" { val += 1 }
            return val
        }
        
        let owner = String(symbolic.dropFirst(1).prefix(3))
        let group = String(symbolic.dropFirst(4).prefix(3))
        let other = String(symbolic.dropFirst(7).prefix(3))
        
        return "\(tripleToOctal(owner))\(tripleToOctal(group))\(tripleToOctal(other))"
    }
    
    private func parseLsDate(_ dateStr: String) -> Date {
        // Try parsing formats like "Jan 10 12:00" or "Jan 10 2024"
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "MMM dd HH:mm"
        formatter1.locale = Locale(identifier: "en_US_POSIX")
        
        let formatter2 = DateFormatter()
        formatter2.dateFormat = "MMM dd yyyy"
        formatter2.locale = Locale(identifier: "en_US_POSIX")
        
        // Add current year for time-based format
        let withYear = dateStr + " 2026"
        let formatter3 = DateFormatter()
        formatter3.dateFormat = "MMM dd HH:mm yyyy"
        formatter3.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = formatter1.date(from: dateStr) {
            // Set year to current
            var components = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: date)
            components.year = Calendar.current.component(.year, from: Date())
            return Calendar.current.date(from: components) ?? Date()
        }
        
        if let date = formatter2.date(from: dateStr) {
            return date
        }
        
        if let date = formatter3.date(from: withYear) {
            return date
        }
        
        return Date()
    }
    
    // MARK: - Databases
    
    /// Fetch MySQL databases
    func fetchMySQLDatabases(via session: TerminalViewModel) async -> [Database] {
        log("Fetching MySQL databases...")
        
        // First check if MySQL is installed
        let checkResult = await executeCommand("which mysql 2>/dev/null", via: session, timeout: 10)
        if cleanOutput(checkResult.output).isEmpty || cleanOutput(checkResult.output).contains("not found") {
            log("MySQL not installed")
            return []
        }
        
        let result = await executeCommand("mysql -e 'SHOW DATABASES' 2>/dev/null", via: session, timeout: 15)
        
        // Check for errors or empty output
        let cleanedOutput = cleanOutput(result.output)
        if cleanedOutput.isEmpty || cleanedOutput.contains("error") || cleanedOutput.contains("denied") {
            log("MySQL not available or no access")
            return []
        }
        
        var databases: [Database] = []
        let lines = result.output.components(separatedBy: .newlines)
        
        for line in lines {
            let dbName = line.trimmingCharacters(in: .whitespaces)
            
            // Validate database name
            guard isValidDatabaseName(dbName, skipSystem: true) else { continue }
            
            databases.append(Database(
                name: dbName,
                type: .mysql,
                sizeBytes: 0,
                status: .active
            ))
            log("Found MySQL DB: \(dbName)")
        }
        
        log("Total MySQL databases: \(databases.count)")
        return databases
    }
    
    /// Fetch PostgreSQL databases
    func fetchPostgreSQLDatabases(via session: TerminalViewModel) async -> [Database] {
        log("Fetching PostgreSQL databases...")
        
        // Check if PostgreSQL is installed
        let checkResult = await executeCommand("which psql 2>/dev/null", via: session, timeout: 10)
        if cleanOutput(checkResult.output).isEmpty {
            log("PostgreSQL not installed")
            return []
        }
        
        // List databases using psql
        let result = await executeCommand("sudo -u postgres psql -t -c 'SELECT datname FROM pg_database WHERE datistemplate = false;' 2>/dev/null", via: session, timeout: 15)
        
        let cleanedOutput = cleanOutput(result.output)
        if cleanedOutput.isEmpty || cleanedOutput.contains("error") || cleanedOutput.contains("denied") {
            log("PostgreSQL not available or no access")
            return []
        }
        
        var databases: [Database] = []
        let lines = result.output.components(separatedBy: .newlines)
        
        for line in lines {
            let dbName = line.trimmingCharacters(in: .whitespaces)
            
            // Validate database name
            guard isValidDatabaseName(dbName, skipSystem: false) else { continue }
            
            // Skip template and system databases
            if dbName == "postgres" || dbName.hasPrefix("template") { continue }
            
            databases.append(Database(
                name: dbName,
                type: .postgres,
                sizeBytes: 0,
                status: .active
            ))
            log("Found PostgreSQL DB: \(dbName)")
        }
        
        log("Total PostgreSQL databases: \(databases.count)")
        return databases
    }
    
    /// Validate that a string is a valid database name (not garbage)
    private func isValidDatabaseName(_ name: String, skipSystem: Bool) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        
        // Must not be empty and reasonable length
        guard !trimmed.isEmpty, trimmed.count < 64, trimmed.count > 1 else { return false }
        
        // Must not contain terminal garbage
        let invalidPatterns = ["@", "#", "$", ":", "root", "vmi", "bash", "inactive", "grep", "echo", "ls "]
        for pattern in invalidPatterns {
            if trimmed.contains(pattern) { return false }
        }
        
        // Skip column headers
        if trimmed == "Database" || trimmed == "datname" { return false }
        
        // Skip system databases if requested
        if skipSystem {
            let systemDbs = ["information_schema", "performance_schema", "mysql", "sys"]
            if systemDbs.contains(trimmed) { return false }
        }
        
        // Must look like a valid identifier (alphanumeric and underscores)
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard trimmed.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else { return false }
        
        return true
    }
    
    // MARK: - Install Package

    /// Install a package via apt/yum with streaming output
    func installPackage(_ command: String, via session: TerminalViewModel, onOutput: @escaping (String) -> Void) async -> Bool {
        log("Installing package: \(command)")

        // Send the install command
        session.terminalEngine.sendInput("\(command)\n")

        // Stream output
        var lastLineCount = session.outputLines.count
        var attempts = 0
        let maxAttempts = 600 // 60 seconds max for installation

        while attempts < maxAttempts {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // Check for new lines
            if session.outputLines.count > lastLineCount {
                let newLines = session.outputLines.dropFirst(lastLineCount)
                for line in newLines {
                    onOutput(line.text)
                }
                lastLineCount = session.outputLines.count
            }

            // Check if command completed (prompt returned)
            if let lastLine = session.outputLines.last?.text,
               (lastLine.contains("#") || lastLine.contains("$")) && attempts > 10 {
                break
            }

            attempts += 1
        }

        log("Installation completed")
        return true
    }

    // MARK: - Website Management (Real SSH)

    /// Create Nginx virtual host configuration
    func createNginxSite(domain: String, path: String, port: Int, phpVersion: String?, via session: TerminalViewModel) async -> Bool {
        log("Creating Nginx site for \(domain)")

        // Build Nginx config
        var config = """
        server {
            listen 80;
            listen [::]:80;

            server_name \(domain) www.\(domain);
            root \(path);
            index index.html index.htm index.php;

            location / {
                try_files $uri $uri/ =404;
            }
        """

        // Add PHP support if version specified
        if let php = phpVersion {
            config += """


            location ~ \\.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/var/run/php/php\(php)-fpm.sock;
            }

            location ~ /\\.ht {
                deny all;
            }
        """
        }

        config += "\n}"

        // Create config file using base64 to avoid escaping issues
        if let data = config.data(using: .utf8) {
            let base64 = data.base64EncodedString()
            let configPath = "/etc/nginx/sites-available/\(domain)"

            // Write config file
            _ = await executeCommand("echo '\(base64)' | base64 --decode | sudo tee \(configPath) > /dev/null", via: session, timeout: 15)

            // Enable site (create symlink)
            _ = await executeCommand("sudo ln -sf \(configPath) /etc/nginx/sites-enabled/\(domain)", via: session, timeout: 10)

            // Test nginx configuration
            let testResult = await executeCommand("sudo nginx -t 2>&1", via: session, timeout: 15)
            if cleanOutput(testResult.output).contains("successful") || cleanOutput(testResult.output).contains("ok") {
                // Reload nginx
                _ = await executeCommand("sudo systemctl reload nginx", via: session, timeout: 15)
                log("✅ Nginx site \(domain) created and enabled")
                return true
            } else {
                log("❌ Nginx config test failed: \(testResult.output)")
                // Rollback - remove bad config
                _ = await executeCommand("sudo rm -f /etc/nginx/sites-enabled/\(domain) /etc/nginx/sites-available/\(domain)", via: session, timeout: 10)
                return false
            }
        }
        return false
    }

    /// Create Apache virtual host configuration
    func createApacheSite(domain: String, path: String, port: Int, via session: TerminalViewModel) async -> Bool {
        log("Creating Apache site for \(domain)")

        let config = """
        <VirtualHost *:\(port)>
            ServerName \(domain)
            ServerAlias www.\(domain)
            DocumentRoot \(path)

            <Directory \(path)>
                Options Indexes FollowSymLinks
                AllowOverride All
                Require all granted
            </Directory>

            ErrorLog ${APACHE_LOG_DIR}/\(domain)_error.log
            CustomLog ${APACHE_LOG_DIR}/\(domain)_access.log combined
        </VirtualHost>
        """

        if let data = config.data(using: .utf8) {
            let base64 = data.base64EncodedString()
            let configPath = "/etc/apache2/sites-available/\(domain).conf"

            // Write config file
            _ = await executeCommand("echo '\(base64)' | base64 --decode | sudo tee \(configPath) > /dev/null", via: session, timeout: 15)

            // Enable site
            _ = await executeCommand("sudo a2ensite \(domain).conf", via: session, timeout: 15)

            // Test apache configuration
            let testResult = await executeCommand("sudo apache2ctl configtest 2>&1", via: session, timeout: 15)
            if cleanOutput(testResult.output).contains("Syntax OK") || testResult.output.isEmpty {
                // Reload apache
                _ = await executeCommand("sudo systemctl reload apache2", via: session, timeout: 15)
                log("✅ Apache site \(domain) created and enabled")
                return true
            } else {
                log("❌ Apache config test failed: \(testResult.output)")
                // Rollback
                _ = await executeCommand("sudo a2dissite \(domain).conf && sudo rm -f \(configPath)", via: session, timeout: 10)
                return false
            }
        }
        return false
    }

    /// Delete website (Nginx or Apache)
    func deleteWebsite(domain: String, path: String?, deleteFiles: Bool, webServer: String, via session: TerminalViewModel) async -> Bool {
        log("Deleting website \(domain) from \(webServer)")

        if webServer.lowercased() == "nginx" {
            // Disable and remove Nginx site
            _ = await executeCommand("sudo rm -f /etc/nginx/sites-enabled/\(domain)", via: session, timeout: 10)
            _ = await executeCommand("sudo rm -f /etc/nginx/sites-available/\(domain)", via: session, timeout: 10)
            _ = await executeCommand("sudo systemctl reload nginx", via: session, timeout: 15)
        } else if webServer.lowercased() == "apache" {
            // Disable and remove Apache site
            _ = await executeCommand("sudo a2dissite \(domain).conf 2>/dev/null || true", via: session, timeout: 15)
            _ = await executeCommand("sudo rm -f /etc/apache2/sites-available/\(domain).conf", via: session, timeout: 10)
            _ = await executeCommand("sudo systemctl reload apache2", via: session, timeout: 15)
        }

        // Optionally delete files
        if deleteFiles, let sitePath = path, !sitePath.isEmpty && sitePath != "/" && sitePath != "/var" && sitePath != "/var/www" {
            _ = await executeCommand("sudo rm -rf '\(sitePath)'", via: session, timeout: 30)
            log("Deleted website files at \(sitePath)")
        }

        log("✅ Website \(domain) deleted")
        return true
    }

    /// Restart web server service
    func restartWebService(_ service: String, via session: TerminalViewModel) async -> Bool {
        log("Restarting \(service)...")
        let result = await executeCommand("sudo systemctl restart \(service)", via: session, timeout: 30)

        // Verify service is running
        let statusResult = await executeCommand("systemctl is-active \(service) 2>/dev/null", via: session, timeout: 10)
        let isActive = cleanOutput(statusResult.output) == "active"

        if isActive {
            log("✅ \(service) restarted successfully")
        } else {
            log("❌ \(service) restart may have failed")
        }
        return isActive
    }

    // MARK: - Database Management (Real SSH)

    /// Create MySQL/MariaDB database
    func createMySQLDatabase(name: String, username: String?, password: String?, via session: TerminalViewModel) async -> Bool {
        log("Creating MySQL database: \(name)")

        // Create database
        let createDbResult = await executeCommand("sudo mysql -e \"CREATE DATABASE IF NOT EXISTS \(name);\"", via: session, timeout: 15)

        // Create user if provided
        if let user = username, !user.isEmpty, let pass = password, !pass.isEmpty {
            _ = await executeCommand("sudo mysql -e \"CREATE USER IF NOT EXISTS '\(user)'@'localhost' IDENTIFIED BY '\(pass)';\"", via: session, timeout: 15)
            _ = await executeCommand("sudo mysql -e \"GRANT ALL PRIVILEGES ON \(name).* TO '\(user)'@'localhost';\"", via: session, timeout: 15)
            _ = await executeCommand("sudo mysql -e \"FLUSH PRIVILEGES;\"", via: session, timeout: 10)
        }

        log("✅ MySQL database \(name) created")
        return true
    }

    /// Create PostgreSQL database
    func createPostgreSQLDatabase(name: String, username: String?, password: String?, via session: TerminalViewModel) async -> Bool {
        log("Creating PostgreSQL database: \(name)")

        // Create database
        _ = await executeCommand("sudo -u postgres createdb \(name) 2>/dev/null || true", via: session, timeout: 15)

        // Create user if provided
        if let user = username, !user.isEmpty, let pass = password, !pass.isEmpty {
            _ = await executeCommand("sudo -u postgres psql -c \"CREATE USER \(user) WITH PASSWORD '\(pass)';\" 2>/dev/null || true", via: session, timeout: 15)
            _ = await executeCommand("sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE \(name) TO \(user);\"", via: session, timeout: 15)
        }

        log("✅ PostgreSQL database \(name) created")
        return true
    }

    /// Delete database (MySQL or PostgreSQL)
    func deleteDatabase(name: String, type: String, via session: TerminalViewModel) async -> Bool {
        log("Deleting \(type) database: \(name)")

        if type.lowercased().contains("mysql") || type.lowercased().contains("mariadb") {
            _ = await executeCommand("sudo mysql -e \"DROP DATABASE IF EXISTS \(name);\"", via: session, timeout: 15)
        } else if type.lowercased().contains("postgres") {
            _ = await executeCommand("sudo -u postgres dropdb \(name) 2>/dev/null || true", via: session, timeout: 15)
        }

        log("✅ Database \(name) deleted")
        return true
    }

    /// Backup MySQL database
    func backupMySQLDatabase(name: String, via session: TerminalViewModel) async -> String? {
        log("Backing up MySQL database: \(name)")

        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupPath = "/tmp/\(name)_\(timestamp).sql"

        let result = await executeCommand("sudo mysqldump \(name) > '\(backupPath)' 2>/dev/null && echo 'SUCCESS'", via: session, timeout: 120)

        if cleanOutput(result.output).contains("SUCCESS") {
            log("✅ Database backup saved to \(backupPath)")
            return backupPath
        }
        log("❌ Database backup failed")
        return nil
    }

    // MARK: - File Operations (Real SSH)

    /// Rename file on server
    func renameFile(at path: String, from oldName: String, to newName: String, via session: TerminalViewModel) async -> Bool {
        let oldPath = path == "/" ? "/\(oldName)" : "\(path)/\(oldName)"
        let newPath = path == "/" ? "/\(newName)" : "\(path)/\(newName)"

        log("Renaming \(oldPath) to \(newPath)")
        let result = await executeCommand("sudo mv '\(oldPath)' '\(newPath)' && echo 'SUCCESS'", via: session, timeout: 15)

        return cleanOutput(result.output).contains("SUCCESS")
    }

    /// Delete file or directory on server
    func deleteFile(at path: String, name: String, isDirectory: Bool, via session: TerminalViewModel) async -> Bool {
        let fullPath = path == "/" ? "/\(name)" : "\(path)/\(name)"

        // Safety check - don't delete critical paths
        let protectedPaths = ["/", "/etc", "/var", "/usr", "/bin", "/sbin", "/boot", "/root", "/home"]
        if protectedPaths.contains(fullPath) {
            log("❌ Cannot delete protected path: \(fullPath)")
            return false
        }

        log("Deleting \(fullPath)")
        let flag = isDirectory ? "-rf" : "-f"
        let result = await executeCommand("sudo rm \(flag) '\(fullPath)' && echo 'SUCCESS'", via: session, timeout: 30)

        return cleanOutput(result.output).contains("SUCCESS")
    }

    /// Change file permissions
    func changePermissions(at path: String, name: String, permissions: String, via session: TerminalViewModel) async -> Bool {
        let fullPath = path == "/" ? "/\(name)" : "\(path)/\(name)"

        log("Changing permissions of \(fullPath) to \(permissions)")
        let result = await executeCommand("sudo chmod \(permissions) '\(fullPath)' && echo 'SUCCESS'", via: session, timeout: 15)

        return cleanOutput(result.output).contains("SUCCESS")
    }

    /// Change file owner
    func changeOwner(at path: String, name: String, owner: String, via session: TerminalViewModel) async -> Bool {
        let fullPath = path == "/" ? "/\(name)" : "\(path)/\(name)"

        log("Changing owner of \(fullPath) to \(owner)")
        let result = await executeCommand("sudo chown \(owner) '\(fullPath)' && echo 'SUCCESS'", via: session, timeout: 15)

        return cleanOutput(result.output).contains("SUCCESS")
    }

    /// Create directory on server
    func createDirectory(at path: String, name: String, via session: TerminalViewModel) async -> Bool {
        let fullPath = path == "/" ? "/\(name)" : "\(path)/\(name)"

        log("Creating directory: \(fullPath)")
        let result = await executeCommand("sudo mkdir -p '\(fullPath)' && echo 'SUCCESS'", via: session, timeout: 15)

        return cleanOutput(result.output).contains("SUCCESS")
    }

    // MARK: - Service Management (Real SSH)

    /// Restart a system service
    func restartService(_ service: String, via session: TerminalViewModel) async -> Bool {
        log("Restarting service: \(service)")
        _ = await executeCommand("sudo systemctl restart \(service)", via: session, timeout: 30)

        // Verify service is running
        let statusResult = await executeCommand("systemctl is-active \(service) 2>/dev/null", via: session, timeout: 10)
        let isActive = cleanOutput(statusResult.output) == "active"

        log(isActive ? "✅ Service \(service) restarted" : "❌ Service \(service) may have failed")
        return isActive
    }

    /// Stop a system service
    func stopService(_ service: String, via session: TerminalViewModel) async -> Bool {
        log("Stopping service: \(service)")
        _ = await executeCommand("sudo systemctl stop \(service)", via: session, timeout: 30)

        let statusResult = await executeCommand("systemctl is-active \(service) 2>/dev/null", via: session, timeout: 10)
        let isStopped = cleanOutput(statusResult.output) != "active"

        log(isStopped ? "✅ Service \(service) stopped" : "❌ Service \(service) still running")
        return isStopped
    }

    /// Start a system service
    func startService(_ service: String, via session: TerminalViewModel) async -> Bool {
        log("Starting service: \(service)")
        _ = await executeCommand("sudo systemctl start \(service)", via: session, timeout: 30)

        let statusResult = await executeCommand("systemctl is-active \(service) 2>/dev/null", via: session, timeout: 10)
        let isActive = cleanOutput(statusResult.output) == "active"

        log(isActive ? "✅ Service \(service) started" : "❌ Service \(service) failed to start")
        return isActive
    }

    /// Change root password
    func changeRootPassword(newPassword: String, via session: TerminalViewModel) async -> Bool {
        log("Changing root password...")
        let result = await executeCommand("echo 'root:\(newPassword)' | sudo chpasswd && echo 'SUCCESS'", via: session, timeout: 15)
        return cleanOutput(result.output).contains("SUCCESS")
    }

    /// Change MySQL root password
    func changeMySQLRootPassword(newPassword: String, via session: TerminalViewModel) async -> Bool {
        log("Changing MySQL root password...")
        let result = await executeCommand("sudo mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '\(newPassword)'; FLUSH PRIVILEGES;\" && echo 'SUCCESS'", via: session, timeout: 15)
        return cleanOutput(result.output).contains("SUCCESS")
    }

    // MARK: - Traffic / Network Stats (Optimized)

    /// Fetch network traffic stats (lightweight)
    func fetchNetworkStats(via session: TerminalViewModel) async -> (rx: Int64, tx: Int64) {
        // Use /proc/net/dev for lightweight stats - single command
        let result = await executeCommand("cat /proc/net/dev | grep -E 'eth0|ens|enp' | head -1 | awk '{print $2,$10}'", via: session, timeout: 10)
        let parts = cleanOutput(result.output).components(separatedBy: " ").compactMap { Int64($0) }

        if parts.count >= 2 {
            return (rx: parts[0], tx: parts[1])
        }
        return (rx: 0, tx: 0)
    }

    // MARK: - Optimized Batch Commands

    /// Fetch all basic stats in a single command (optimized for performance)
    func fetchAllStatsOptimized(via session: TerminalViewModel) async -> ParsedServerStats {
        log("Fetching optimized server stats (batch)...")

        // Single compound command to get all stats at once - much faster than multiple calls
        let batchCommand = """
        echo "===HOSTNAME===" && hostname && \
        echo "===IP===" && hostname -I | awk '{print $1}' && \
        echo "===OS===" && cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' && \
        echo "===UPTIME===" && uptime -p && \
        echo "===LOAD===" && cat /proc/loadavg | awk '{print $1}' && \
        echo "===MEM===" && free -m | grep Mem | awk '{print $2,$3}' && \
        echo "===DISK===" && df -h / | tail -1 | awk '{print $2,$3,$5}'
        """

        let result = await executeCommand(batchCommand, via: session, timeout: 20)
        var stats = ParsedServerStats()

        // Parse the sectioned output
        let sections = result.output.components(separatedBy: "===")

        for section in sections {
            let lines = section.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
            guard let header = lines.first, lines.count > 1 else { continue }
            let value = lines.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)

            switch header {
            case "HOSTNAME":
                stats.hostname = cleanOutput(value)
            case "IP":
                stats.ipAddress = cleanOutput(value)
            case "OS":
                stats.osName = cleanOutput(value)
            case "UPTIME":
                stats.uptime = cleanOutput(value)
            case "LOAD":
                if let load = Double(cleanOutput(value)) {
                    stats.cpuUsage = min(load, 1.0)
                }
            case "MEM":
                let memParts = cleanOutput(value).components(separatedBy: " ").compactMap { Int($0) }
                if memParts.count >= 2 {
                    stats.ramTotal = memParts[0]
                    stats.ramUsed = memParts[1]
                    stats.ramUsage = stats.ramTotal > 0 ? Double(stats.ramUsed) / Double(stats.ramTotal) : 0
                }
            case "DISK":
                let diskParts = cleanOutput(value).components(separatedBy: " ").filter { !$0.isEmpty }
                if diskParts.count >= 3 {
                    stats.diskTotal = diskParts[0]
                    stats.diskUsed = diskParts[1]
                    let percentStr = diskParts[2].replacingOccurrences(of: "%", with: "")
                    stats.diskUsage = (Double(percentStr) ?? 0) / 100.0
                }
            default:
                break
            }
        }

        log("Optimized stats: CPU \(Int(stats.cpuUsage * 100))%, RAM \(Int(stats.ramUsage * 100))%, Disk \(Int(stats.diskUsage * 100))%")
        return stats
    }

    /// Check multiple software statuses in optimized batch
    func fetchServerStatusOptimized(via session: TerminalViewModel) async -> ServerStatus {
        log("🔍 Checking server software status (optimized batch)...")
        var status = ServerStatus()

        // Improved batch command that checks both binary existence AND version
        // Uses 'which' as fallback to ensure we detect installed software
        let batchCommand = """
        echo "===NGINX===" && (which nginx >/dev/null 2>&1 && nginx -v 2>&1 | head -1 || echo "not_installed") && (systemctl is-active nginx 2>/dev/null || echo "inactive") && \
        echo "===APACHE===" && (which apache2 >/dev/null 2>&1 && apache2 -v 2>&1 | head -1 || echo "not_installed") && (systemctl is-active apache2 2>/dev/null || echo "inactive") && \
        echo "===MYSQL===" && (which mysql >/dev/null 2>&1 && mysql --version 2>/dev/null | head -1 || echo "not_installed") && (systemctl is-active mysql 2>/dev/null || systemctl is-active mariadb 2>/dev/null || echo "inactive") && \
        echo "===PHP===" && (which php >/dev/null 2>&1 && php -v 2>/dev/null | head -1 || echo "not_installed") && (systemctl list-units --type=service --state=running | grep -q 'php.*fpm' && echo "active" || echo "inactive") && \
        echo "===NODE===" && (which node >/dev/null 2>&1 && node -v 2>/dev/null || echo "not_installed") && \
        echo "===PGSQL===" && (which psql >/dev/null 2>&1 && psql --version 2>/dev/null | head -1 || echo "not_installed") && (systemctl is-active postgresql 2>/dev/null || echo "inactive") && \
        echo "===REDIS===" && (which redis-server >/dev/null 2>&1 && redis-server --version 2>/dev/null | head -1 || echo "not_installed") && (systemctl is-active redis-server 2>/dev/null || systemctl is-active redis 2>/dev/null || echo "inactive") && \
        echo "===GIT===" && (which git >/dev/null 2>&1 && git --version 2>/dev/null | head -1 || echo "not_installed") && \
        echo "===PYTHON===" && (which python3 >/dev/null 2>&1 && python3 --version 2>/dev/null || echo "not_installed") && \
        echo "===COMPOSER===" && (which composer >/dev/null 2>&1 && composer --version 2>/dev/null | head -1 || echo "not_installed")
        """

        let result = await executeCommand(batchCommand, via: session, timeout: 45)
        let sections = result.output.components(separatedBy: "===")

        for section in sections {
            let lines = section.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard let header = lines.first, lines.count > 1 else { continue }

            let versionLine = lines.count > 1 ? lines[1] : ""
            let statusLine = lines.count > 2 ? lines[2] : ""
            let isActive = statusLine == "active"

            // Check if software is installed (not just version detection)
            let isInstalled = !versionLine.contains("not_installed") &&
                              !versionLine.contains("not found") &&
                              !versionLine.contains("No such file") &&
                              !versionLine.isEmpty

            // Extract version number with improved regex patterns
            var version: String? = nil
            if isInstalled {
                // Try multiple version patterns
                let patterns = [
                    "[0-9]+\\.[0-9]+\\.[0-9]+",  // X.Y.Z
                    "[0-9]+\\.[0-9]+",           // X.Y
                    "v[0-9]+\\.[0-9]+",          // vX.Y
                ]
                for pattern in patterns {
                    if let match = versionLine.range(of: pattern, options: .regularExpression) {
                        var v = String(versionLine[match])
                        if v.hasPrefix("v") { v = String(v.dropFirst()) }
                        version = v
                        break
                    }
                }
                // Fallback: if no version found but software is installed, use "installed"
                if version == nil {
                    version = "installed"
                }
            }

            switch header {
            case "NGINX":
                if let v = version {
                    status.nginx = isActive ? .running(version: v) : .installed(version: v)
                    log("  Nginx: \(status.nginx)")
                }
            case "APACHE":
                if let v = version {
                    status.apache = isActive ? .running(version: v) : .installed(version: v)
                    log("  Apache: \(status.apache)")
                }
            case "MYSQL":
                if let v = version {
                    // Check if it's MariaDB
                    if versionLine.lowercased().contains("mariadb") {
                        status.mariadb = isActive ? .running(version: v) : .installed(version: v)
                        log("  MariaDB: \(status.mariadb)")
                    } else {
                        status.mysql = isActive ? .running(version: v) : .installed(version: v)
                        log("  MySQL: \(status.mysql)")
                    }
                }
            case "PHP":
                if let v = version {
                    // For PHP, check if PHP-FPM is running
                    status.php = isActive ? .running(version: v) : .installed(version: v)
                    log("  PHP: \(status.php)")
                }
            case "NODE":
                if isInstalled {
                    var v = versionLine.trimmingCharacters(in: .whitespaces)
                    if v.hasPrefix("v") { v = String(v.dropFirst()) }
                    if !v.isEmpty && !v.contains("not_installed") {
                        status.nodejs = .installed(version: v)
                        log("  Node.js: \(status.nodejs)")
                    }
                }
            case "PGSQL":
                if let v = version {
                    status.postgresql = isActive ? .running(version: v) : .installed(version: v)
                    log("  PostgreSQL: \(status.postgresql)")
                }
            case "REDIS":
                if let v = version {
                    status.redis = isActive ? .running(version: v) : .installed(version: v)
                    log("  Redis: \(status.redis)")
                }
            case "GIT":
                if let v = version {
                    status.git = .installed(version: v)
                    log("  Git: \(status.git)")
                }
            case "PYTHON":
                if isInstalled {
                    var v = versionLine.replacingOccurrences(of: "Python ", with: "").trimmingCharacters(in: .whitespaces)
                    if !v.isEmpty && !v.contains("not_installed") {
                        status.python = .installed(version: v)
                        log("  Python: \(status.python)")
                    }
                }
            case "COMPOSER":
                if let v = version {
                    status.composer = .installed(version: v)
                    log("  Composer: \(status.composer)")
                }
            default:
                break
            }
        }

        log("✅ Optimized status check complete - hasWebServer: \(status.hasWebServer), hasDatabase: \(status.hasDatabase)")
        return status
    }

    // MARK: - Domain Management (Real SSH)

    /// Get list of domains configured on server
    func fetchConfiguredDomains(via session: TerminalViewModel) async -> [String] {
        log("Fetching configured domains...")
        var domains: [String] = []

        // Check Nginx sites
        let nginxResult = await executeCommand("grep -h server_name /etc/nginx/sites-enabled/* 2>/dev/null | grep -oE '[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}' | sort -u", via: session, timeout: 15)
        let nginxDomains = cleanOutput(nginxResult.output).components(separatedBy: .newlines).filter { !$0.isEmpty && $0.contains(".") }
        domains.append(contentsOf: nginxDomains)

        // Check Apache sites
        let apacheResult = await executeCommand("grep -h ServerName /etc/apache2/sites-enabled/* 2>/dev/null | awk '{print $2}' | sort -u", via: session, timeout: 15)
        let apacheDomains = cleanOutput(apacheResult.output).components(separatedBy: .newlines).filter { !$0.isEmpty && $0.contains(".") }
        domains.append(contentsOf: apacheDomains)

        // Remove duplicates
        let uniqueDomains = Array(Set(domains)).sorted()
        log("Found \(uniqueDomains.count) configured domains")
        return uniqueDomains
    }

    /// Add domain alias to existing site
    func addDomainAlias(mainDomain: String, aliasDomain: String, webServer: String, via session: TerminalViewModel) async -> Bool {
        log("Adding domain alias \(aliasDomain) to \(mainDomain)")

        if webServer.lowercased() == "nginx" {
            // Update Nginx server_name to include alias
            let configPath = "/etc/nginx/sites-available/\(mainDomain)"
            _ = await executeCommand("sudo sed -i 's/server_name \\(.*\\);/server_name \\1 \(aliasDomain);/' \(configPath)", via: session, timeout: 15)
            _ = await executeCommand("sudo nginx -t && sudo systemctl reload nginx", via: session, timeout: 20)
        } else if webServer.lowercased() == "apache" {
            let configPath = "/etc/apache2/sites-available/\(mainDomain).conf"
            _ = await executeCommand("sudo sed -i '/ServerName/a\\    ServerAlias \(aliasDomain)' \(configPath)", via: session, timeout: 15)
            _ = await executeCommand("sudo apache2ctl configtest && sudo systemctl reload apache2", via: session, timeout: 20)
        }

        log("✅ Domain alias \(aliasDomain) added")
        return true
    }

    // MARK: - PHP Version Management

    /// Get list of installed PHP versions
    func fetchInstalledPHPVersions(via session: TerminalViewModel) async -> [String] {
        log("Fetching installed PHP versions...")

        let result = await executeCommand("ls -1 /etc/php/ 2>/dev/null | grep -E '^[0-9]'", via: session, timeout: 10)
        let versions = cleanOutput(result.output).components(separatedBy: .newlines).filter { !$0.isEmpty }

        log("Found PHP versions: \(versions.joined(separator: ", "))")
        return versions
    }

    /// Switch PHP version for a site (Nginx)
    func switchPHPVersion(forDomain domain: String, toVersion version: String, via session: TerminalViewModel) async -> Bool {
        log("Switching PHP version for \(domain) to \(version)")

        let configPath = "/etc/nginx/sites-available/\(domain)"

        // Update PHP-FPM socket path in Nginx config
        _ = await executeCommand("sudo sed -i 's/php[0-9.]*-fpm.sock/php\(version)-fpm.sock/g' \(configPath)", via: session, timeout: 15)

        // Test and reload
        let testResult = await executeCommand("sudo nginx -t 2>&1", via: session, timeout: 15)
        if cleanOutput(testResult.output).contains("successful") || cleanOutput(testResult.output).contains("ok") {
            _ = await executeCommand("sudo systemctl reload nginx", via: session, timeout: 15)
            log("✅ PHP version switched to \(version) for \(domain)")
            return true
        }

        log("❌ Failed to switch PHP version")
        return false
    }
    
    // MARK: - Helpers
    
    private func parseLoadAverage(_ output: String) -> Double? {
        // Format: 0.00 0.01 0.05 1/123 4567
        let parts = output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if let first = parts.first, let load = Double(first) {
            // Convert load to percentage (assuming 1 core = 100%)
            return min(load, 1.0)
        }
        return nil
    }
    
    private func parseMemory(_ output: String) -> (used: Int, total: Int) {
        // Format: Mem:           7963        4521        1442           0         299        1699
        let parts = output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if parts.count >= 3, let total = Int(parts[1]), let used = Int(parts[2]) {
            return (used, total)
        }
        return (0, 0)
    }
    
    private func parseDisk(_ output: String) -> (used: String, total: String, percent: Double) {
        // Format: /dev/vda1       50G   25G   23G  53% /
        let parts = output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if parts.count >= 5 {
            let total = parts[1]
            let used = parts[2]
            let percentStr = parts[4].replacingOccurrences(of: "%", with: "")
            let percent = (Double(percentStr) ?? 0) / 100.0
            return (used, total, percent)
        }
        return ("0", "0", 0)
    }
    
    private func cleanOutput(_ output: String) -> String {
        // First strip terminal escapes
        var cleaned = stripTerminalEscapes(output)
        
        // Remove prompt lines and filter valid output
        let lines = cleaned.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                guard !line.isEmpty else { return false }
                // Skip lines that look like prompts
                if line.contains("@") && (line.hasSuffix("#") || line.hasSuffix("$")) { return false }
                if line.hasPrefix("root@") { return false }
                // Skip lines with just prompt characters
                if line == "#" || line == "$" { return false }
                return true
            }
        
        return lines.first ?? ""
    }
    
    private func iconForPackage(_ name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("nginx"): return "network"
        case let n where n.contains("apache"): return "network"
        case let n where n.contains("php"): return "scroll"
        case let n where n.contains("mysql"), let n where n.contains("mariadb"): return "cylinder.split.1x2"
        case let n where n.contains("postgres"): return "cylinder.split.1x2"
        case let n where n.contains("redis"): return "bolt.horizontal"
        case let n where n.contains("node"): return "cube.box"
        case let n where n.contains("docker"): return "shippingbox"
        case let n where n.contains("python"): return "terminal"
        case let n where n.contains("git"): return "arrow.triangle.branch"
        default: return "cube.box.fill"
        }
    }
}
