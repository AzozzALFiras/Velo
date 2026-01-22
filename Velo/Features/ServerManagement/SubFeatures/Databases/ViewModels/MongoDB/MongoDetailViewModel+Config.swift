//
//  MongoDetailViewModel+Config.swift
//  Velo
//
//  Configuration management for MongoDB.
//

import Foundation

extension MongoDetailViewModel {
    
    func loadConfigValues() async {
        guard let session = session else { return }
        isLoadingConfig = true
        
        // MongoDB config is YAML and can be complex.
        // We can query running config via db.adminCommand({ getCmdLineOpts: 1 })
        
        let cmd = "mongosh --quiet --eval 'JSON.stringify(db.adminCommand({ getCmdLineOpts: 1 }))'"
        let result = await baseService.execute(cmd, via: session)
        
        var newValues: [SharedConfigValue] = []
        
        // Parse JSON output if successful
        if let data = result.output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let parsed = json["parsed"] as? [String: Any] {
           
            // Flatten a bit
            for (key, val) in parsed {
                newValues.append(SharedConfigValue(
                    key: key,
                    value: "\(val)",
                    displayName: key,
                    description: "MongoDB Setting",
                    type: nil,
                    section: "General"
                ))
            }
        }
        
        await MainActor.run {
            self.configValues = newValues
            self.isLoadingConfig = false
        }
    }
}
