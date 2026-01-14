//
//  DockerManager.swift
//  Velo
//
//  Dashboard Redesign - Docker Management Service
//  Handles container status, lifecycle, and logs.
//

import SwiftUI
import Observation

// MARK: - Models

struct DockerContainer: Identifiable, Codable {
    let id: String
    let name: String
    let image: String
    let status: ContainerStatus
    let cpuUsage: Double
    let memoryUsage: String
    let ports: [String]
    let createdAt: Date
    
    enum ContainerStatus: String, Codable {
        case running, stopped, restarting, paused, exiting
        
        var color: Color {
            switch self {
            case .running: return ColorTokens.success
            case .stopped: return ColorTokens.textTertiary
            case .restarting: return ColorTokens.warning
            case .paused: return ColorTokens.info
            case .exiting: return ColorTokens.error
            }
        }
    }
}

// MARK: - Manager

@Observable
class DockerManager {
    var containers: [DockerContainer] = []
    var isRefreshing: Bool = false
    
    // Mock data for development
    init() {
        refresh()
    }
    
    func refresh() {
        isRefreshing = true
        
        // Simulate real docker ps call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.containers = [
                DockerContainer(
                    id: "c1",
                    name: "velo-api-server",
                    image: "velo/api:latest",
                    status: .running,
                    cpuUsage: 1.2,
                    memoryUsage: "128MB",
                    ports: ["8080:80"],
                    createdAt: Date().addingTimeInterval(-3600 * 24)
                ),
                DockerContainer(
                    id: "c2",
                    name: "velo-postgres-db",
                    image: "postgres:15-alpine",
                    status: .running,
                    cpuUsage: 0.5,
                    memoryUsage: "256MB",
                    ports: ["5432:5432"],
                    createdAt: Date().addingTimeInterval(-3600 * 48)
                ),
                DockerContainer(
                    id: "c3",
                    name: "velo-redis-cache",
                    image: "redis:7-alpine",
                    status: .stopped,
                    cpuUsage: 0.0,
                    memoryUsage: "0MB",
                    ports: ["6379:6379"],
                    createdAt: Date().addingTimeInterval(-3600 * 72)
                )
            ]
            self.isRefreshing = false
        }
    }
    
    func startContainer(_ id: String) {
        if let index = containers.firstIndex(where: { $0.id == id }) {
            // In a real app, run 'docker start <id>'
            print("Starting container: \(id)")
            refresh()
        }
    }
    
    func stopContainer(_ id: String) {
        if let index = containers.firstIndex(where: { $0.id == id }) {
            // In a real app, run 'docker stop <id>'
            print("Stopping container: \(id)")
            refresh()
        }
    }
    
    func restartContainer(_ id: String) {
        if let index = containers.firstIndex(where: { $0.id == id }) {
            // In a real app, run 'docker restart <id>'
            print("Restarting container: \(id)")
            refresh()
        }
    }
}
