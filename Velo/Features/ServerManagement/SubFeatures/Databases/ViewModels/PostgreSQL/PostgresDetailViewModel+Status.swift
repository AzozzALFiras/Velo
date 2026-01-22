//
//  PostgresDetailViewModel+Status.swift
//  Velo
//
//  Status metrics for PostgreSQL.
//

import Foundation

extension PostgresDetailViewModel {
    
    func loadStatusInfo() async {
        guard let session = session else { return }
        isLoadingStatus = true
        
        var info = MySQLStatusInfo()
        
        // Uptime
        let uptimeCmd = "sudo -u postgres psql -t -c \"SELECT date_trunc('second', current_timestamp - pg_postmaster_start_time()) as uptime;\" 2>/dev/null"
        let uptimeResult = await baseService.execute(uptimeCmd, via: session)
        info.uptime = uptimeResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Connections
        let connCmd = "sudo -u postgres psql -t -c \"SELECT count(*) FROM pg_stat_activity;\" 2>/dev/null"
        let connResult = await baseService.execute(connCmd, via: session)
        if let count = Int(connResult.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
            info.threads = count // Using threads field for connections
            info.activeConnections = count
        }
        
        // Traffic/Queries (approximate via pg_stat_database)
        let qCmd = "sudo -u postgres psql -t -c \"SELECT sum(xact_commit + xact_rollback) FROM pg_stat_database;\" 2>/dev/null"
        let qResult = await baseService.execute(qCmd, via: session)
        info.userQueries = qResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        await MainActor.run {
            self.statusInfo = info
            self.uptime = info.uptime
            self.isLoadingStatus = false
        }
    }
}
