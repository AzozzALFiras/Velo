//
//  ServiceAction.swift
//  Velo
//
//  Standard systemd service actions.
//

import Foundation

public enum ServiceAction: String, Sendable {
    case start = "start"
    case stop = "stop"
    case restart = "restart"
    case reload = "reload"
    case enable = "enable"
    case disable = "disable"
}
