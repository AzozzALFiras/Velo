//
//  SystemStatsService.swift
//  Velo
//
//  Consolidated service for gathering system statistics including CPU, RAM, Disk, Network, and Uptime.
//  Provides both individual stat fetching and optimized batch operations.
//

import Foundation
import Combine

@MainActor
final class SystemStatsService: ObservableObject {
    static let shared = SystemStatsService()

    private let baseService = SSHBaseService.shared

    private init() {}

    // MARK: - Batch Statistics

    /// Fetch all system stats in a single optimized batch command
    func fetchAllStats(via session: TerminalViewModel) async -> SystemStats {
        let batchCommand = """
        echo "HOSTNAME" && hostname && \
        echo "IP" && hostname -I 2>/dev/null | awk '{print $1}' && \
        echo "OS" && cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' && \
        echo "UPTIME" && uptime -p 2>/dev/null && \
        echo "CPU" && top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' && \
        echo "LOAD" && cat /proc/loadavg | awk '{print $1}' && \
        echo "MEM" && free -m | grep Mem | awk '{print $2,$3,$4,$7}' && \
        echo "DISK" && df -h / | tail -n 1 | awk '{print $2,$3,$4,$5}'
        """

        let result = await baseService.execute(batchCommand, via: session, timeout: 20)
        return parseStatsBatch(result.output)
    }

    /// Fetch quick stats (CPU, RAM, Disk only) for live updates
    func fetchQuickStats(via session: TerminalViewModel) async -> (cpu: Double, ram: Double, disk: Double) {
        let quickCommand = """
        echo "CPU" && top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' && \
        echo "MEM" && free -m | grep Mem | awk '{print $3,$2}' && \
        echo "DISK" && df -h / | tail -n 1 | awk '{print $5}'
        """

        let result = await baseService.execute(quickCommand, via: session, timeout: 10)
        return parseQuickStats(result.output)
    }

    // MARK: - Individual Statistics

    /// Get CPU usage percentage (0.0 - 1.0)
    func getCPUUsage(via session: TerminalViewModel) async -> Double {
        let result = await baseService.execute("top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}'", via: session, timeout: 10)
        if let value = Double(result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) {
            return min(value / 100.0, 1.0)
        }
        return 0.0
    }

    /// Get CPU load average (1, 5, 15 minutes)
    func getLoadAverage(via session: TerminalViewModel) async -> (load1: Double, load5: Double, load15: Double) {
        let result = await baseService.execute("cat /proc/loadavg | awk '{print $1,$2,$3}'", via: session, timeout: 10)
        let parts = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).split(separator: " ").compactMap { Double($0) }

