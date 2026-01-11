//
//  DirectoryBadge.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

// MARK: - Directory Badge
struct DirectoryBadge: View {
    let path: String
    let onNavigate: (String) -> Void
    
    @State private var showingPicker = false
    @State private var isHovered = false
    
    var displayPath: String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
    
    var directoryName: String {
        let name = (displayPath as NSString).lastPathComponent
        return name.isEmpty ? "~" : name
    }
    
    var body: some View {
        Button {
            showingPicker.toggle()
        } label: {
            HStack(spacing: VeloDesign.Spacing.xs) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                Text(directoryName)
                    .font(VeloDesign.Typography.monoSmall)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .opacity(isHovered ? 1 : 0.5)
            }
            .foregroundColor(VeloDesign.Colors.neonCyan)
            .padding(.horizontal, VeloDesign.Spacing.sm)
            .padding(.vertical, VeloDesign.Spacing.xs)
            .background(
                Capsule()
                    .fill(VeloDesign.Colors.neonCyan.opacity(isHovered ? 0.2 : 0.1))
            )
            .overlay(
                Capsule()
                    .stroke(VeloDesign.Colors.neonCyan.opacity(isHovered ? 0.4 : 0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Click to navigate • \(displayPath)")
        .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
            DirectoryPickerPopover(
                currentPath: path,
                onSelect: { selectedPath in
                    showingPicker = false
                    onNavigate(selectedPath)
                }
            )
        }
    }
}

// MARK: - Directory Picker Popover
struct DirectoryPickerPopover: View {
    let currentPath: String
    let onSelect: (String) -> Void
    
    @State private var navigationPath: [String] = []
    @State private var folderContents: [DirectoryItem] = []
    
    var browsePath: String {
        navigationPath.last ?? "quick"
    }
    
    var isShowingQuickAccess: Bool {
        navigationPath.isEmpty
    }
    
    var displayBrowsePath: String {
        let home = NSHomeDirectory()
        if browsePath.hasPrefix(home) {
            return "~" + browsePath.dropFirst(home.count)
        }
        return browsePath
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with back button
            HStack {
                if !isShowingQuickAccess {
                    Button {
                        withAnimation(VeloDesign.Animation.quick) {
                            _ = navigationPath.popLast()
                            if let newPath = navigationPath.last {
                                loadContents(of: newPath)
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(VeloDesign.Colors.neonCyan)
                    }
                    .buttonStyle(.plain)
                }
                
                Text(isShowingQuickAccess ? "Quick Navigation" : displayBrowsePath)
                    .font(VeloDesign.Typography.caption)
                    .foregroundColor(VeloDesign.Colors.textMuted)
                    .lineLimit(1)
                
                Spacer()
                
                if !isShowingQuickAccess {
                    // Select current folder button
                    Button {
                        onSelect(browsePath)
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                            Text("Select")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(VeloDesign.Colors.neonGreen)
                        .padding(.horizontal, VeloDesign.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(VeloDesign.Colors.neonGreen.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, VeloDesign.Spacing.md)
            .padding(.top, VeloDesign.Spacing.md)
            .padding(.bottom, VeloDesign.Spacing.sm)
            
            Divider()
                .background(VeloDesign.Colors.glassBorder)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isShowingQuickAccess {
                        // Quick access locations
                        QuickAccessRow(name: "Home", icon: "house.fill", color: VeloDesign.Colors.neonCyan) {
                            drillInto(NSHomeDirectory())
                        }
                        QuickAccessRow(name: "Desktop", icon: "menubar.dock.rectangle", color: VeloDesign.Colors.info) {
                            drillInto(NSHomeDirectory() + "/Desktop")
                        }
                        QuickAccessRow(name: "Documents", icon: "doc.fill", color: VeloDesign.Colors.neonPurple) {
                            drillInto(NSHomeDirectory() + "/Documents")
                        }
                        QuickAccessRow(name: "Downloads", icon: "arrow.down.circle.fill", color: VeloDesign.Colors.neonGreen) {
                            drillInto(NSHomeDirectory() + "/Downloads")
                        }
                        QuickAccessRow(name: "Applications", icon: "app.fill", color: VeloDesign.Colors.warning) {
                            drillInto("/Applications")
                        }
                        QuickAccessRow(name: "Developer", icon: "hammer.fill", color: VeloDesign.Colors.error) {
                            drillInto(NSHomeDirectory() + "/Developer")
                        }
                        
                        Divider()
                            .background(VeloDesign.Colors.glassBorder)
                            .padding(.vertical, VeloDesign.Spacing.xs)
                        
                        // Current folder shortcut
                        QuickAccessRow(name: "Current: \((currentPath as NSString).lastPathComponent)", icon: "folder.fill", color: VeloDesign.Colors.textSecondary) {
                            drillInto(currentPath)
                        }
                    } else {
                        // Folder contents
                        if folderContents.isEmpty {
                            Text("Empty folder")
                                .font(VeloDesign.Typography.caption)
                                .foregroundColor(VeloDesign.Colors.textMuted)
                                .frame(maxWidth: .infinity)
                                .padding(VeloDesign.Spacing.lg)
                        } else {
                            ForEach(folderContents) { item in
                                BrowsableDirectoryRow(item: item) {
                                    drillInto(item.path)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, VeloDesign.Spacing.xs)
            }
            .frame(maxHeight: 350)
        }
        .frame(width: 260)
        .background(VeloDesign.Colors.darkSurface)
    }
    
    private func drillInto(_ path: String) {
        withAnimation(VeloDesign.Animation.quick) {
            navigationPath.append(path)
            loadContents(of: path)
        }
    }
    
    private func loadContents(of path: String) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            folderContents = contents
                .filter { !$0.hasPrefix(".") }
                .compactMap { name -> DirectoryItem? in
                    let fullPath = (path as NSString).appendingPathComponent(name)
                    var isDir: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir),
                          isDir.boolValue else { return nil }
                    return DirectoryItem(name: name, path: fullPath, icon: "folder.fill", color: VeloDesign.Colors.textSecondary)
                }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
        } catch {
            folderContents = []
        }
    }
}

// MARK: - Quick Access Row
struct QuickAccessRow: View {
    let name: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: VeloDesign.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                    .frame(width: 18)
                
                Text(name)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(VeloDesign.Colors.textMuted)
            }
            .padding(.horizontal, VeloDesign.Spacing.md)
            .padding(.vertical, VeloDesign.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VeloDesign.Radius.small)
                    .fill(isHovered ? VeloDesign.Colors.elevatedSurface : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Browsable Directory Row
struct BrowsableDirectoryRow: View {
    let item: DirectoryItem
    let onDrillDown: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onDrillDown) {
            HStack(spacing: VeloDesign.Spacing.sm) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundColor(VeloDesign.Colors.neonCyan.opacity(0.7))
                    .frame(width: 18)
                
                Text(item.name)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(VeloDesign.Colors.textMuted)
            }
            .padding(.horizontal, VeloDesign.Spacing.md)
            .padding(.vertical, VeloDesign.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VeloDesign.Radius.small)
                    .fill(isHovered ? VeloDesign.Colors.elevatedSurface : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Directory Item
struct DirectoryItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: String
    let color: Color
}

// MARK: - Directory Row
struct DirectoryRow: View {
    let item: DirectoryItem
    let onSelect: (String) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button {
            onSelect(item.path)
        } label: {
            HStack(spacing: VeloDesign.Spacing.sm) {
                Image(systemName: item.icon)
                    .font(.system(size: 12))
                    .foregroundColor(item.color)
                    .frame(width: 18)
                
                Text(item.name)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                
                Spacer()
                
                if isHovered {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(VeloDesign.Colors.textMuted)
                }
            }
            .padding(.horizontal, VeloDesign.Spacing.md)
            .padding(.vertical, VeloDesign.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VeloDesign.Radius.small)
                    .fill(isHovered ? VeloDesign.Colors.elevatedSurface : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
