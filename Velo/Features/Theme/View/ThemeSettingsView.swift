//
//  ThemeSettingsView.swift
//  Velo
//
//  Theme customization UI
//  NOTE: SectionHeader is defined in Settings/Components/SectionHeader.swift
//

import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingCustomThemeEditor = false
    @State private var editingTheme: VeloTheme?
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.lg) {
            // Built-in Themes
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                SectionHeader(title: "Built-in Themes")
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: VeloDesign.Spacing.md) {
                    ForEach(VeloTheme.allBuiltInThemes) { theme in
                        ThemePreviewCard(
                            theme: theme,
                            isSelected: themeManager.currentTheme.id == theme.id,
                            onSelect: { themeManager.setTheme(theme) }
                        )
                    }
                }
            }
            
            // Custom Themes
            if !themeManager.customThemes.isEmpty {
                VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                    HStack {
                        SectionHeader(title: "Custom Themes")
                        Spacer()
                        Button(action: { showingCustomThemeEditor = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(VeloDesign.Colors.neonCyan)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: VeloDesign.Spacing.md) {
                        ForEach(themeManager.customThemes) { theme in
                            ThemePreviewCard(
                                theme: theme,
                                isSelected: themeManager.currentTheme.id == theme.id,
                                onSelect: { themeManager.setTheme(theme) },
                                onEdit: { editingTheme = theme },
                                onDelete: { themeManager.deleteCustomTheme(theme) }
                            )
                        }
                    }
                }
            } else {
                Button(action: { showingCustomThemeEditor = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Custom Theme")
                    }
                    .font(VeloDesign.Typography.subheadline)
                    .foregroundColor(VeloDesign.Colors.neonCyan)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(VeloDesign.Colors.neonCyan.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(VeloDesign.Colors.neonCyan.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingCustomThemeEditor) {
            CustomThemeEditorView(theme: nil)
        }
        .sheet(item: $editingTheme) { theme in
            CustomThemeEditorView(theme: theme)
        }
    }
}

// MARK: - Theme Preview Card
struct ThemePreviewCard: View {
    let theme: VeloTheme
    let isSelected: Bool
    var onSelect: () -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preview
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(theme.colorScheme.color(for: \.neonCyan))
                            .frame(width: 12, height: 12)
                        Circle()
                            .fill(theme.colorScheme.color(for: \.neonPurple))
                            .frame(width: 12, height: 12)
                        Circle()
                            .fill(theme.colorScheme.color(for: \.neonGreen))
                            .frame(width: 12, height: 12)
                        Spacer()
                    }
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.colorScheme.color(for: \.cardBackground))
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(theme.colorScheme.glassBorder(), lineWidth: 1)
                        )
                }
                .padding(8)
                .background(theme.colorScheme.color(for: \.darkSurface))
                .cornerRadius(8)
                
                // Edit/Delete buttons for custom themes
                if !theme.isBuiltIn && (onEdit != nil || onDelete != nil) {
                    HStack(spacing: 4) {
                        if let onEdit = onEdit {
                            Button(action: onEdit) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(VeloDesign.Colors.neonCyan)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if let onDelete = onDelete {
                            Button(action: onDelete) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(VeloDesign.Colors.error)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .opacity(isHovered ? 1 : 0)
                }
            }
            
            // Theme name
            Text(theme.name)
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.textPrimary)
                .lineLimit(1)
        }
        .padding(8)
        .background(isSelected ? VeloDesign.Colors.neonCyan.opacity(0.1) : Color.clear)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? VeloDesign.Colors.neonCyan : VeloDesign.Colors.glassBorder, lineWidth: isSelected ? 2 : 1)
        )
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onSelect)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - Custom Theme Editor
struct CustomThemeEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var themeName: String
    @State private var colorScheme: VeloTheme.ColorScheme
    @State private var fontScheme: VeloTheme.FontScheme
    
    private let isEditing: Bool
    private let themeId: UUID?
    
    init(theme: VeloTheme?) {
        if let theme = theme {
            self.isEditing = true
            self.themeId = theme.id
            _themeName = State(initialValue: theme.name)
            _colorScheme = State(initialValue: theme.colorScheme)
            _fontScheme = State(initialValue: theme.fontScheme)
        } else {
            self.isEditing = false
            self.themeId = nil
            _themeName = State(initialValue: "My Custom Theme")
            // Use Neon Dark as the default base theme
            _colorScheme = State(initialValue: VeloTheme.neonDark.colorScheme)
            _fontScheme = State(initialValue: VeloTheme.neonDark.fontScheme)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Theme" : "Create Theme")
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(VeloDesign.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(VeloDesign.Colors.darkSurface)
            
            ScrollView {
                VStack(alignment: .leading, spacing: VeloDesign.Spacing.lg) {
                    // Theme Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Theme Name")
                            .font(VeloDesign.Typography.caption)
                            .foregroundColor(VeloDesign.Colors.textSecondary)
                        
                        TextField("Enter theme name", text: $themeName)
                            .textFieldStyle(.plain)
                            .font(VeloDesign.Typography.monoFont)
                            .padding(10)
                            .background(VeloDesign.Colors.cardBackground)
                            .cornerRadius(6)
                    }
                    
                    // Color Scheme
                    ColorSchemeEditor(colorScheme: $colorScheme)
                    
                    // Font Scheme
                    FontSchemeEditor(fontScheme: $fontScheme)
                }
                .padding()
            }
            
            // Actions
            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(VeloDesign.Typography.subheadline)
                        .foregroundColor(VeloDesign.Colors.textSecondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: saveTheme) {
                    Text(isEditing ? "Save" : "Create")
                        .font(VeloDesign.Typography.subheadline)
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(VeloDesign.Colors.neonCyan)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(themeName.isEmpty)
            }
            .padding()
            .background(VeloDesign.Colors.darkSurface)
        }
        .frame(width: 600, height: 700)
        .background(VeloDesign.Colors.deepSpace)
    }
    
    private func saveTheme() {
        if isEditing, let id = themeId {
            // Update existing theme
            let updatedTheme = VeloTheme(
                id: id,
                name: themeName,
                isBuiltIn: false,
                colorScheme: colorScheme,
                fontScheme: fontScheme
            )
            themeManager.updateCustomTheme(updatedTheme)
            themeManager.setTheme(updatedTheme)
        } else {
            // Create new theme
            let newTheme = VeloTheme(
                name: themeName,
                isBuiltIn: false,
                colorScheme: colorScheme,
                fontScheme: fontScheme
            )
            // Use the manager's method to properly add and persist
            let created = themeManager.createCustomTheme(name: themeName, basedOn: nil)
            // Now update it with our custom values
            let updated = VeloTheme(
                id: created.id,
                name: themeName,
                isBuiltIn: false,
                colorScheme: colorScheme,
                fontScheme: fontScheme
            )
            themeManager.updateCustomTheme(updated)
            themeManager.setTheme(updated)
        }
        
        dismiss()
    }
}

