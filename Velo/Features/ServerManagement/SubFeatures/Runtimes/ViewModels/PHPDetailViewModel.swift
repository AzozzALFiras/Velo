//
//  PHPDetailViewModel.swift
//  Velo
//
//  ViewModel for detailed PHP management including service control,
//  configuration editing, extensions, and version management.
//

import Foundation
import Combine
import SwiftUI

// MARK: - PHPConfigValue

/// Represents a PHP configuration value with metadata
struct PHPConfigValue: Identifiable, Equatable {
    let id = UUID()
    let key: String
    let value: String
    let displayName: String
    let description: String
    let type: ConfigValueType
    
    enum ConfigValueType {
        case size       // e.g., upload_max_filesize
        case time       // e.g., max_execution_time
        case number     // e.g., max_input_vars
        case boolean    // e.g., display_errors
        case string     // e.g., date.timezone
    }
}

// MARK: - PHPExtension

/// Represents a PHP extension with its status
struct PHPExtension: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let isLoaded: Bool
    let isCore: Bool
}

// MARK: - PHPDetailSection

/// Represents a section in the PHP detail sidebar
enum PHPDetailSection: String, CaseIterable, Identifiable {
    case service = "Service"
    case extensions = "Extensions"
    case disabledFunctions = "Disabled Functions"
    case configuration = "Configuration"
    case uploadLimits = "Upload Limits"
    case timeouts = "Timeouts"
    case configFile = "Config File"
    case fpmProfile = "FPM Profile"
    case logs = "Logs"
    case phpinfo = "PHP Info"
    
    var id: String { rawValue }

    
    var icon: String {
        switch self {
        case .service: return "power"
        case .extensions: return "puzzlepiece.extension"
        case .disabledFunctions: return "xmark.circle"
        case .configuration: return "gearshape"
        case .uploadLimits: return "arrow.up.doc"
        case .timeouts: return "clock"
        case .configFile: return "doc.text"
        case .fpmProfile: return "cpu"
        case .logs: return "doc.plaintext"
        case .phpinfo: return "info.circle"
        }
    }
}

// MARK: - PHPDetailViewModel

