//
//  CommandShortcuts.swift
//  Velo
//
//  Dashboard Redesign - Command Shortcuts/Aliases
//  Manage favorite commands with custom shortcuts
//

import SwiftUI

// MARK: - Command Shortcut Model

/// A saved command shortcut/alias
struct CommandShortcut: Identifiable, Codable, Hashable {
    let id: UUID
    var shortcut: String      // e.g., "pas"
    var command: String       // e.g., "php artisan serve"
    var description: String   // e.g., "Start Laravel dev server"
    var icon: String          // SF Symbol name
    var color: String         // Hex color
    var category: String      // e.g., "Laravel", "Git", "Docker"
    
    init(
        id: UUID = UUID(),
        shortcut: String,
        command: String,
        description: String = "",
        icon: String = "terminal",
        color: String = "#00D9FF",
        category: String = "General"
    ) {
        self.id = id
        self.shortcut = shortcut
        self.command = command
        self.description = description
        self.icon = icon
        self.color = color
        self.category = category
    }
    
    var displayColor: Color {
        Color(hex: color) ?? ColorTokens.accentPrimary
    }
}

// MARK: - Shortcuts Manager

/// Manages command shortcuts persistence and lookup
@Observable
final class CommandShortcutsManager {
    
    var shortcuts: [CommandShortcut] = []
    
    private let userDefaultsKey = "velo_command_shortcuts"
    
    init() {
        loadShortcuts()
        
        // Add default shortcuts if empty
        if shortcuts.isEmpty {
            addDefaultShortcuts()
        }
    }
    
    // MARK: - CRUD
    
    func addShortcut(_ shortcut: CommandShortcut) {
        shortcuts.append(shortcut)
        saveShortcuts()
    }
    
    func updateShortcut(_ shortcut: CommandShortcut) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index] = shortcut
            saveShortcuts()
        }
    }
    
    func deleteShortcut(_ shortcut: CommandShortcut) {
        shortcuts.removeAll { $0.id == shortcut.id }
        saveShortcuts()
    }
    
    func deleteShortcut(at indexSet: IndexSet) {
        shortcuts.remove(atOffsets: indexSet)
        saveShortcuts()
    }
    
    // MARK: - Lookup
    
    /// Find command for a given shortcut
    func expandShortcut(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        return shortcuts.first { $0.shortcut.lowercased() == trimmed.lowercased() }?.command
    }
    
    /// Check if input starts with a known shortcut
    func hasShortcut(for input: String) -> CommandShortcut? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        return shortcuts.first { $0.shortcut.lowercased() == trimmed.lowercased() }
    }
    
    /// Get shortcuts by category
    func shortcuts(for category: String) -> [CommandShortcut] {
        shortcuts.filter { $0.category == category }
    }
    
    /// Get all categories
    var categories: [String] {
        Array(Set(shortcuts.map { $0.category })).sorted()
    }
    
    // MARK: - Persistence
    
    private func saveShortcuts() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func loadShortcuts() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([CommandShortcut].self, from: data) {
            shortcuts = decoded
        }
    }
    
    // MARK: - Defaults
    
    private func addDefaultShortcuts() {
        shortcuts = [
            // Laravel
            CommandShortcut(
                shortcut: "pas",
                command: "php artisan serve",
                description: "Start Laravel development server",
                icon: "play.fill",
                color: "#FF2D20",
                category: "Laravel"
            ),
            CommandShortcut(
                shortcut: "pam",
                command: "php artisan migrate",
                description: "Run database migrations",
                icon: "cylinder.split.1x2.fill",
                color: "#FF2D20",
                category: "Laravel"
            ),
            CommandShortcut(
                shortcut: "pamf",
                command: "php artisan migrate:fresh --seed",
                description: "Fresh migration with seeding",
                icon: "arrow.counterclockwise",
                color: "#FF2D20",
                category: "Laravel"
            ),
            
            // Git
            CommandShortcut(
                shortcut: "gs",
                command: "git status",
                description: "Show git status",
                icon: "arrow.triangle.branch",
                color: "#F05032",
                category: "Git"
            ),
            CommandShortcut(
                shortcut: "gp",
                command: "git pull",
                description: "Pull from remote",
                icon: "arrow.down.doc",
                color: "#F05032",
                category: "Git"
            ),
            CommandShortcut(
                shortcut: "gpu",
                command: "git push",
                description: "Push to remote",
                icon: "arrow.up.doc",
                color: "#F05032",
                category: "Git"
            ),
            
            // npm
            CommandShortcut(
                shortcut: "nrd",
                command: "npm run dev",
                description: "Start npm development",
                icon: "shippingbox.fill",
                color: "#CB3837",
                category: "npm"
            ),
            CommandShortcut(
                shortcut: "nrb",
                command: "npm run build",
                description: "Build for production",
                icon: "hammer.fill",
                color: "#CB3837",
                category: "npm"
            ),
            
            // Docker
            CommandShortcut(
                shortcut: "dcu",
                command: "docker-compose up -d",
                description: "Start Docker containers",
                icon: "shippingbox",
                color: "#2496ED",
                category: "Docker"
            ),
            CommandShortcut(
                shortcut: "dcd",
                command: "docker-compose down",
                description: "Stop Docker containers",
                icon: "stop.fill",
                color: "#2496ED",
                category: "Docker"
            ),
        ]
        saveShortcuts()
    }
}

// MARK: - Shortcuts Panel View

/// Panel showing available shortcuts
struct ShortcutsPanel: View {
    
