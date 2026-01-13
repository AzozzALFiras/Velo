//
//  SSHGroupEditor.swift
//  Velo
//
//  SSH connection group create/edit modal
//

import SwiftUI

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
            _colorHex = State(initialValue: "94A3B8")
            _icon = State(initialValue: "folder.fill")
        }
    }

    var body: some View {
        VStack(spacing: VeloDesign.Spacing.lg) {
            Text(isEditing ? "Edit Group" : "New Group")
                .font(TypographyTokens.heading)
                .foregroundColor(ColorTokens.textPrimary)

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
                    .foregroundColor(ColorTokens.textSecondary)

                Spacer()

                Button(action: save) {
                    Text(isEditing ? "Save" : "Create")
                        .foregroundColor(.white)
                        .padding(.horizontal, VeloDesign.Spacing.lg)
                        .padding(.vertical, VeloDesign.Spacing.sm)
                        .background(ColorTokens.accentPrimary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .background(ColorTokens.layer0)
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
