//
//  SettingsView.swift
//  Velo
//
//  Settings view - Now redirects to tab-based coordinator
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    var onClose: (() -> Void)? = nil

    var body: some View {
        SettingsTabCoordinator(onClose: onClose)
    }
}

#Preview {
    SettingsView()
}
