import Foundation

// NginxDetailSection moved to Enums/NginxDetailSection.swift

// NginxConfigValue replaced by SharedConfigValue in Models/Shared/SharedConfigValue.swift

struct NginxStatusInfo {
    let activeConnections: Int
    let accepts: Int
    let handled: Int
    let requests: Int
    let reading: Int
    let writing: Int
    let waiting: Int
}
