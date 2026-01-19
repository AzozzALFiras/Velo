import Foundation

/// Models for Python Management

struct PythonPackage: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let version: String
    let location: String? // e.g. /usr/lib/python3.8/site-packages
}

struct PythonEnvironment: Identifiable {
    let id = UUID()
    let path: String
    let version: String
    let packages: [PythonPackage]
}
