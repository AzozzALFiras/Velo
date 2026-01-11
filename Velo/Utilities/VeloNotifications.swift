//
//  VeloNotifications.swift
//  Velo
//
//  Centralized Notification Definitions
//

import Foundation

extension Notification.Name {
    static let clearScreen = Notification.Name("clearScreen")
    static let interrupt = Notification.Name("interrupt")
    static let toggleHistorySidebar = Notification.Name("toggleHistorySidebar")
    static let toggleAIPanel = Notification.Name("Velo.toggleAIPanel")
    static let askAI = Notification.Name("Velo.askAI") // userInfo: ["query": String]
    static let newTab = Notification.Name("newTab")
}
