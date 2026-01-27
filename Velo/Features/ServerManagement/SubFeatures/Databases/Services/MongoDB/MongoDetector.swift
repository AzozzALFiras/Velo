//
//  MongoDetector.swift
//  Velo
//
//  Detects MongoDB installation on the server.
//

import Foundation

struct MongoDetector {
    
    func detect(via session: TerminalViewModel) async -> (installed: Bool, serviceName: String?) {
        let isInstalled = await checkBinary(via: session)
        if !isInstalled { return (false, nil) }
        
        let serviceName = await checkService(via: session)
        return (true, serviceName)
    }
    
    func isInstalled(via session: TerminalViewModel) async -> Bool {
        await checkBinary(via: session)
    }
    
    func getServiceName(via session: TerminalViewModel) async -> String {
        await checkService(via: session) ?? "mongod"
    }

    private func checkBinary(via session: TerminalViewModel) async -> Bool {
        let result = await ServerAdminService.shared.execute("which mongod", via: session)
        return result.exitCode == 0 && !result.output.isEmpty
    }
    
    private func checkService(via session: TerminalViewModel) async -> String? {
        // Check common service names
        let services = ["mongod", "mongodb"]
        for svc in services {
            if await LinuxServiceHelper.serviceExists(serviceName: svc, via: session) {
                return svc
            }
        }
        return nil
    }
}
