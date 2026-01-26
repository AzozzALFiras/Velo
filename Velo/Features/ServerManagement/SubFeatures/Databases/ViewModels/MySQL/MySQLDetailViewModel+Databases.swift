import Foundation

extension MySQLDetailViewModel {
    
    func loadDatabases() async {
        guard let session = session else { return }
        
        await MainActor.run {
            isLoadingDatabases = true
        }
        
        let dbs = await service.fetchDatabases(via: session)
        
        await MainActor.run {
            self.databases = dbs
            self.isLoadingDatabases = false
        }
    }
    
    func createDatabase(name: String) async {
        guard let session = session else { return }
        
        await performAsyncAction("Create Database") {
            let success = await service.createDatabase(name: name, username: nil, password: nil, via: session)
            if success {
                await self.loadDatabases()
                return (true, "Database '\(name)' created successfully")
            } else {
                return (false, "Failed to create database")
            }
        }
    }
    
    func deleteDatabase(_ name: String) async {
        guard let session = session else { return }
        
        await performAsyncAction("Delete Database") {
            let success = await service.deleteDatabase(name: name, via: session)
            if success {
                await self.loadDatabases()
                return (true, "Database '\(name)' deleted successfully")
            } else {
                return (false, "Failed to delete database")
            }
        }
    }
}
