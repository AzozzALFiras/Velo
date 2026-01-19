import Foundation

/// Models for Node.js Management

struct NodePackage: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let version: String
    let isGlobal: Bool
    let path: String?
}

struct NodeEnvironment: Identifiable {
    let id = UUID()
    let version: String
    let npmVersion: String
    let globalPackages: [NodePackage]
}
