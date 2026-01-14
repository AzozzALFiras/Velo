//
//  SystemMonitor.swift
//  Velo
//
//  Dashboard Redesign - System Information Monitor
//  Shows CPU, Memory, Disk usage for local or remote systems
//

import SwiftUI

// MARK: - System Stats

/// Observable system statistics
@Observable
final class SystemMonitor {
    
    // Stats
    var cpuUsage: Double = 0
    var memoryUsage: Double = 0
    var memoryUsed: String = "0 GB"
    var memoryTotal: String = "0 GB"
    var diskUsage: Double = 0
    var diskUsed: String = "0 GB"
    var diskTotal: String = "0 GB"
    var hostname: String = "localhost"
    var isRemote: Bool = false
    var uptime: String = ""
    
    // Refresh timer
    private var timer: Timer?
    
    init() {
        refresh()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func refresh() {
        Task { @MainActor in
            await updateStats()
        }
    }
    
    @MainActor
    private func updateStats() async {
        // Get hostname
        hostname = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        
        // Get memory info
        let memInfo = getMemoryInfo()
        memoryUsage = memInfo.usage
        memoryUsed = formatBytes(memInfo.used)
        memoryTotal = formatBytes(memInfo.total)
        
        // Get CPU usage (simplified)
        cpuUsage = getCPUUsage()
        
        // Get disk info
        let diskInfo = getDiskInfo()
        diskUsage = diskInfo.usage
        diskUsed = formatBytes(diskInfo.used)
        diskTotal = formatBytes(diskInfo.total)
        
        // Get uptime
        uptime = getUptime()
    }
    
    private func getMemoryInfo() -> (usage: Double, used: UInt64, total: UInt64) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return (0, 0, 0)
        }
        
        let pageSize = UInt64(vm_kernel_page_size)
        let total = ProcessInfo.processInfo.physicalMemory
        let free = UInt64(stats.free_count) * pageSize
        let used = total - free
        let usage = Double(used) / Double(total)
        
        return (usage, used, total)
    }
    
    private func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )
        
        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return 0
        }
        
        var totalUsage: Double = 0
        
        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = Double(info[offset + Int(CPU_STATE_USER)])
            let system = Double(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Double(info[offset + Int(CPU_STATE_IDLE)])
            let nice = Double(info[offset + Int(CPU_STATE_NICE)])
            
            let total = user + system + idle + nice
            let usage = (user + system + nice) / total
            totalUsage += usage
        }
        
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCPUInfo))
        
        return totalUsage / Double(numCPUs)
    }
    
    private func getDiskInfo() -> (usage: Double, used: UInt64, total: UInt64) {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = (attrs[.systemSize] as? UInt64) ?? 0
            let free = (attrs[.systemFreeSize] as? UInt64) ?? 0
            let used = total - free
            let usage = Double(used) / Double(total)
            return (usage, used, total)
        } catch {
            return (0, 0, 0)
        }
    }
    
    private func getUptime() -> String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let days = hours / 24
        
        if days > 0 {
            return "\(days)d \(hours % 24)h"
        } else {
            return "\(hours)h"
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else {
            let mb = Double(bytes) / 1_048_576
            return String(format: "%.0f MB", mb)
        }
    }
}

// MARK: - System Info Bar View

/// Compact system information bar
struct SystemInfoBar: View {
    
    let monitor: SystemMonitor
    var isSSH: Bool = false
    var serverName: String? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            // Host indicator
            HStack(spacing: 6) {
                Image(systemName: isSSH ? "server.rack" : "laptopcomputer")
                    .font(.system(size: 10))
                    .foregroundStyle(isSSH ? ColorTokens.success : ColorTokens.accentPrimary)
                
                Text(serverName ?? monitor.hostname)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
            }
            
            Divider()
                .frame(height: 14)
            
            // CPU
            StatPill(
                icon: "cpu",
                label: "CPU",
                value: String(format: "%.0f%%", monitor.cpuUsage * 100),
                color: colorForUsage(monitor.cpuUsage)
            )
            
            // Memory
            StatPill(
                icon: "memorychip",
                label: "RAM",
                value: String(format: "%.0f%%", monitor.memoryUsage * 100),
                color: colorForUsage(monitor.memoryUsage)
            )
            
            // Disk
            StatPill(
                icon: "internaldrive",
                label: "Disk",
                value: String(format: "%.0f%%", monitor.diskUsage * 100),
                color: colorForUsage(monitor.diskUsage)
            )
            
            // Uptime
            if !monitor.uptime.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(monitor.uptime)
                        .font(.system(size: 10))
                }
                .foregroundStyle(ColorTokens.textTertiary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(ColorTokens.layer1)
    }
    
    private func colorForUsage(_ usage: Double) -> Color {
        if usage > 0.9 {
            return ColorTokens.error
        } else if usage > 0.7 {
            return ColorTokens.warning
        } else {
            return ColorTokens.success
        }
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .help("\(label): \(value)")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        SystemInfoBar(monitor: SystemMonitor())
        
        Divider()
        
        SystemInfoBar(
            monitor: SystemMonitor(),
            isSSH: true,
            serverName: "production-server"
        )
    }
    .frame(width: 600)
}
