//
//  VeloApp.swift
//  Velo
//
//  AI-Powered Terminal Application
//

import SwiftUI

@main
struct VeloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var sshManager = SSHManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1200, minHeight: 700)
                .preferredColorScheme(.dark)
                .environmentObject(themeManager)
                .environmentObject(sshManager)
                .onAppear {
                    // Wire up theme manager to design system
                    VeloDesign.ThemeAware.themeManager = themeManager
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            // Terminal commands
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: .newTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Divider()
                
                Button("Clear Screen") {
                    NotificationCenter.default.post(name: .clearScreen, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Button("Interrupt") {
                    NotificationCenter.default.post(name: .interrupt, object: nil)
                }
                .keyboardShortcut("c", modifiers: .control)
            }
            
            // View commands
            CommandGroup(after: .toolbar) {
                Button("Toggle History Sidebar") {
                    NotificationCenter.default.post(name: .toggleHistorySidebar, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)
                
                Button("Toggle AI Panel") {
                    NotificationCenter.default.post(name: .toggleAIPanel, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure window appearance
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = NSColor(VeloDesign.Colors.deepSpace)
            window.isMovableByWindowBackground = true
            
            // Add vibrancy
            window.contentView?.wantsLayer = true
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Notification Names

