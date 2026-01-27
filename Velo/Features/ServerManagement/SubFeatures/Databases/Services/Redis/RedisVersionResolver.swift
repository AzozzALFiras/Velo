//
//  RedisVersionResolver.swift
//  Velo
//
//  Resolves the installed Redis version.
//

import Foundation

struct RedisVersionResolver {
    
    func getVersion(via session: TerminalViewModel) async -> String? {
        // Run redis-server --version
        // Output example: Redis server v=6.0.9 sha=00000000:0 malloc=jemalloc-5.2.1 bits=64 build=...
        let result = await ServerAdminService.shared.execute("redis-server --version", via: session)
        guard result.exitCode == 0 else { return nil }
        
        let output = result.output
        
        // Parse "v=X.Y.Z"
        if let range = output.range(of: "v=[0-9.]+", options: .regularExpression) {
            let versionString = String(output[range])
            return versionString.replacingOccurrences(of: "v=", with: "")
        }
        
        return nil
    }
}