// MARK: - Color Scheme Editor
struct ColorSchemeEditor: View {
    @Binding var colorScheme: VeloTheme.ColorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
            Text("Colors")
                .font(VeloDesign.Typography.headline)
                .foregroundColor(VeloDesign.Colors.textPrimary)
            
            VStack(spacing: VeloDesign.Spacing.sm) {
                ColorPickerRow(title: "Neon Cyan", hex: $colorScheme.neonCyan)
                ColorPickerRow(title: "Neon Purple", hex: $colorScheme.neonPurple)
                ColorPickerRow(title: "Neon Green", hex: $colorScheme.neonGreen)
                
                Divider().background(VeloDesign.Colors.glassBorder)
                
                ColorPickerRow(title: "Deep Space", hex: $colorScheme.deepSpace)
                ColorPickerRow(title: "Dark Surface", hex: $colorScheme.darkSurface)
                ColorPickerRow(title: "Card Background", hex: $colorScheme.cardBackground)
                ColorPickerRow(title: "Elevated Surface", hex: $colorScheme.elevatedSurface)
                
                Divider().background(VeloDesign.Colors.glassBorder)
                
                ColorPickerRow(title: "Text Primary", hex: $colorScheme.textPrimary)
                ColorPickerRow(title: "Text Secondary", hex: $colorScheme.textSecondary)
                ColorPickerRow(title: "Text Muted", hex: $colorScheme.textMuted)
                
                Divider().background(VeloDesign.Colors.glassBorder)
                
                ColorPickerRow(title: "Success", hex: $colorScheme.success)
                ColorPickerRow(title: "Warning", hex: $colorScheme.warning)
                ColorPickerRow(title: "Error", hex: $colorScheme.error)
                ColorPickerRow(title: "Info", hex: $colorScheme.info)
            }
        }
    }
}

