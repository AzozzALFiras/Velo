//
//  MongoVersionResolver.swift
//  Velo
//
//  Resolves the installed MongoDB version.
//

import Foundation

struct MongoVersionResolver {
    
    func getVersion(via session: TerminalViewModel) async -> String? {
        // Run mongod --version
        // Output example: db version v4.4.6
        let result = await SSHBaseService.shared.execute("mongod --version", via: session)
        guard result.exitCode == 0 else { return nil }
        
        let output = result.output
        
        // Parse "vX.Y.Z"
        if let range = output.range(of: "v[0-9.]+", options: .regularExpression) {
            let versionString = String(output[range])
            return versionString.replacingOccurrences(of: "v", with: "")
        }
        
        return nil
    }
}
