//
//  SSHWebsiteService.swift
//  Velo
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class SSHWebsiteService: ObservableObject {
    static let shared = SSHWebsiteService()
    private let base = SSHBaseService.shared
    
    @Published var isExecuting = false
    
    private init() {}
    
    /// Create a website atomically using a single compound shell script
    func createWebsite(domain: String, path: String, framework: String, port: Int, phpVersion: String?, via session: TerminalViewModel) async -> Bool {
        let safeDomain = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let safePath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Build one giant atomic command to avoid round-trip latency
        var script = """
        mkdir -p '\(safePath)'
        chown -R www-data:www-data '\(safePath)' 2>/dev/null || chown -R nginx:nginx '\(safePath)' 2>/dev/null || true
        chmod -R 755 '\(safePath)'
        """
        
        // Add index file creation logic to the same script
        let welcomeMsg = "Welcome to \(safeDomain)"
        if framework.contains("PHP") {
            script += "\necho '<?php echo \"<h1>\(welcomeMsg)</h1>\"; phpinfo(); ?>' > '\(safePath)/index.php'"
        } else {
            script += "\necho '<h1>\(welcomeMsg)</h1>' > '\(safePath)/index.html'"
        }
        
        // Execute the groundwork
        let result = await base.execute("sudo bash -c \"\(script)\"", via: session)
        guard result.exitCode == 0 else { return false }
        
        // config creation is still separate for now as it's more complex, 
        // but it could also be bundled later.
        return true
    }
    
    /// Fetch sites using a high-speed unified command
    func fetchWebsites(via session: TerminalViewModel) async -> [String] {
        // Broad search for both enabled and available sites, including standard and non-standard paths
        let command = """
        find /etc/nginx/sites-enabled/ /etc/apache2/sites-enabled/ /etc/nginx/conf.d/ -maxdepth 1 -type f -not -name "default" -not -name "*.bak" 2>/dev/null | xargs -n 1 basename
        """
        let result = await base.execute(command, via: session)
        return result.output.components(separatedBy: .newlines).filter { !$0.isEmpty && !$0.contains("default") }
    }
}
