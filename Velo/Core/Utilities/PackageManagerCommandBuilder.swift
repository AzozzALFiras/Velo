//
//  PackageManagerCommandBuilder.swift
//  Velo
//
//  Centralized, OS-aware command builder for package management.
//  Generates fully non-interactive install/update/remove commands
//  for any detected Linux distribution.
//

import Foundation

struct PackageManagerCommandBuilder {

    // MARK: - Package Manager Type

    enum PackageManager: String, Sendable {
        case apt       // Debian, Ubuntu, Mint, Pop!_OS, Kali
        case dnf       // Fedora, RHEL 8+, AlmaLinux, Rocky
        case yum       // CentOS 7, RHEL 7
        case pacman    // Arch, Manjaro
        case zypper    // openSUSE, SLES
    }

    // MARK: - Detection

    /// Determine package manager from OS ID (from /etc/os-release)
    static func detect(from osId: String) -> PackageManager {
        let id = osId.lowercased()
        switch id {
        case "ubuntu", "debian", "linuxmint", "pop", "kali", "raspbian", "elementary":
            return .apt
        case "fedora", "rhel", "almalinux", "rocky":
            return .dnf
        case "centos":
            return .yum
        case "arch", "manjaro":
            return .pacman
        case "opensuse", "opensuse-leap", "opensuse-tumbleweed", "sles":
            return .zypper
        default:
            // Safe default for most cloud servers
            return .apt
        }
    }

    // MARK: - Install

    /// Generate a fully non-interactive install command.
    /// Returns the complete command string including sudo and all safety flags.
    static func installCommand(
        packages: [String],
        packageManager: PackageManager,
        withUpdate: Bool = false
    ) -> String {
        guard !packages.isEmpty else { return "" }

        switch packageManager {
        case .apt:
            return aptInstallCommand(packages: packages, withUpdate: withUpdate)
        case .dnf:
            return dnfInstallCommand(packages: packages, withUpdate: withUpdate)
        case .yum:
            return yumInstallCommand(packages: packages, withUpdate: withUpdate)
        case .pacman:
            return pacmanInstallCommand(packages: packages)
        case .zypper:
            return zypperInstallCommand(packages: packages)
        }
    }

    // MARK: - Update

    /// Generate a repository update/refresh command.
    static func updateCommand(packageManager: PackageManager) -> String {
        switch packageManager {
        case .apt:
            return "sudo apt-get update"
        case .dnf:
            return "sudo dnf makecache -q"
        case .yum:
            return "sudo yum makecache -q"
        case .pacman:
            return "sudo pacman -Sy --noconfirm"
        case .zypper:
            return "sudo zypper --non-interactive refresh"
        }
    }

    // MARK: - Remove

    /// Generate a remove/uninstall command.
    static func removeCommand(
        packages: [String],
        packageManager: PackageManager,
        purge: Bool = false
    ) -> String {
        guard !packages.isEmpty else { return "" }
        let packageList = packages.joined(separator: " ")

        switch packageManager {
        case .apt:
            let action = purge ? "purge" : "remove"
            return "sudo apt-get \(action) -y \(packageList)"
        case .dnf:
            return "sudo dnf remove -y -q \(packageList)"
        case .yum:
            return "sudo yum remove -y -q \(packageList)"
        case .pacman:
            return "sudo pacman -R --noconfirm \(packageList)"
        case .zypper:
            return "sudo zypper --non-interactive remove \(packageList)"
        }
    }

    // MARK: - Private: Per-Manager Builders

    /// The "golden pattern" for apt - fully non-interactive, quiet, auto-config.
    /// -q: suppress progress bar noise
    /// --force-confdef: auto-select default config behavior
    /// --force-confold: keep existing config files (prevents blocking prompts)
    private static func aptInstallCommand(packages: [String], withUpdate: Bool) -> String {
        let packageList = packages.joined(separator: " ")
        // We now rely on ServerAdminTerminalEngine to inject DEBIAN_FRONTEND and robust flags
        // including hook disabling and conflict resolution.
        let updatePrefix = withUpdate
            ? "sudo apt-get update || true && "
            : ""

        return "\(updatePrefix)sudo apt-get install -y \(packageList)"
    }

    private static func dnfInstallCommand(packages: [String], withUpdate: Bool) -> String {
        let packageList = packages.joined(separator: " ")
        let updatePrefix = withUpdate ? "sudo dnf makecache -q || true && " : ""
        return "\(updatePrefix)sudo dnf install -y -q \(packageList)"
    }

    private static func yumInstallCommand(packages: [String], withUpdate: Bool) -> String {
        let packageList = packages.joined(separator: " ")
        let updatePrefix = withUpdate ? "sudo yum makecache -q || true && " : ""
        return "\(updatePrefix)sudo yum install -y -q \(packageList)"
    }

    private static func pacmanInstallCommand(packages: [String]) -> String {
        let packageList = packages.joined(separator: " ")
        return "sudo pacman -S --noconfirm --needed \(packageList)"
    }

    private static func zypperInstallCommand(packages: [String]) -> String {
        let packageList = packages.joined(separator: " ")
        return "sudo zypper --non-interactive install \(packageList)"
    }
}
