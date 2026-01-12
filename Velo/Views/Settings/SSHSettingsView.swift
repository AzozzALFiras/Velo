//
//  SSHSettingsView.swift
//  Velo
//
//  SSH Connection Management UI
//

import SwiftUI

struct SSHSettingsView: View {
    @EnvironmentObject var sshManager: SSHManager
    @State private var showingEditor = false
    @State private var editingConnection: SSHConnection?
    @State private var showingGroupEditor = false
    @State private var showingImportAlert = false
    @State private var importCount = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.lg) {
            // Header
            HStack {
                SectionHeader(title: "SSH Connections")
                Spacer()
                
                // Import button
                Button(action: importFromConfig) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundColor(VeloDesign.Colors.neonCyan)
                .help("Import from ~/.ssh/config")
                
                // Add group
                Button(action: { showingGroupEditor = true }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundColor(VeloDesign.Colors.neonCyan)
                .help("Add Group")
                
                // Add connection
                Button(action: { showingEditor = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .foregroundColor(VeloDesign.Colors.neonCyan)
                .help("Add Connection")
            }
            
            // Connections list
            if sshManager.connections.isEmpty {
                EmptySSHView(onAdd: { showingEditor = true }, onImport: importFromConfig)
            } else {
                VStack(spacing: VeloDesign.Spacing.sm) {
                    // Groups
                    ForEach(sshManager.groups) { group in
                        SSHGroupSection(
                            group: group,
                            connections: sshManager.connections(in: group),
                            onEdit: { editingConnection = $0 },
                            onDelete: { sshManager.deleteConnection($0) }
                        )
                    }
                    
                    // Ungrouped
                    let ungrouped = sshManager.ungroupedConnections()
                    if !ungrouped.isEmpty {
                        SSHGroupSection(
                            group: nil,
                            connections: ungrouped,
                            onEdit: { editingConnection = $0 },
                            onDelete: { sshManager.deleteConnection($0) }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            SSHConnectionEditor(connection: nil)
        }
        .sheet(item: $editingConnection) { connection in
            SSHConnectionEditor(connection: connection)
        }
        .sheet(isPresented: $showingGroupEditor) {
            SSHGroupEditor(group: nil)
        }
        .alert("Import Complete", isPresented: $showingImportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Imported \(importCount) connection\(importCount == 1 ? "" : "s") from ~/.ssh/config")
        }
    }
    
    private func importFromConfig() {
        importCount = sshManager.importFromSSHConfig()
        showingImportAlert = true
    }
}

// MARK: - Empty State
struct EmptySSHView: View {
    let onAdd: () -> Void
    let onImport: () -> Void
    
    var body: some View {
        VStack(spacing: VeloDesign.Spacing.md) {
            Image(systemName: "server.rack")
                .font(.system(size: 40))
                .foregroundColor(VeloDesign.Colors.textMuted)
            
            Text("No SSH Connections")
                .font(VeloDesign.Typography.subheadline)
                .foregroundColor(VeloDesign.Colors.textSecondary)
            
            HStack(spacing: VeloDesign.Spacing.md) {
                Button(action: onAdd) {
                    Label("Add Connection", systemImage: "plus")
                        .font(VeloDesign.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(VeloDesign.Colors.neonCyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(VeloDesign.Colors.neonCyan.opacity(0.1))
                .cornerRadius(6)
                
                Button(action: onImport) {
                    Label("Import from Config", systemImage: "square.and.arrow.down")
                        .font(VeloDesign.Typography.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(VeloDesign.Colors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(VeloDesign.Colors.cardBackground)
                .cornerRadius(6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VeloDesign.Spacing.xl)
    }
}

// MARK: - Group Section
struct SSHGroupSection: View {
    let group: SSHConnectionGroup?
    let connections: [SSHConnection]
    let onEdit: (SSHConnection) -> Void
    let onDelete: (SSHConnection) -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(VeloDesign.Colors.textMuted)
                        .frame(width: 16)
                    
                    if let group = group {
                        Image(systemName: group.icon)
                            .foregroundColor(group.color)
                    } else {
                        Image(systemName: "tray")
                            .foregroundColor(VeloDesign.Colors.textMuted)
                    }
                    
                    Text(group?.name ?? "Ungrouped")
                        .font(VeloDesign.Typography.caption)
                        .foregroundColor(VeloDesign.Colors.textSecondary)
                    
                    Text("(\(connections.count))")
                        .font(VeloDesign.Typography.caption)
                        .foregroundColor(VeloDesign.Colors.textMuted)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            
            // Connections
            if isExpanded {
                ForEach(connections) { connection in
                    SSHConnectionRow(
                        connection: connection,
                        onEdit: { onEdit(connection) },
                        onDelete: { onDelete(connection) }
                    )
                }
            }
        }
        .background(VeloDesign.Colors.cardBackground.opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Connection Row
struct SSHConnectionRow: View {
    let connection: SSHConnection
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: VeloDesign.Spacing.sm) {
            // Icon
            Image(systemName: connection.icon)
                .font(.system(size: 16))
                .foregroundColor(connection.color)
                .frame(width: 24)
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.displayName)
                    .font(VeloDesign.Typography.monoFont)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                
                Text(connection.connectionString)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textMuted)
            }
            
            Spacer()
            
            // Auth method badge
            Image(systemName: connection.authMethod.icon)
                .font(.system(size: 12))
                .foregroundColor(VeloDesign.Colors.textMuted)
                .help(connection.authMethod.displayName)
            
            // Actions (visible on hover)
            if isHovered {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(VeloDesign.Colors.neonCyan)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(VeloDesign.Colors.error)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? VeloDesign.Colors.glassBorder : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Connection Editor
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
            _colorHex = State(initialValue: "00F5FF")
            _icon = State(initialValue: "server.rack")
            _notes = State(initialValue: "")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Connection" : "New SSH Connection")
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(VeloDesign.Colors.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(VeloDesign.Colors.darkSurface)
            
            ScrollView {
                VStack(alignment: .leading, spacing: VeloDesign.Spacing.lg) {
                    // Basic Info
                    VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                        Text("Connection")
                            .font(VeloDesign.Typography.caption)
                            .foregroundColor(VeloDesign.Colors.textMuted)
                        
                        EditorField(label: "Name", placeholder: "My Server", text: $name)
                        EditorField(label: "Host", placeholder: "example.com", text: $host)
                        
                        HStack {
                            EditorField(label: "Port", placeholder: "22", text: $port)
                                .frame(width: 100)
                            EditorField(label: "Username", placeholder: NSUserName(), text: $username)
                        }
                    }
                    
                    Divider().background(VeloDesign.Colors.glassBorder)
                    
                    // Authentication
                    VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                        Text("Authentication")
                            .font(VeloDesign.Typography.caption)
                            .foregroundColor(VeloDesign.Colors.textMuted)
                        
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
                                .font(VeloDesign.Typography.monoFont)
                                .padding(8)
                                .background(VeloDesign.Colors.cardBackground)
                                .cornerRadius(6)
                        case .privateKey:
                            EditorField(label: "Key Path", placeholder: "~/.ssh/id_rsa", text: $privateKeyPath)
                        case .sshAgent:
                            Text("Will use SSH Agent for authentication")
                                .font(VeloDesign.Typography.caption)
                                .foregroundColor(VeloDesign.Colors.textMuted)
                        }
                    }
                    
                    Divider().background(VeloDesign.Colors.glassBorder)
                    
                    // Appearance
                    VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                        Text("Appearance")
                            .font(VeloDesign.Typography.caption)
                            .foregroundColor(VeloDesign.Colors.textMuted)
                        
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
                    
                    Divider().background(VeloDesign.Colors.glassBorder)
                    
                    // Notes
                    VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                        Text("Notes")
                            .font(VeloDesign.Typography.caption)
                            .foregroundColor(VeloDesign.Colors.textMuted)
                        
                        TextEditor(text: $notes)
                            .font(VeloDesign.Typography.monoSmall)
                            .frame(height: 60)
                            .padding(4)
                            .background(VeloDesign.Colors.cardBackground)
                            .cornerRadius(6)
                    }
                }
                .padding()
            }
            
            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(VeloDesign.Colors.textSecondary)
                
                Spacer()
                
                Button(action: save) {
                    Text(isEditing ? "Save" : "Add Connection")
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(VeloDesign.Colors.neonCyan)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(host.isEmpty || username.isEmpty)
            }
            .padding()
            .background(VeloDesign.Colors.darkSurface)
        }
        .frame(width: 450, height: 550)
        .background(VeloDesign.Colors.deepSpace)
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

// MARK: - Editor Field
struct EditorField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.textMuted)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(VeloDesign.Typography.monoFont)
                .padding(8)
                .background(VeloDesign.Colors.cardBackground)
                .cornerRadius(6)
        }
    }
}

// MARK: - Group Editor
struct SSHGroupEditor: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sshManager: SSHManager
    
    @State private var name: String
    @State private var colorHex: String
    @State private var icon: String
    
    private let isEditing: Bool
    private let groupId: UUID?
    
    init(group: SSHConnectionGroup?) {
        if let g = group {
            self.isEditing = true
            self.groupId = g.id
            _name = State(initialValue: g.name)
            _colorHex = State(initialValue: g.colorHex)
            _icon = State(initialValue: g.icon)
        } else {
            self.isEditing = false
            self.groupId = nil
            _name = State(initialValue: "")
            _colorHex = State(initialValue: "A0A0B0")
            _icon = State(initialValue: "folder.fill")
        }
    }
    
    var body: some View {
        VStack(spacing: VeloDesign.Spacing.lg) {
            Text(isEditing ? "Edit Group" : "New Group")
                .font(VeloDesign.Typography.headline)
            
            EditorField(label: "Name", placeholder: "Production Servers", text: $name)
            
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
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: save) {
                    Text(isEditing ? "Save" : "Create")
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(VeloDesign.Colors.neonCyan)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .background(VeloDesign.Colors.deepSpace)
    }
    
    private func save() {
        let group = SSHConnectionGroup(
            id: groupId ?? UUID(),
            name: name,
            colorHex: colorHex,
            icon: icon
        )
        
        if isEditing {
            sshManager.updateGroup(group)
        } else {
            sshManager.addGroup(group)
        }
        
        dismiss()
    }
}
