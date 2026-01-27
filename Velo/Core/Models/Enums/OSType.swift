//
//  OSType.swift
//  Velo
//
//  Classification of Linux distributions by package manager family.
//

import Foundation

public enum OSType: Sendable {
    case debian    // Debian, Ubuntu, Mint, Pop, Kali, Raspbian, Elementary
    case rhel      // RHEL, CentOS, Fedora, AlmaLinux, Rocky
    case arch      // Arch, Manjaro
    case suse      // openSUSE, SLES
    case unknown

    /// Map an OS ID string (from /etc/os-release) to an OSType
    static func from(osId: String) -> OSType {
        let id = osId.lowercased()
        switch id {
        case "ubuntu", "debian", "linuxmint", "pop", "kali", "raspbian", "elementary":
            return .debian
        case "fedora", "rhel", "almalinux", "rocky", "centos":
            return .rhel
        case "arch", "manjaro":
            return .arch
        case "opensuse", "opensuse-leap", "opensuse-tumbleweed", "sles":
            return .suse
        default:
            return .unknown
        }
    }

    /// Convenience: the corresponding package manager for this OS type
    var packageManager: PackageManagerCommandBuilder.PackageManager {
        switch self {
        case .debian:  return .apt
        case .rhel:    return .dnf
        case .arch:    return .pacman
        case .suse:    return .zypper
        case .unknown: return .apt // Safe default for most cloud servers
        }
    }
}
