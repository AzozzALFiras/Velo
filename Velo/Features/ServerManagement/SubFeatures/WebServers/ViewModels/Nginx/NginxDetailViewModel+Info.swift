import Foundation

extension NginxDetailViewModel {
    
    // MARK: - Modules & Info
    
    func loadModules() async {
        guard let session = session else { return }
        isLoadingInfo = true
        
        // nginx -V (capital V) shows version and configure arguments
        let result = await SSHBaseService.shared.execute("\(binaryPath) -V 2>&1", via: session)
        let output = result.output
        
        // Parse arguments
        if let range = output.range(of: "configure arguments:") {
            let argsString = String(output[range.upperBound...])
            configureArguments = argsString.components(separatedBy: " --")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { "--\($0)" }
            
            // Extract modules from arguments
            // usually --with-http_ssl_module, etc.
            modules = configureArguments.filter { $0.contains("_module") }
        }
        
        isLoadingInfo = false
    }
    
    // MARK: - Status
    
    func loadStatusMetrics() async {
        guard let session = session else { return }
        isLoadingStatus = true
        
        // Try to fetch status from localhost
        // Common paths: /nginx_status, /stub_status, /status
        let endpoints = ["http://127.0.0.1/nginx_status", "http://127.0.0.1/stub_status", "http://127.0.0.1/status"]
        
        for endpoint in endpoints {
            let result = await SSHBaseService.shared.execute("curl -s \(endpoint)", via: session, timeout: 5)
            if !result.output.isEmpty && result.output.contains("Active connections") {
                parseStubStatus(result.output)
                break
            }
        }
        
        if statusInfo == nil {
            // If failed, maybe try to check process limit?
            // For now just leave nil, View handles it.
        }
        
        isLoadingStatus = false
    }
    
    private func parseStubStatus(_ output: String) {
        // Example output:
        // Active connections: 291 
        // server accepts handled requests
        //  16630948 16630948 31070465 
        // Reading: 6 Writing: 179 Waiting: 106 
        
        var active = 0
        var accepts = 0
        var handled = 0
        var requests = 0
        var reading = 0
        var writing = 0
        var waiting = 0
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Active connections") {
                active = Int(line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
            } else if line.contains("Reading") {
                let parts = line.components(separatedBy: " ")
                // Reading: 6 Writing: 179 Waiting: 106
                // Index might vary depending on spaces. regex is safer.
                if let rRange = line.range(of: "Reading:\\s+(\\d+)", options: .regularExpression),
                   let rMatch = line[rRange].components(separatedBy: ":").last {
                     reading = Int(rMatch.trimmingCharacters(in: .whitespaces)) ?? 0
                }
                if let wRange = line.range(of: "Writing:\\s+(\\d+)", options: .regularExpression),
                   let wMatch = line[wRange].components(separatedBy: ":").last {
                     writing = Int(wMatch.trimmingCharacters(in: .whitespaces)) ?? 0
                }
                if let waRange = line.range(of: "Waiting:\\s+(\\d+)", options: .regularExpression),
                   let waMatch = line[waRange].components(separatedBy: ":").last {
                     waiting = Int(waMatch.trimmingCharacters(in: .whitespaces)) ?? 0
                }
            } else if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: line.replacingOccurrences(of: " ", with: ""))) && !line.isEmpty {
                 let nums = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.compactMap { Int($0) }
                 if nums.count >= 3 {
                     accepts = nums[0]
                     handled = nums[1]
                     requests = nums[2]
                 }
            }
        }
        
        statusInfo = NginxStatusInfo(
            activeConnections: active,
            accepts: accepts,
            handled: handled,
            requests: requests,
            reading: reading,
            writing: writing,
            waiting: waiting
        )
    }
}
