//
//  SSHConnectionEditor.swift
//  Velo
//
//  SSH connection create/edit modal
//

import SwiftUI

struct SSHConnectionEditor: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sshManager: SSHManager

    @State private var name: String
    @State private var host: String
    @State private var port: String
    @State private var username: String
    @State private var authMethod: SSHAuthMethod
    @State private var password: String
    @State private var privateKeyPath: String
    @State private var selectedGroup: UUID?
    @State private var colorHex: String
    @State private var icon: String
    @State private var notes: String

    private let isEditing: Bool
    private let connectionId: UUID?

    private let availableIcons = [
        "server.rack", "desktopcomputer", "laptopcomputer",
        "cloud", "network", "globe", "cpu", "memorychip",
        "externaldrive", "internaldrive"
    ]

    init(connection: SSHConnection?) {
        if let conn = connection {
            self.isEditing = true
            self.connectionId = conn.id
            _name = State(initialValue: conn.name)
            _host = State(initialValue: conn.host)
            _port = State(initialValue: String(conn.port))
            _username = State(initialValue: conn.username)
            _authMethod = State(initialValue: conn.authMethod)
            _password = State(initialValue: "")
            _privateKeyPath = State(initialValue: conn.privateKeyPath ?? "")
            _selectedGroup = State(initialValue: conn.groupId)
            _colorHex = State(initialValue: conn.colorHex)
            _icon = State(initialValue: conn.icon)
            _notes = State(initialValue: conn.notes)
        } else {
            self.isEditing = false
            self.connectionId = nil
            _name = State(initialValue: "")
            _host = State(initialValue: "")
            _port = State(initialValue: "22")
            _username = State(initialValue: NSUserName())
            _authMethod = State(initialValue: .password)
            _password = State(initialValue: "")
            _privateKeyPath = State(initialValue: "~/.ssh/id_rsa")
            _selectedGroup = State(initialValue: nil)
            _colorHex = State(initialValue: "4AA9FF")
            _icon = State(initialValue: "server.rack")
            _notes = State(initialValue: "")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Connection" : "New SSH Connection")
                    .font(TypographyTokens.heading)
                    .foregroundColor(ColorTokens.textPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(ColorTokens.layer1)

            ScrollView {
                VStack(alignment: .leading, spacing: VeloDesign.Spacing.lg) {
                    // Basic Info
                    VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                        Text("Connection")
                            .font(TypographyTokens.caption)
                            .foregroundColor(ColorTokens.textTertiary)

                        VeloEditorField(label: "Name", placeholder: "My Server", text: $name)
                        VeloEditorField(label: "Host", placeholder: "example.com", text: $host)

                        HStack {
                            VeloEditorField(label: "Port", placeholder: "22", text: $port)
                                .frame(width: 100)
                            VeloEditorField(label: "Username", placeholder: NSUserName(), text: $username)
                        }
                    }

                    Divider().background(ColorTokens.borderSubtle)

                    // Authentication
                    VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                        Text("Authentication")
                            .font(TypographyTokens.caption)
                            .foregroundColor(ColorTokens.textTertiary)

                        Picker("Method", selection: $authMethod) {
                            ForEach(SSHAuthMethod.allCases) { method in
                                Label(method.displayName, systemImage: method.icon)
                                    .tag(method)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch authMethod {
                        case .password:
                            SecureField("Password", text: $password)
                                .textFieldStyle(.plain)
                                .font(TypographyTokens.mono)
                                .padding(VeloDesign.Spacing.sm)
                                .background(ColorTokens.layer2)
                                .cornerRadius(6)
                        case .privateKey:
                            VeloEditorField(label: "Key Path", placeholder: "~/.ssh/id_rsa", text: $privateKeyPath)
                        case .sshAgent:
                            Text("Will use SSH Agent for authentication")
                                .font(TypographyTokens.caption)
                                .foregroundColor(ColorTokens.textTertiary)
                        }
                    }

                    Divider().background(ColorTokens.borderSubtle)

                    // Appearance
                    VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                        Text("Appearance")
                            .font(TypographyTokens.caption)
                            .foregroundColor(ColorTokens.textTertiary)

                        HStack {
                            ColorPicker("Color", selection: Binding(
                                get: { Color(hex: colorHex) },
                                set: { newColor in
                                    if let components = NSColor(newColor).cgColor.components {
                                        let r = Int(components[0] * 255)
                                        let g = Int(components[1] * 255)
                                        let b = Int(components[2] * 255)
                                        colorHex = String(format: "%02X%02X%02X", r, g, b)
                                    }
                                }
                            ))
                            .labelsHidden()

                            Picker("Icon", selection: $icon) {
                                ForEach(availableIcons, id: \.self) { iconName in
                                    Image(systemName: iconName).tag(iconName)
                                }
                            }
                            .frame(width: 120)
                        }

                        if !sshManager.groups.isEmpty {
                            Picker("Group", selection: $selectedGroup) {
                                Text("None").tag(nil as UUID?)
                                ForEach(sshManager.groups) { group in
                                    Text(group.name).tag(group.id as UUID?)
                                }
                            }
                        }
                    }

                    Divider().background(ColorTokens.borderSubtle)

                    // Notes
                    VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                        Text("Notes")
                            .font(TypographyTokens.caption)
                            .foregroundColor(ColorTokens.textTertiary)

                        TextEditor(text: $notes)
                            .font(TypographyTokens.monoSm)
                            .frame(height: 60)
                            .padding(4)
                            .background(ColorTokens.layer2)
                            .cornerRadius(6)
                    }
                }
                .padding()
            }

            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(ColorTokens.textSecondary)

                Spacer()

                Button(action: save) {
                    Text(isEditing ? "Save" : "Add Connection")
                        .foregroundColor(.white)
                        .padding(.horizontal, VeloDesign.Spacing.lg)
                        .padding(.vertical, VeloDesign.Spacing.sm)
                        .background(ColorTokens.accentPrimary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(host.isEmpty || username.isEmpty)
            }
            .padding()
            .background(ColorTokens.layer1)
        }
        .frame(width: 450, height: 550)
        .background(ColorTokens.layer0)
    }

    private func save() {
        let connection = SSHConnection(
            id: connectionId ?? UUID(),
            name: name,
            host: host,
            port: Int(port) ?? 22,
            username: username,
            authMethod: authMethod,
            privateKeyPath: authMethod == .privateKey ? privateKeyPath : nil,
            groupId: selectedGroup,
            colorHex: colorHex,
            icon: icon,
            notes: notes
        )

        if isEditing {
            sshManager.updateConnection(connection)
        } else {
            sshManager.addConnection(connection)
        }

        // Save password if provided
        if authMethod == .password && !password.isEmpty {
            sshManager.savePassword(password, for: connection)
        }

        dismiss()
    }
}
