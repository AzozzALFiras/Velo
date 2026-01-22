//
//  SystemMonitor.swift
//  Velo
//
//  Root Feature - System Information Monitor Service
//  Shows CPU, Memory, Disk usage for local or remote systems
//

import SwiftUI

// MARK: - System Monitor

/// Observable system statistics service
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
