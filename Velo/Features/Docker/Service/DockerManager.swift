//
//  DockerManager.swift
//  Velo
//
//  Workspace Redesign - Docker Management Service
//  Handles container status, lifecycle, and logs via real docker CLI.
//

import SwiftUI
import Observation

// MARK: - Models

struct DockerContainer: Identifiable, Codable {
    let id: String
    let name: String
    let image: String
    var status: ContainerStatus
    var cpuUsage: Double
    var memoryUsage: String
    let ports: [String]
    let createdAt: Date
    
    enum ContainerStatus: String, Codable {
        case running, stopped, restarting, paused, exiting
        
        init(from state: String) {
            switch state.lowercased() {
            case "running": self = .running
            case "restarting": self = .restarting
            case "paused": self = .paused
            case "exiting", "dead": self = .exiting
            default: self = .stopped
            }
        }
        
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
    var dockerAvailable: Bool = true
    var errorMessage: String?
    
    init() {
        refresh()
    }
    
    func refresh() {
        isRefreshing = true
        errorMessage = nil
        
        Task {
            let newContainers = await fetchContainers()
            await MainActor.run {
                self.containers = newContainers
                self.isRefreshing = false
            }
        }
    }
    
    private func fetchContainers() async -> [DockerContainer] {
        // Run: docker ps -a --format json
        let output = await runCommand("docker ps -a --format '{{json .}}'")
        
        guard !output.isEmpty else {
            await MainActor.run { self.dockerAvailable = false }
            return []
        }
        
        var result: [DockerContainer] = []
        
        // Parse each line as JSON
        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                let id = json["ID"] as? String ?? ""
                let name = json["Names"] as? String ?? ""
                let image = json["Image"] as? String ?? ""
                let state = json["State"] as? String ?? "stopped"
                let ports = (json["Ports"] as? String ?? "").components(separatedBy: ", ").filter { !$0.isEmpty }
                
                let container = DockerContainer(
                    id: id,
                    name: name,
                    image: image,
                    status: .init(from: state),
                    cpuUsage: 0.0, // Would need docker stats for this
                    memoryUsage: "N/A",
                    ports: ports,
                    createdAt: Date()
                )
                result.append(container)
            }
        }
        
        return result
    }
    
    func startContainer(_ id: String) {
        Task {
            await runCommand("docker start \(id)")
            refresh()
        }
    }
    
    func stopContainer(_ id: String) {
        Task {
            await runCommand("docker stop \(id)")
            refresh()
        }
    }
    
    func restartContainer(_ id: String) {
        Task {
            await runCommand("docker restart \(id)")
            refresh()
        }
    }
    
    @discardableResult
    private func runCommand(_ command: String) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command]
                process.standardOutput = pipe
                process.standardError = pipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    print("Docker command failed: \(error)")
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