@MainActor
final class PHPDetailViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    weak var session: TerminalViewModel?
    private let phpService = PHPService.shared
    private let baseService = SSHBaseService.shared
    
    // MARK: - Published State
    
    // General Info
    @Published var activeVersion: String = "..."
    @Published var installedVersions: [String] = []
    @Published var isRunning: Bool = false
    @Published var configPath: String = "..."
    @Published var binaryPath: String = "..."
    
    // Sections
    @Published var selectedSection: PHPDetailSection = .service
    
    // Extensions
    @Published var extensions: [PHPExtension] = []
    @Published var availableExtensions: [String] = []
    @Published var isLoadingExtensions: Bool = false
    @Published var isInstallingExtension: Bool = false
    
    // Disabled Functions
    @Published var disabledFunctions: [String] = []
    @Published var isLoadingDisabledFunctions: Bool = false
    
    // Configuration Values
    @Published var configValues: [PHPConfigValue] = []
    @Published var isLoadingConfig: Bool = false
    
    // Config File Content
    @Published var configFileContent: String = ""
    @Published var isLoadingConfigFile: Bool = false
    @Published var isSavingConfigFile: Bool = false
    
    // Logs
    @Published var logContent: String = ""
    @Published var isLoadingLogs: Bool = false
    
    // PHP Info
    @Published var phpInfoHTML: String = ""
    @Published var phpInfoData: [String: String] = [:]
    @Published var isLoadingPHPInfo: Bool = false
    
    // FPM Status
    @Published var fpmStatus: [String: Bool] = [:]
    @Published var isLoadingFPM: Bool = false
    
    // Loading & Error
    @Published var isLoading: Bool = false
    @Published var isPerformingAction: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    
    // API Data
    @Published var availableVersionsFromAPI: [CapabilityVersion] = []
    @Published var capabilityIcon: String? = nil
    @Published var isInstallingVersion: Bool = false
    @Published var installingVersionName: String = ""
    @Published var installStatus: String = ""
    
    // MARK: - Init
    
    init(session: TerminalViewModel? = nil) {
        self.session = session
    }
    
    // MARK: - Data Loading
    
    /// Load all PHP data
    func loadData() async {
        guard session != nil else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Load basic info first
        async let versionTask: () = loadVersionInfo()
        async let statusTask: () = loadServiceStatus()
        async let pathsTask: () = loadPaths()
        async let apiTask: () = loadAPIData()
        
        await versionTask
        await statusTask
        await pathsTask
        await apiTask
        
        // Load section-specific data
        await loadSectionData()
        
        isLoading = false
    }
    
    /// Load data for the current section
    func loadSectionData() async {
        // Skip reloading if a version is being installed (session is busy)
        guard !isInstallingVersion else { return }
        
        switch selectedSection {
        case .service:
            await loadFPMStatus()
        case .extensions:
            await loadExtensions()
        case .disabledFunctions:
            await loadDisabledFunctions()
        case .configuration, .uploadLimits, .timeouts:
            await loadConfigValues()
        case .configFile:
            await loadConfigFile()
        case .fpmProfile:
            await loadFPMStatus()
        case .logs:
            await loadLogs()
        case .phpinfo:
            await loadPHPInfo()
        }
    }
    
    // MARK: - Version Info
    
    private func loadVersionInfo() async {
        guard let session = session else { return }
        
        if let version = await phpService.getVersion(via: session) {
            activeVersion = version
        }
        
        installedVersions = await phpService.getInstalledVersions(via: session)
    }
    
    // MARK: - Service Status
    
    private func loadServiceStatus() async {
        guard let session = session else { return }
        isRunning = await phpService.isRunning(via: session)
    }
    
    // MARK: - Paths
    
    private func loadPaths() async {
        guard let session = session else { return }
        
        if let path = await phpService.getConfigFilePath(via: session) {
            configPath = path
        }
        
        // Get binary path
        let result = await baseService.execute("which php 2>/dev/null", via: session, timeout: 5)
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty {
            binaryPath = path
        }
    }
    
    // MARK: - API Data
    
    private func loadAPIData() async {
        do {
            let capability = try await ApiService.shared.fetchCapabilityDetails(slug: "php")
            capabilityIcon = capability.icon
            availableVersionsFromAPI = capability.versions ?? []
        } catch {
            print("[PHPDetailViewModel] Failed to load API data: \(error)")
        }
    }
    
    // MARK: - Extensions
    
    private func loadExtensions() async {
        guard let session = session else { return }
        
        isLoadingExtensions = true
        
        let loadedExtensions = await phpService.getLoadedExtensions(via: session)
        
        // Core extensions that are typically built-in
        let coreExtensions = ["Core", "date", "libxml", "pcre", "reflection", "spl", "standard", "filter", "hash", "json"]
        
        extensions = loadedExtensions.map { ext in
            PHPExtension(
                name: ext,
                isLoaded: true,
                isCore: coreExtensions.contains { $0.lowercased() == ext.lowercased() }
            )
        }.sorted { $0.name.lowercased() < $1.name.lowercased() }
        
        isLoadingExtensions = false
    }
    
    // MARK: - Configuration
    
    private func loadConfigValues() async {
        guard let session = session else { return }
        
        isLoadingConfig = true
        
        // Key configuration values to fetch
        let configKeys: [(key: String, display: String, desc: String, type: PHPConfigValue.ConfigValueType)] = [
            ("upload_max_filesize", "Max Upload Size", "Maximum size of an uploaded file", .size),
            ("post_max_size", "Max POST Size", "Maximum size of POST data", .size),
            ("memory_limit", "Memory Limit", "Maximum memory a script can consume", .size),
            ("max_execution_time", "Max Execution Time", "Maximum time a script can run (seconds)", .time),
            ("max_input_time", "Max Input Time", "Maximum time to parse input data (seconds)", .time),
            ("max_input_vars", "Max Input Vars", "Maximum number of input variables", .number),
            ("max_file_uploads", "Max File Uploads", "Maximum number of files to upload simultaneously", .number),
            ("display_errors", "Display Errors", "Show PHP errors on screen", .boolean),
            ("error_reporting", "Error Reporting", "Error reporting level", .string),
            ("date.timezone", "Timezone", "Default timezone", .string),
        ]
        
        var values: [PHPConfigValue] = []
        
        for config in configKeys {
            if let value = await phpService.getConfigValue(config.key, via: session) {
                values.append(PHPConfigValue(
                    key: config.key,
                    value: value,
                    displayName: config.display,
                    description: config.desc,
                    type: config.type
                ))
            }
        }
        
        configValues = values
        isLoadingConfig = false
    }
    
    // MARK: - Config File
    
    /// Load ONLY active configuration lines (no comments) - much faster!
    /// This reduces ~1800 lines to ~80 lines
    func loadConfigFile() async {
        guard let session = session else { return }
        
        isLoadingConfigFile = true
        
        // Use grep to extract only non-empty, non-comment lines
        // This is MUCH faster and won't freeze the UI
        let command = "grep -v '^[[:space:]]*;' '\(configPath)' 2>/dev/null | grep -v '^[[:space:]]*$' | grep -v '^\\['"
        let result = await baseService.execute(command, via: session, timeout: 10)
        configFileContent = result.output
        
        isLoadingConfigFile = false
    }
    
    /// Load full config file (use with caution - large file!)
    func loadFullConfigFile() async {
        guard let session = session else { return }
        
        isLoadingConfigFile = true
        
        // Increase timeout for large file
        let result = await baseService.execute("cat '\(configPath)' 2>/dev/null", via: session, timeout: 30)
        configFileContent = result.output
        
        isLoadingConfigFile = false
    }
    
    /// Save a specific configuration value using sed (fast and reliable)
    func saveConfigValue(_ key: String, _ value: String) async -> Bool {
        guard let session = session else { return false }
        
        isSavingConfigFile = true
        errorMessage = nil
        successMessage = nil
        
        // Use sed to update just this one value in the config file
        // This is MUCH faster than rewriting the entire file
        let escapedValue = value.replacingOccurrences(of: "/", with: "\\/")
        let command = "sed -i 's/^\\s*\(key)\\s*=.*/\(key) = \(escapedValue)/' '\(configPath)'"
        
        let result = await baseService.execute(command, via: session, timeout: 10)
        
        if result.exitCode == 0 {
            successMessage = "Updated \(key) successfully"
            // Reload PHP-FPM to apply changes
            _ = await phpService.reload(via: session)
            isSavingConfigFile = false
            return true
        } else {
            errorMessage = "Failed to update \(key)"
            isSavingConfigFile = false
            return false
        }
    }
    
    func saveConfigFile() async -> Bool {
        guard let session = session else { return false }
        
        isSavingConfigFile = true
        errorMessage = nil
        successMessage = nil
        
        // Use heredoc approach instead of base64 - much faster and more reliable
        // This writes directly without encoding
        let tempPath = "/tmp/php_config_\(UUID().uuidString.prefix(8)).ini"
        
        // Escape single quotes in content
        let escapedContent = configFileContent.replacingOccurrences(of: "'", with: "'\\''")
        
        // Write using echo with single quotes (preserves all content)
        // Split into smaller chunks if needed
        let lines = configFileContent.components(separatedBy: "\n")
        
        var success = false
        
        if lines.count <= 50 {
            // Small file - write directly using cat with heredoc
            let writeCommand = "cat > '\(tempPath)' << 'ENDOFCONFIG'\n\(configFileContent)\nENDOFCONFIG"
            let result = await baseService.execute(writeCommand, via: session, timeout: 15)
            
            if result.exitCode == 0 || result.output.isEmpty {
                // Move to final location
                let moveResult = await baseService.execute("mv '\(tempPath)' '\(configPath)'", via: session, timeout: 5)
                success = moveResult.exitCode == 0 || !moveResult.output.contains("error")
            }
        } else {
            // Larger file - write line by line
            // First clear/create the temp file
            _ = await baseService.execute("> '\(tempPath)'", via: session, timeout: 5)
            
            // Write in chunks of 20 lines
            let chunkSize = 20
            var currentIndex = 0
            success = true
            
            while currentIndex < lines.count && success {
                let endIndex = min(currentIndex + chunkSize, lines.count)
                let chunk = lines[currentIndex..<endIndex].joined(separator: "\n")
                let escapedChunk = chunk.replacingOccurrences(of: "'", with: "'\\''")
                
                let appendCommand = "echo '\(escapedChunk)' >> '\(tempPath)'"
                let result = await baseService.execute(appendCommand, via: session, timeout: 10)
                
                if result.exitCode != 0 && result.output.contains("error") {
                    success = false
                }
                
                currentIndex = endIndex
            }
            
            if success {
                // Move to final location
                let moveResult = await baseService.execute("mv '\(tempPath)' '\(configPath)'", via: session, timeout: 5)
                success = moveResult.exitCode == 0 || !moveResult.output.contains("error")
            }
        }
        
        if success {
            successMessage = "Configuration saved successfully"
            // Reload PHP-FPM to apply changes
            _ = await phpService.reload(via: session)
        } else {
            errorMessage = "Failed to save configuration"
            // Cleanup temp file
            _ = await baseService.execute("rm -f '\(tempPath)'", via: session, timeout: 5)
        }
        
        isSavingConfigFile = false
        return success
    }
    
    // MARK: - FPM Status
    
    private func loadFPMStatus() async {
        guard let session = session else { return }
        
        isLoadingFPM = true
        fpmStatus = await phpService.getAllFPMStatus(via: session)
        isLoadingFPM = false
    }
    
    // MARK: - Logs
    
    private func loadLogs() async {
        guard let session = session else { return }
        
        isLoadingLogs = true
        
        // Try common PHP log locations
        let logPaths = [
            "/var/log/php\(activeVersion)-fpm.log",
            "/var/log/php-fpm/error.log",
            "/var/log/php/error.log",
            "/var/log/php_errors.log"
        ]
        
        for path in logPaths {
            let result = await baseService.execute("tail -100 '\(path)' 2>/dev/null", via: session, timeout: 10)
            if !result.output.isEmpty && !result.output.contains("No such file") {
                logContent = result.output
                break
            }
        }
        
        if logContent.isEmpty {
            logContent = "No PHP logs found in common locations."
        }
        
        isLoadingLogs = false
    }
    
    // MARK: - PHP Info
    
    private func loadPHPInfo() async {
        guard let session = session else { return }
        
        isLoadingPHPInfo = true
        phpInfoData = [:]
        
        // Get key PHP info values
        let result = await baseService.execute("php -i 2>/dev/null | head -200", via: session, timeout: 15)
        phpInfoHTML = result.output
        
        // Parse the output into key-value pairs
        var data: [String: String] = [:]
        let lines = result.output.components(separatedBy: "\n")
        
        for line in lines {
            // Parse lines like "key => value" or "key = value"
            if line.contains(" => ") {
                let parts = line.components(separatedBy: " => ")
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts.dropFirst().joined(separator: " => ").trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty && !value.isEmpty {
                        data[key] = value
                    }
                }
            }
        }
        
        phpInfoData = data
        isLoadingPHPInfo = false
    }
    
    // MARK: - Service Actions
    
    func startService() async {
        guard let session = session else { return }
        
        isPerformingAction = true
        errorMessage = nil
        
        let success = await phpService.start(via: session)
        
        if success {
            isRunning = true
            successMessage = "PHP-FPM started successfully"
        } else {
            errorMessage = "Failed to start PHP-FPM"
        }
        
        isPerformingAction = false
    }
    
    func stopService() async {
        guard let session = session else { return }
        
        isPerformingAction = true
        errorMessage = nil
        
        let success = await phpService.stop(via: session)
        
        if success {
            isRunning = false
            successMessage = "PHP-FPM stopped successfully"
        } else {
            errorMessage = "Failed to stop PHP-FPM"
        }
        
        isPerformingAction = false
    }
    
    func restartService() async {
        guard let session = session else { return }
        
        isPerformingAction = true
        errorMessage = nil
        
        let success = await phpService.restart(via: session)
        
        if success {
            isRunning = true
            successMessage = "PHP-FPM restarted successfully"
        } else {
            errorMessage = "Failed to restart PHP-FPM"
        }
        
        isPerformingAction = false
    }
    
    func reloadService() async {
        guard let session = session else { return }
        
        isPerformingAction = true
        errorMessage = nil
        
        let success = await phpService.reload(via: session)
        
        if success {
            successMessage = "PHP-FPM configuration reloaded"
        } else {
            errorMessage = "Failed to reload PHP-FPM"
        }
        
        isPerformingAction = false
    }
    
    // MARK: - Version Switching
    
    func switchVersion(to version: String) async {
        guard let session = session else { return }
        
        isPerformingAction = true
        errorMessage = nil
        
        let success = await phpService.switchVersion(to: version, via: session)
        
        if success {
            activeVersion = version
            successMessage = "Switched to PHP \(version)"
            // Reload data for the new version
            await loadData()
        } else {
            errorMessage = "Failed to switch PHP version"
        }
        
        isPerformingAction = false
    }
    
    /// Install a new PHP version from API
    func installVersion(_ version: CapabilityVersion) async {
        guard let session = session else { return }
        
        isInstallingVersion = true
        installingVersionName = version.version
        installStatus = "Detecting OS..."
        errorMessage = nil
        
        // Get OS name (ubuntu/debian)
        let osResult = await baseService.execute("cat /etc/os-release | grep -E '^ID=' | cut -d= -f2", via: session, timeout: 5)
        let osName = osResult.output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\"", with: "")
        
        print("[PHPDetailVM] Detected OS: '\(osName)', installCommands: \(version.installCommands ?? [:])")
        
        installStatus = "Preparing installation..."
        
        // Get install commands from API - API uses "default" key, not "install"
        guard let installCommands = version.installCommands,
              let osCommands = installCommands[osName] ?? installCommands["ubuntu"] ?? installCommands["debian"],
              let installCommand = osCommands["default"] ?? osCommands["install"] else {
            errorMessage = "No install commands available for \(osName)"
            isInstallingVersion = false
            installStatus = ""
            return
        }
        
        print("[PHPDetailVM] Executing install command: \(installCommand.prefix(100))...")
        
        installStatus = "Installing PHP \(version.version)..."
        
        // Execute install command (with longer timeout for package installation)
        let result = await baseService.execute(installCommand, via: session, timeout: 600)
        
        if result.exitCode == 0 || result.output.contains("is already") || result.output.contains("newest version") {
            installStatus = "Verifying installation..."
            successMessage = "PHP \(version.version) installed successfully"
            // Reload installed versions
            await loadVersionInfo()
        } else {
            errorMessage = "Failed to install PHP \(version.version)"
            print("[PHPDetailVM] Install error: \(result.output.suffix(200))")
        }
        
        isInstallingVersion = false
        installingVersionName = ""
        installStatus = ""
    }
    
    /// Set a PHP version as the default (update-alternatives)
    func setAsDefaultVersion(_ version: String) async {
        guard let session = session else { return }
        
        isPerformingAction = true
        errorMessage = nil
        
        // Use update-alternatives to set default PHP
        let command = "update-alternatives --set php /usr/bin/php\(version)"
        let result = await baseService.execute(command, via: session, timeout: 10)
        
        if result.exitCode == 0 || result.output.isEmpty {
            activeVersion = version
            successMessage = "PHP \(version) is now the default version"
            // Reload to update active version
            await loadVersionInfo()
        } else {
            errorMessage = "Failed to set PHP \(version) as default"
        }
        
        isPerformingAction = false
    }
    
    // MARK: - Config Value Modification
    
    func updateConfigValue(_ key: String, to newValue: String) async -> Bool {
        guard let session = session else { return false }
        
        isPerformingAction = true
        errorMessage = nil
        
        // Use sed to update the value in php.ini
        let escapedValue = newValue.replacingOccurrences(of: "/", with: "\\/")
        let command = "sudo sed -i 's/^\\(;\\?\\s*\\)\\(\(key)\\s*=\\s*\\).*/\\2\(escapedValue)/' '\(configPath)'"
        
        let result = await baseService.execute(command, via: session, timeout: 10)
        
        let success = result.exitCode == 0
        
        if success {
            // Reload config values
            await loadConfigValues()
            // Reload PHP-FPM
            _ = await phpService.reload(via: session)
            successMessage = "\(key) updated to \(newValue)"
        } else {
            errorMessage = "Failed to update \(key)"
        }
        
        isPerformingAction = false
        return success
    }
    
    // MARK: - FPM Version-Specific Actions
    
    func startFPM(version: String) async {
        guard let session = session else { return }
        
        isPerformingAction = true
        _ = await phpService.startFPM(version: version, via: session)
        await loadFPMStatus()
        isPerformingAction = false
    }
    
    func stopFPM(version: String) async {
        guard let session = session else { return }
        
        isPerformingAction = true
        _ = await phpService.stopFPM(version: version, via: session)
        await loadFPMStatus()
        isPerformingAction = false
    }
    
    // MARK: - Disabled Functions
    
    private func loadDisabledFunctions() async {
        guard let session = session else { return }
        
        isLoadingDisabledFunctions = true
        
        let result = await baseService.execute("php -r \"echo ini_get('disable_functions');\" 2>/dev/null", via: session, timeout: 10)
        let functions = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !functions.isEmpty && functions != "no value" {
            disabledFunctions = functions.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .sorted()
        } else {
            disabledFunctions = []
        }
        
        isLoadingDisabledFunctions = false
    }
    
    /// Remove a function from the disabled functions list
    func removeDisabledFunction(_ function: String) async -> Bool {
        guard let session = session else { return false }
        
        isPerformingAction = true
        errorMessage = nil
        
        // Remove the function from the list
        var newList = disabledFunctions.filter { $0 != function }
        let newValue = newList.joined(separator: ",")
        
        // Update php.ini
        let command = "sudo sed -i 's/^\\(disable_functions\\s*=\\s*\\).*/\\1\\(newValue)/' '\\(configPath)'"
        let result = await baseService.execute(command, via: session, timeout: 10)
        
        if result.exitCode == 0 {
            disabledFunctions = newList
            _ = await phpService.reload(via: session)
            successMessage = "Function \\(function) enabled"
            isPerformingAction = false
            return true
        } else {
            errorMessage = "Failed to enable function"
            isPerformingAction = false
            return false
        }
    }
    
    /// Add a function to the disabled functions list
    func addDisabledFunction(_ function: String) async -> Bool {
        guard let session = session else { return false }
        
        isPerformingAction = true
        errorMessage = nil
        
        var newList = disabledFunctions
        if !newList.contains(function) {
            newList.append(function)
        }
        let newValue = newList.joined(separator: ",")
        
        let command = "sudo sed -i 's/^\\(disable_functions\\s*=\\s*\\).*/\\1\\(newValue)/' '\\(configPath)'"
        let result = await baseService.execute(command, via: session, timeout: 10)
        
        if result.exitCode == 0 {
            disabledFunctions = newList.sorted()
            _ = await phpService.reload(via: session)
            successMessage = "Function \\(function) disabled"
            isPerformingAction = false
            return true
        } else {
            errorMessage = "Failed to disable function"
            isPerformingAction = false
            return false
        }
    }
    
    // MARK: - Extension Installation
    
    /// Get list of available PHP extensions that can be installed
    func loadAvailableExtensions() async {
        guard let session = session else { return }
        
        // Common PHP extensions
        availableExtensions = [
            "bcmath", "bz2", "calendar", "ctype", "curl", "dba", "dom", "enchant",
            "exif", "fileinfo", "ftp", "gd", "gettext", "gmp", "iconv", "igbinary",
            "imagick", "imap", "intl", "ldap", "mbstring", "memcached", "mongodb",
            "mysqli", "mysqlnd", "odbc", "opcache", "openssl", "pcntl", "pdo",
            "pdo_mysql", "pdo_pgsql", "pdo_sqlite", "pgsql", "phar", "posix",
            "pspell", "readline", "redis", "shmop", "simplexml", "soap", "sockets",
            "sodium", "sqlite3", "ssh2", "sysvmsg", "sysvsem", "sysvshm", "tidy",
            "tokenizer", "xml", "xmlreader", "xmlrpc", "xmlwriter", "xsl", "zip", "zlib"
        ]
    }
    
    /// Install a PHP extension
    func installExtension(_ extensionName: String) async -> Bool {
        guard let session = session else { return false }
        
        isInstallingExtension = true
        errorMessage = nil
        successMessage = nil
        
        // Determine the package name based on PHP version
        let majorVersion = activeVersion.components(separatedBy: ".").first ?? "8"
        let packageName = "php\\(majorVersion)-\\(extensionName)"
        
        // Try apt-get first (Debian/Ubuntu)
        var command = "sudo apt-get install -y \\(packageName) 2>&1"
        var result = await baseService.execute(command, via: session, timeout: 120)
        
        if result.exitCode != 0 {
            // Try yum (CentOS/RHEL)
            command = "sudo yum install -y php-\\(extensionName) 2>&1"
            result = await baseService.execute(command, via: session, timeout: 120)
        }
        
        if result.exitCode == 0 && !result.output.contains("E:") {
            // Reload PHP-FPM
            _ = await phpService.reload(via: session)
            // Refresh extensions list
            await loadExtensions()
            successMessage = "Extension \\(extensionName) installed successfully"
            isInstallingExtension = false
            return true
        } else {
            errorMessage = "Failed to install \\(extensionName)"
            isInstallingExtension = false
            return false
        }
    }
}
