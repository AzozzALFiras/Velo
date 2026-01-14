//
//  ContentView.swift
//  Velo
//
//  AI-Powered Terminal - Main Entry Point
//  Switches between legacy TerminalWallView and new DashboardRoot
//

import SwiftUI

struct ContentView: View {
    
    // Feature flag for new Dashboard UI
    @AppStorage("useDashboardUI") private var useDashboardUI = true
    
    var body: some View {
        Group {
            if useDashboardUI {
                DashboardRoot()
            } else {
                TerminalWallView()
            }
        }
    }
}

#Preview("Legacy Terminal") {
    ContentView()
        .frame(width: 1200, height: 700)
}

#Preview("New Dashboard") {
    DashboardRoot()
        .frame(width: 1400, height: 800)
}
