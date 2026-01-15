//
//  ContentView.swift
//  Velo
//
//  AI-Powered Terminal - Main Entry Point
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        WorkspaceRoot()
            .localizedLayout()
    }
}

#Preview("Workspace") {
    ContentView()
        .frame(width: 1200, height: 700)
}