        return (
            load1: parts.count > 0 ? parts[0] : 0,
            load5: parts.count > 1 ? parts[1] : 0,
            load15: parts.count > 2 ? parts[2] : 0
        )
    }

    /// Get RAM usage
    func getRAMUsage(via session: TerminalViewModel) async -> MemoryStats {
        let result = await baseService.execute("free -m | grep Mem | awk '{print $2,$3,$4,$7}'", via: session, timeout: 10)
        let parts = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).split(separator: " ").compactMap { Int($0) }

        let total = parts.count > 0 ? parts[0] : 0
        let used = parts.count > 1 ? parts[1] : 0
        let free = parts.count > 2 ? parts[2] : 0
        let available = parts.count > 3 ? parts[3] : free

        return MemoryStats(
            totalMB: total,
            usedMB: used,
            freeMB: free,
            availableMB: available,
            usagePercent: total > 0 ? Double(used) / Double(total) : 0
        )
    }

    /// Get disk usage for root partition
    func getDiskUsage(via session: TerminalViewModel) async -> DiskStats {
        let result = await baseService.execute("df -h / | tail -n 1 | awk '{print $2,$3,$4,$5}'", via: session, timeout: 10)
        let parts = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).split(separator: " ").map { String($0) }

        let total = parts.count > 0 ? parts[0] : "0"
        let used = parts.count > 1 ? parts[1] : "0"
        let available = parts.count > 2 ? parts[2] : "0"
        let percentStr = parts.count > 3 ? parts[3].replacingOccurrences(of: "%", with: "") : "0"
        let percent = (Double(percentStr) ?? 0) / 100.0

        return DiskStats(
            totalFormatted: total,
            usedFormatted: used,
            availableFormatted: available,
            usagePercent: percent
        )
    }

    /// Get system uptime
    func getUptime(via session: TerminalViewModel) async -> String {
        let result = await baseService.execute("uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}'", via: session, timeout: 10)
        return result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    /// Get hostname
    func getHostname(via session: TerminalViewModel) async -> String {
        let result = await baseService.execute("hostname", via: session, timeout: 10)
        return result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    /// Get IP address
    func getIPAddress(via session: TerminalViewModel) async -> String {
        let result = await baseService.execute("hostname -I 2>/dev/null | awk '{print $1}'", via: session, timeout: 10)
        let ip = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return ip.isEmpty ? "Unknown" : ip
    }

    /// Get OS information
    func getOSInfo(via session: TerminalViewModel) async -> OSInfo {
        let result = await baseService.execute("""
            echo "NAME" && cat /etc/os-release | grep -E '^PRETTY_NAME=' | cut -d= -f2 | tr -d '"' && \
            echo "ID" && cat /etc/os-release | grep -E '^ID=' | cut -d= -f2 | tr -d '"' && \
            echo "VERSION" && cat /etc/os-release | grep -E '^VERSION_ID=' | cut -d= -f2 | tr -d '"' && \
            echo "KERNEL" && uname -r
        """, via: session, timeout: 10)

        return parseOSInfo(result.output)
    }

    // MARK: - Network Statistics

    /// Get network traffic statistics
    func getNetworkStats(via session: TerminalViewModel) async -> NetworkStats {
        let result = await baseService.execute("""
            cat /proc/net/dev | grep -E 'eth0|ens|enp' | head -1 | awk '{print $2,$3,$10,$11}'
        """, via: session, timeout: 10)

        let parts = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).split(separator: " ").compactMap { Int64($0) }

        return NetworkStats(
            rxBytes: parts.count > 0 ? parts[0] : 0,
            rxPackets: parts.count > 1 ? parts[1] : 0,
            txBytes: parts.count > 2 ? parts[2] : 0,
            txPackets: parts.count > 3 ? parts[3] : 0
        )
    }

    // MARK: - Process Information

    /// Get top processes by CPU usage
    func getTopProcessesByCPU(count: Int = 5, via session: TerminalViewModel) async -> [ServerProcessItem] {
        let result = await baseService.execute("ps aux --sort=-%cpu | head -\(count + 1) | tail -\(count)", via: session, timeout: 10)
        return parseProcessList(result.output)
    }

    /// Get top processes by memory usage
    func getTopProcessesByMemory(count: Int = 5, via session: TerminalViewModel) async -> [ServerProcessItem] {
        let result = await baseService.execute("ps aux --sort=-%mem | head -\(count + 1) | tail -\(count)", via: session, timeout: 10)
        return parseProcessList(result.output)
    }

    // MARK: - Parsing Helpers

    private func parseStatsBatch(_ output: String) -> SystemStats {
        var stats = SystemStats()
        let lines = output.components(separatedBy: CharacterSet.newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        var currentHeader = ""
        for line in lines {
            if ["HOSTNAME", "IP", "OS", "UPTIME", "CPU", "LOAD", "MEM", "DISK"].contains(line) {
                currentHeader = line
                continue
            }

            switch currentHeader {
            case "HOSTNAME":
                stats.hostname = line
            case "IP":
                stats.ipAddress = line
            case "OS":
                stats.osName = line
            case "UPTIME":
                stats.uptime = line
            case "CPU":
                if let value = Double(line) {
                    stats.cpuUsage = min(value / 100.0, 1.0)
                }
            case "LOAD":
                if let value = Double(line) {
                    stats.loadAverage = value
                }
            case "MEM":
                let parts = line.split(separator: " ").compactMap { Int($0) }
                if parts.count >= 2 {
                    stats.ramTotalMB = parts[0]
                    stats.ramUsedMB = parts[1]
                    stats.ramUsage = parts[0] > 0 ? Double(parts[1]) / Double(parts[0]) : 0
                }
            case "DISK":
                let parts = line.split(separator: " ").map { String($0) }
                if parts.count >= 4 {
                    stats.diskTotal = parts[0]
                    stats.diskUsed = parts[1]
                    stats.diskAvailable = parts[2]
                    let percentStr = parts[3].replacingOccurrences(of: "%", with: "")
                    stats.diskUsage = (Double(percentStr) ?? 0) / 100.0
                }
            default: break
            }
        }

        return stats
    }

    private func parseQuickStats(_ output: String) -> (cpu: Double, ram: Double, disk: Double) {
        var cpu: Double = 0
        var ram: Double = 0
        var disk: Double = 0

        let lines = output.components(separatedBy: CharacterSet.newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        var currentHeader = ""
        for line in lines {
            if ["CPU", "MEM", "DISK"].contains(line) {
                currentHeader = line
                continue
            }

            switch currentHeader {
            case "CPU":
                if let value = Double(line) {
                    cpu = min(value / 100.0, 1.0)
                }
            case "MEM":
                let parts = line.split(separator: " ").compactMap { Double($0) }
                if parts.count >= 2 && parts[1] > 0 {
                    ram = parts[0] / parts[1]
                }
            case "DISK":
                let percentStr = line.replacingOccurrences(of: "%", with: "")
                disk = (Double(percentStr) ?? 0) / 100.0
            default: break
            }
        }

        return (cpu, ram, disk)
    }

    private func parseOSInfo(_ output: String) -> OSInfo {
        var info = OSInfo()
        let lines = output.components(separatedBy: CharacterSet.newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        var currentHeader = ""
        for line in lines {
            if ["NAME", "ID", "VERSION", "KERNEL"].contains(line) {
                currentHeader = line
                continue
            }

            switch currentHeader {
            case "NAME": info.prettyName = line
            case "ID": info.id = line
            case "VERSION": info.versionId = line
            case "KERNEL": info.kernelVersion = line
            default: break
            }
        }

        return info
    }

    private func parseProcessList(_ output: String) -> [ServerProcessItem] {
        var processes: [ServerProcessItem] = []
        let lines = output.components(separatedBy: CharacterSet.newlines)

        for line in lines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true).map { String($0) }
            guard parts.count >= 11 else { continue }

            processes.append(ServerProcessItem(
                user: parts[0],
                pid: Int(parts[1]) ?? 0,
                cpuPercent: Double(parts[2]) ?? 0,
                memPercent: Double(parts[3]) ?? 0,
                command: parts[10...].joined(separator: " ")
            ))
        }

        return processes
    }
}

// MARK: - Supporting Types

struct SystemStats {
    var hostname: String = ""
    var ipAddress: String = ""
    var osName: String = ""
    var uptime: String = ""
    var cpuUsage: Double = 0
    var loadAverage: Double = 0
    var ramUsage: Double = 0
    var ramTotalMB: Int = 0
    var ramUsedMB: Int = 0
    var diskUsage: Double = 0
    var diskTotal: String = ""
    var diskUsed: String = ""
    var diskAvailable: String = ""
}

struct MemoryStats {
    let totalMB: Int
    let usedMB: Int
    let freeMB: Int
    let availableMB: Int
    let usagePercent: Double
}

struct DiskStats {
    let totalFormatted: String
    let usedFormatted: String
    let availableFormatted: String
    let usagePercent: Double
}

struct OSInfo {
    var prettyName: String = ""
    var id: String = ""
    var versionId: String = ""
    var kernelVersion: String = ""
}

struct NetworkStats {
    let rxBytes: Int64
    let rxPackets: Int64
    let txBytes: Int64
    let txPackets: Int64

    var rxKB: Double { Double(rxBytes) / 1024.0 }
    var txKB: Double { Double(txBytes) / 1024.0 }
    var rxMB: Double { Double(rxBytes) / (1024.0 * 1024.0) }
    var txMB: Double { Double(txBytes) / (1024.0 * 1024.0) }
}

struct ServerProcessItem: Identifiable {
    let id = UUID()
    let user: String
    let pid: Int
    let cpuPercent: Double
    let memPercent: Double
    let command: String
}
