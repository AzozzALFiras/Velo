//
//  QuickAccessService.swift
//  Velo
//
//  Detects server environment (Nginx/Apache) and provides 
//  intelligent Quick Access locations for the Files sidebar.
//

import Foundation

@MainActor
final class QuickAccessService {
    static let shared = QuickAccessService()
    
    // Dependencies - Using the Detectors directly to be lightweight
    private let nginxDetector = NginxDetector()
    private let nginxPathResolver = NginxPathResolver()
    
    private let apacheDetector = ApacheDetector()
    private let apachePathResolver = ApachePathResolver()
    
    private let baseService = SSHBaseService.shared
    
    private init() {}
    
    /// Detects environment and returns optimized locations
    func getLocations(via session: TerminalViewModel) async -> [QuickAccessLocation] {
        var locations: [QuickAccessLocation] = []
        
        // 1. Core System Locations (Always present)
        locations.append(QuickAccessLocation(name: "files.quickAccess.root".localized, path: "/", icon: "externaldrive", isSystem: true))
        locations.append(QuickAccessLocation(name: "files.quickAccess.home".localized, path: "~", icon: "house", isSystem: true))
        
        // 2. Detect Web Server & Add Config Paths
        
        // Check Nginx
        if await nginxDetector.isInstalled(via: session) {
            let sitesPath = await nginxPathResolver.getSitesAvailablePath(via: session)
            locations.append(QuickAccessLocation(
                name: "Nginx Sites", 
                path: sitesPath, 
                icon: "server.rack", 
                isSystem: true
            ))
            
            // Add Nginx Logs if they exist
            let logPath = await nginxPathResolver.getLogDirPath(via: session)
            locations.append(QuickAccessLocation(
                name: "Nginx Logs",
                path: logPath,
                icon: "doc.text",
                isSystem: true
            ))
        }
        
        // Check Apache (only if Nginx not found or if both exist)
        if await apacheDetector.isInstalled(via: session) {
            let sitesPath = await apachePathResolver.getSitesAvailablePath(via: session)
            locations.append(QuickAccessLocation(
                name: "Apache Sites", 
                path: sitesPath, 
                icon: "server.rack", 
                isSystem: true
            ))
        }
        
        // 3. Smart Web Root Detection
        // Try to find the actual web root used by the active server
        var webRoot = "/var/www"
        if await nginxDetector.isInstalled(via: session) {
            webRoot = await nginxPathResolver.getDefaultDocumentRoot(via: session)
        } else if await apacheDetector.isInstalled(via: session) {
            webRoot = await apachePathResolver.getDefaultDocumentRoot(via: session)
        }
        
        locations.append(QuickAccessLocation(
            name: "files.quickAccess.webRoot".localized, 
            path: webRoot, 
            icon: "globe", 
            isSystem: true
        ))
        
        // 4. Common Utilities
        // Add specific panel paths if detected (aaPanel/BT)
        let isPanel = await baseService.execute("test -d /www/server/panel && echo 'YES'", via: session, timeout: 5).output.contains("YES")
        if isPanel {
            locations.append(QuickAccessLocation(
                name: "aaPanel Root",
                path: "/www/server",
                icon: "wrench.and.screwdriver",
                isSystem: true
            ))
        }
        
        locations.append(QuickAccessLocation(name: "files.quickAccess.temp".localized, path: "/tmp", icon: "clock.arrow.circlepath", isSystem: true))
        
        return locations
    }
}
