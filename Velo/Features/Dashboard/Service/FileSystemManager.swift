//
//  FileSystemManager.swift
//  Velo
//
//  Dashboard - File System Navigation & Management
//

import Foundation
import SwiftUI
import Combine

/// Types of files recognized by the dashboard explorer
public enum IntelligenceFileType: String, Codable {
    case file, folder, image, video
}

/// Represents a file or folder in the dashboard explorer
struct FileItem: Identifiable, Hashable {
    let id: String // Absolute path
    let name: String
    let path: String
    let isDirectory: Bool
    let type: IntelligenceFileType
    var isExpanded: Bool = false
    var children: [FileItem]? = nil
    
    var size: Int64?
    var modificationDate: Date?
    
    // For hashable/equatable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class FileExplorerManager: ObservableObject {
    @Published var rootItems: [FileItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let fileManager = FileManager.default
    
    /// Load files for a specific directory
    func loadDirectory(_ path: String, into item: FileItem? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let urls = try fileManager.contentsOfDirectory(at: URL(fileURLWithPath: path),
                                                           includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                                                           options: [.skipsHiddenFiles])
            
            let loadedItems = urls.map { url -> FileItem in
                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                let isDir = resourceValues?.isDirectory ?? false
                let name = url.lastPathComponent
                let fullPath = url.path
                
                return FileItem(
                    id: fullPath,
                    name: name,
                    path: fullPath,
                    isDirectory: isDir,
                    type: isDir ? .folder : detectType(from: name),
                    children: isDir ? [] : nil,
                    size: Int64(resourceValues?.fileSize ?? 0),
                    modificationDate: resourceValues?.contentModificationDate
                )
            }.sorted { (a, b) in
                if a.isDirectory != b.isDirectory {
                    return a.isDirectory // Folders first
                }
                return a.name.lowercased() < b.name.lowercased()
            }
            
            if let targetItem = item {
                // Update children of an existing item
                if let index = findItemIndex(path: targetItem.path) {
                    // Update the tree
                    updateChildren(at: index, with: loadedItems)
                }
            } else {
                rootItems = loadedItems
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func findItemIndex(path: String, in items: [FileItem]? = nil) -> [Int]? {
        let list = items ?? rootItems
        for (index, item) in list.enumerated() {
            if item.path == path {
                return [index]
            }
            if let children = item.children, let subIndex = findItemIndex(path: path, in: children) {
                return [index] + subIndex
            }
        }
        return nil
    }
    
    private func updateChildren(at index: [Int], with newChildren: [FileItem]) {
        // Implementation for updating nested item children
        // For simplicity in SwiftUI, it's often better to use a flat structure or nested Observables
        // But for this use case, we'll update the rootItems tree
        rootItems = updatedTree(items: rootItems, at: index, with: newChildren)
    }
    
    private func updatedTree(items: [FileItem], at index: [Int], with newChildren: [FileItem]) -> [FileItem] {
        var copy = items
        guard !index.isEmpty else { return items }
        
        let first = index[0]
        if index.count == 1 {
            var item = copy[first]
            item.children = newChildren
            copy[first] = item
        } else {
            var item = copy[first]
            if let children = item.children {
                item.children = updatedTree(items: children, at: Array(index.dropFirst()), with: newChildren)
                copy[first] = item
            }
        }
        return copy
    }
    
    func toggleExpansion(path: String) {
        rootItems = toggledTree(items: rootItems, path: path)
    }
    
    private func toggledTree(items: [FileItem], path: String) -> [FileItem] {
        var copy = items
        for i in 0..<copy.count {
            if copy[i].path == path {
                copy[i].isExpanded.toggle()
                // If it was expanded, load children if empty
                if copy[i].isExpanded && (copy[i].children == nil || copy[i].children!.isEmpty) {
                    let taskPath = path
                    let taskItem = copy[i]
                    Task {
                        await loadDirectory(taskPath, into: taskItem)
                    }
                }
                return copy
            }
            if let children = copy[i].children {
                let updatedChildren = toggledTree(items: children, path: path)
                if updatedChildren != children {
                    copy[i].children = updatedChildren
                    return copy
                }
            }
        }
        return copy
    }
    
    private func detectType(from filename: String) -> IntelligenceFileType {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "svg": return .image
        case "mp4", "mov", "avi": return .video
        case "swift", "py", "js", "ts", "php", "html", "css", "json", "md": return .file
        default: return .file
        }
    }
    
    // Actions
    func rename(item: FileItem, to newName: String) {
        let newPath = (item.path as NSString).deletingLastPathComponent + "/" + newName
        do {
            try fileManager.moveItem(atPath: item.path, toPath: newPath)
            // Reload parent or update tree
            // To keep it simple, we reload root for now or the parent if we tracked it
            // For now let's just refresh everything or update the item in place
            refreshTree()
        } catch {
            errorMessage = "Rename failed: \(error.localizedDescription)"
        }
    }
    
    func refreshTree() {
        // Ideally reload what's expanded, but for now just reload root
        // This is a placeholder for better sync logic
    }
}
