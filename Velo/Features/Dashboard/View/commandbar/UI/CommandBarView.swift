//
//  CommandBarView.swift
//  Velo
//
//  Dashboard Redesign - Global Command Bar (⌘K)
//  A Raycast-style fuzzy search palette for commands, files, and servers.
//

import SwiftUI

// MARK: - Search Categories
enum SearchCategory: String, CaseIterable {
    case commands = ">"
    case servers = "@"
    case files = "/"
    case ai = "?"
    case all = ""
    
    var icon: String {
        switch self {
        case .commands: return "command"
        case .servers: return "server.rack"
        case .files: return "doc"
        case .ai: return "sparkles"
        case .all: return "magnifyingglass"
        }
    }
    
    var label: String {
        switch self {
        case .commands: return "Commands"
        case .servers: return "Servers"
        case .files: return "Files"
        case .ai: return "Ask AI"
        case .all: return "Everything"
        }
    }
}

// MARK: - Search Item
struct SearchItem: Identifiable, Hashable {
    let id: UUID = UUID()
    let title: String
    let subtitle: String?
    let category: SearchCategory
    let action: () -> Void
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SearchItem, rhs: SearchItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Command Bar View
struct CommandBarView: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool
    
    // Data providers
    let commands: [String]
    let servers: [String]
    let files: [String]
    
    var onRunCommand: (String) -> Void
    var onSelectServer: (String) -> Void
    var onOpenFile: (String) -> Void
    var onAskAI: (String) -> Void
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 0) {
                // Search Header
                searchHeader
                
                Divider()
                    .background(ColorTokens.border)
                
                // Results List
                if items.isEmpty {
                    emptyState
                } else {
                    resultsList
                }
                
                // Footer
                footer
            }
            .frame(width: 600)
            .frame(maxHeight: 450)
            .background(ColorTokens.layer1)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(ColorTokens.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 20)
            .padding(.top, 100) // Position near top
        }
        .onAppear {
            isFocused = true
        }
    }
    
    // MARK: - Components
    
    private var searchHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: activeCategory.icon)
                .font(.system(size: 18))
                .foregroundStyle(ColorTokens.accentPrimary)
            
            TextField("Search or type a command...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($isFocused)
                .onSubmit {
                    if let first = items.first {
                        executeItem(first)
                    }
                }
            
            if !activeCategory.label.isEmpty {
                Text(activeCategory.label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ColorTokens.accentPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ColorTokens.accentPrimary.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Text("⌘K")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(16)
    }
    
    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        SearchResultRow(
                            item: item,
                            isSelected: selectedIndex == index
                        )
                        .onTapGesture {
                            executeItem(item)
                        }
                    }
                }
                .padding(8)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.textTertiary)
            
            Text("No results found for \"\(searchText)\"")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textSecondary)
            
            VStack(alignment: .leading, spacing: 6) {
                categoryHint(prefix: ">", label: "Commands")
                categoryHint(prefix: "@", label: "Servers")
                categoryHint(prefix: "/", label: "Files")
                categoryHint(prefix: "?", label: "Ask AI")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func categoryHint(prefix: String, label: String) -> some View {
        HStack(spacing: 8) {
            Text(prefix)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(ColorTokens.accentPrimary)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }
    
    private var footer: some View {
        HStack {
            HStack(spacing: 12) {
                footerHint(keys: ["↑", "↓"], label: "Navigate")
                footerHint(keys: ["↵"], label: "Apply")
                footerHint(keys: ["Esc"], label: "Close")
            }
            
            Spacer()
            
            Text("Velo Search")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ColorTokens.layer2.opacity(0.5))
    }
    
    private func footerHint(keys: [String], label: String) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(ColorTokens.layer3)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }
    
    // MARK: - Logic
    
    private var activeCategory: SearchCategory {
        for category in SearchCategory.allCases where category != .all {
            if searchText.hasPrefix(category.rawValue) {
                return category
            }
        }
        return .all
    }
    
    private var searchContent: String {
        let prefix = activeCategory.rawValue
        if !prefix.isEmpty && searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        return searchText
    }
    
    private var items: [SearchItem] {
        var filtered: [SearchItem] = []
        let query = searchContent.lowercased()
        
        // Commands
        if activeCategory == .all || activeCategory == .commands {
            let matches = commands.filter { query.isEmpty || $0.lowercased().contains(query) }
            filtered += matches.map { cmd in
                SearchItem(title: cmd, subtitle: "Recent Command", category: .commands) {
                    onRunCommand(cmd)
                }
            }
        }
        
        // Servers
        if activeCategory == .all || activeCategory == .servers {
            let matches = servers.filter { query.isEmpty || $0.lowercased().contains(query) }
            filtered += matches.map { server in
                SearchItem(title: server, subtitle: "SSH Server", category: .servers) {
                    onSelectServer(server)
                }
            }
        }
        
        // Files
        if activeCategory == .all || activeCategory == .files {
            let matches = files.filter { query.isEmpty || $0.lowercased().contains(query) }
            filtered += matches.map { file in
                SearchItem(title: file, subtitle: "Workspace File", category: .files) {
                    onOpenFile(file)
                }
            }
        }
        
        // AI
        if !query.isEmpty && (activeCategory == .all || activeCategory == .ai) {
            filtered.append(SearchItem(title: "Ask AI: \"\(query)\"", subtitle: "AI Intelligence", category: .ai) {
                onAskAI(query)
            })
        }
        
        return filtered
    }
    
    private func executeItem(_ item: SearchItem) {
        item.action()
        isPresented = false
    }
}

// MARK: - Row Components
private struct SearchResultRow: View {
    let item: SearchItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.icon)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? .white : ColorTokens.textTertiary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? .white : ColorTokens.textPrimary)
                
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : ColorTokens.textTertiary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? ColorTokens.accentPrimary : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
    }
}
