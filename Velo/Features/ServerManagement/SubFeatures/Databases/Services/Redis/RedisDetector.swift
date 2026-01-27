//
//  RedisDetector.swift
//  Velo
//
//  Detects Redis installation on the server.
//

import Foundation

struct RedisDetector {
    
    func detect(via session: TerminalViewModel) async -> (installed: Bool, serviceName: String?) {
        let isInstalled = await checkBinary(via: session)
        if !isInstalled { return (false, nil) }
        
        // Redis service is usually just "redis" or "redis-server"
        let serviceName = await checkService(via: session)
        return (true, serviceName)
    }
    
    func isInstalled(via session: TerminalViewModel) async -> Bool {
        await checkBinary(via: session)
    }
    
    func getServiceName(via session: TerminalViewModel) async -> String {
        await checkService(via: session) ?? "redis"
    }

    private func checkBinary(via session: TerminalViewModel) async -> Bool {
        let result = await ServerAdminService.shared.execute("which redis-server", via: session)
        print("🔍 [RedisDetector] checkBinary output: '\(result.output)', exitCode: \(result.exitCode)")
        return result.exitCode == 0 && !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func checkService(via session: TerminalViewModel) async -> String? {
        // Check common service names
        let services = ["redis", "redis-server"]
        for svc in services {
            let exists = await LinuxServiceHelper.serviceExists(serviceName: svc, via: session)
            print("🔍 [RedisDetector] Checking service '\(svc)': \(exists)")
            if exists {
                return svc
            }
        }
        return nil
    }
}