// MARK: - Font Scheme Editor
struct FontSchemeEditor: View {
    @Binding var fontScheme: VeloTheme.FontScheme
    
    let availableFonts = [
        "System Monospaced",
        "Menlo",
        "Monaco",
        "SF Mono",
        "Courier New"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
            Text("Fonts")
                .font(VeloDesign.Typography.headline)
                .foregroundColor(VeloDesign.Colors.textPrimary)
            
            VStack(spacing: VeloDesign.Spacing.sm) {
                // Mono Font
                HStack {
                    Text("Monospace Font")
                        .font(VeloDesign.Typography.caption)
                        .foregroundColor(VeloDesign.Colors.textSecondary)
                    Spacer()
                    Picker("", selection: $fontScheme.monoFontName) {
                        ForEach(availableFonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
                
                HStack {
                    Text("Mono Font Size")
                        .font(VeloDesign.Typography.caption)
                        .foregroundColor(VeloDesign.Colors.textSecondary)
                    Spacer()
                    Slider(value: $fontScheme.monoFontSize, in: 10...18, step: 1)
                        .frame(width: 150)
                    Text("\(Int(fontScheme.monoFontSize))pt")
                        .font(VeloDesign.Typography.monoSmall)
                        .foregroundColor(VeloDesign.Colors.textMuted)
                        .frame(width: 40, alignment: .trailing)
                }
                
                Divider().background(VeloDesign.Colors.glassBorder)
                
                // Headline Font
                HStack {
                    Text("Headline Font")
                        .font(VeloDesign.Typography.caption)
                        .foregroundColor(VeloDesign.Colors.textSecondary)
                    Spacer()
                    Picker("", selection: $fontScheme.headlineFontName) {
                        Text("System Rounded").tag("System Rounded")
                        Text("System Default").tag("System Default")
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
                
                HStack {
                    Text("Headline Size")
                        .font(VeloDesign.Typography.caption)
                        .foregroundColor(VeloDesign.Colors.textSecondary)
                    Spacer()
                    Slider(value: $fontScheme.headlineFontSize, in: 14...24, step: 1)
                        .frame(width: 150)
                    Text("\(Int(fontScheme.headlineFontSize))pt")
                        .font(VeloDesign.Typography.monoSmall)
                        .foregroundColor(VeloDesign.Colors.textMuted)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Color Picker Row
struct ColorPickerRow: View {
    let title: String
    @Binding var hex: String
    
    var color: Color {
        Color(hex: hex)
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.textSecondary)
            
            Spacer()
            
            ColorPicker("", selection: Binding(
                get: { color },
                set: { newColor in
                    if let components = NSColor(newColor).cgColor.components {
                        let r = Int(components[0] * 255)
                        let g = Int(components[1] * 255)
                        let b = Int(components[2] * 255)
                        hex = String(format: "%02X%02X%02X", r, g, b)
                    }
                }
            ))
            .labelsHidden()
            
            TextField("", text: $hex)
                .font(VeloDesign.Typography.monoSmall)
                .frame(width: 80)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(VeloDesign.Colors.cardBackground)
                .cornerRadius(4)
        }
    }
}