    let manager: CommandShortcutsManager
    var onRunShortcut: ((CommandShortcut) -> Void)?
    var onAddShortcut: (() -> Void)?
    
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var showAddSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Close")
                
                Text("Command Shortcuts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Spacer()
                
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.accentPrimary)
                }
                .buttonStyle(.plain)
                .help("Add New Shortcut")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            
            Divider()
                .background(ColorTokens.border)
            
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                
                TextField("Search shortcuts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ColorTokens.layer2)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            
            Divider()
                .background(ColorTokens.borderSubtle)
            
            // Categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    CategoryPill(name: "All", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    
                    ForEach(manager.categories, id: \.self) { category in
                        CategoryPill(name: category, isSelected: selectedCategory == category) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            // Shortcuts list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredShortcuts) { shortcut in
                        ShortcutRow(shortcut: shortcut) {
                            onRunShortcut?(shortcut)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .background(ColorTokens.layer1)
        .sheet(isPresented: $showAddSheet) {
            AddShortcutSheet(manager: manager)
        }
    }
    
    private var filteredShortcuts: [CommandShortcut] {
        var result = manager.shortcuts
        
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.shortcut.localizedCaseInsensitiveContains(searchText) ||
                $0.command.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
}

// MARK: - Category Pill

private struct CategoryPill: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isSelected ? ColorTokens.textPrimary : ColorTokens.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? ColorTokens.accentPrimary.opacity(0.15) : ColorTokens.layer2)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shortcut Row

private struct ShortcutRow: View {
    let shortcut: CommandShortcut
    let onRun: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onRun) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: shortcut.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(shortcut.displayColor)
                    .frame(width: 24, height: 24)
                    .background(shortcut.displayColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        // Shortcut badge
                        Text(shortcut.shortcut)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(shortcut.displayColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(shortcut.displayColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        // Command
                        Text(shortcut.command)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(ColorTokens.textSecondary)
                            .lineLimit(1)
                    }
                    
                    if !shortcut.description.isEmpty {
                        Text(shortcut.description)
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Run indicator
                if isHovered {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(ColorTokens.success)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isHovered ? ColorTokens.layer2 : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Add Shortcut Sheet

struct AddShortcutSheet: View {
    let manager: CommandShortcutsManager
    @Environment(\.dismiss) var dismiss
    
    @State private var shortcut = ""
    @State private var command = ""
    @State private var description = ""
    @State private var category = "General"
    @State private var selectedIcon = "terminal"
    @State private var selectedColor = "#00D9FF"
    
    let icons = ["terminal", "play.fill", "stop.fill", "arrow.clockwise", "bolt.fill", "hammer.fill", "shippingbox.fill", "cylinder.split.1x2.fill", "network", "server.rack"]
    let colors = ["#00D9FF", "#FF2D20", "#F05032", "#CB3837", "#2496ED", "#4F5D95", "#8CC84B", "#61DAFB", "#F7DF1E"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add New Shortcut")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(20)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Shortcut & Command
                    VStack(alignment: .leading, spacing: 12) {
                        FieldGroup(title: "Alias / Shortcut", icon: "bolt.fill") {
                            TextField("e.g. pas", text: $shortcut)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                        }
                        
                        FieldGroup(title: "Command", icon: "terminal.fill") {
                            TextField("e.g. php artisan serve", text: $command)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                        }
                        
                        FieldGroup(title: "Description (Optional)", icon: "text.alignleft") {
                            TextField("What does it do?", text: $description)
                                .textFieldStyle(.plain)
                        }
                    }
                    
                    // Category
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ColorTokens.textTertiary)
                        
                        TextField("General", text: $category)
                            .padding(8)
                            .background(ColorTokens.layer2)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .textFieldStyle(.plain)
                    }
                    
                    // Visuals
                    HStack(spacing: 30) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icon")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(ColorTokens.textTertiary)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 30))], spacing: 8) {
                                ForEach(icons, id: \.self) { icon in
                                    Image(systemName: icon)
                                        .font(.system(size: 14))
                                        .frame(width: 30, height: 30)
                                        .background(selectedIcon == icon ? ColorTokens.accentPrimary.opacity(0.2) : ColorTokens.layer2)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .onTapGesture { selectedIcon = icon }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(ColorTokens.textTertiary)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 20))], spacing: 8) {
                                ForEach(colors, id: \.self) { color in
                                    Circle()
                                        .fill(Color(hex: color) ?? .blue)
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(ColorTokens.textPrimary, lineWidth: selectedColor == color ? 2 : 0)
                                        )
                                        .onTapGesture { selectedColor = color }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button {
                    let newShortcut = CommandShortcut(
                        shortcut: shortcut,
                        command: command,
                        description: description,
                        icon: selectedIcon,
                        color: selectedColor,
                        category: category
                    )
                    manager.addShortcut(newShortcut)
                    dismiss()
                } label: {
                    Text("Save Shortcut")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(shortcut.isEmpty || command.isEmpty ? ColorTokens.textTertiary : ColorTokens.accentPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(shortcut.isEmpty || command.isEmpty)
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .frame(width: 450, height: 600)
        .background(ColorTokens.layer1)
    }
}

private struct FieldGroup<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(ColorTokens.textTertiary)
            .padding(.leading, 4)
            
            content()
                .padding(10)
                .background(ColorTokens.layer1)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Preview

#Preview {
    ShortcutsPanel(manager: CommandShortcutsManager())
        .frame(width: 320, height: 500)
}
