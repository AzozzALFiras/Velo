//
//  AutocompleteService.swift
//  Velo
//
//  Shell-Aware Autocomplete Service
//  Provides real-time intelligent command and path completions
//

import Foundation
import Combine

// MARK: - Completion Type
enum CompletionType: Equatable {
    case command          // Shell commands (ls, cd, git, etc.)
    case directory        // Directory paths
    case file             // File paths
    case gitBranch        // Git branch names
    case gitCommand       // Git subcommands
    case npmScript        // NPM scripts
    case dockerCommand    // Docker subcommands
    case sshHost          // SSH known hosts
    case environment      // Environment variables
    case history          // From command history
}

// MARK: - Completion Item
struct CompletionItem: Identifiable, Hashable {
    let id = UUID()
    let text: String              // The completion text
    let displayText: String       // What to show in UI
    let type: CompletionType
    let description: String?      // Optional description
    let score: Double             // Ranking score (0-1)
    let insertText: String?       // Text to insert (if different from text)
    let isDirectory: Bool         // For file completions

    init(
        text: String,
        displayText: String? = nil,
        type: CompletionType,
        description: String? = nil,
        score: Double = 0.5,
        insertText: String? = nil,
        isDirectory: Bool = false
    ) {
        self.text = text
        self.displayText = displayText ?? text
        self.type = type
        self.description = description
        self.score = score
        self.insertText = insertText
        self.isDirectory = isDirectory
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(text)
        hasher.combine(type)
    }

    static func == (lhs: CompletionItem, rhs: CompletionItem) -> Bool {
        lhs.text == rhs.text && lhs.type == rhs.type
    }
}

// MARK: - Autocomplete Service
@MainActor
final class AutocompleteService: ObservableObject {

    // MARK: - Published State
    @Published private(set) var completions: [CompletionItem] = []
    @Published private(set) var selectedIndex: Int = 0
    @Published private(set) var isShowingCompletions: Bool = false
    @Published private(set) var inlineSuggestion: String?

    // MARK: - Configuration
    var maxCompletions: Int = 10
    var minInputLength: Int = 1

    // MARK: - Dependencies
    private let historyManager: CommandHistoryManager
    private let fileManager = FileManager.default

    // MARK: - State
    private var currentWorkingDirectory: String = NSHomeDirectory()
    private var remoteItems: [String] = []
    private var isSSHSession: Bool = false
    private var lastInput: String = ""

    // MARK: - Command Database
    private let commonCommands: [String: String] = [
        "ls": "List directory contents",
        "cd": "Change directory",
        "pwd": "Print working directory",
        "mkdir": "Create directory",
        "rm": "Remove files",
        "cp": "Copy files",
        "mv": "Move files",
        "cat": "Concatenate files",
        "grep": "Search text patterns",
        "find": "Find files",
        "chmod": "Change permissions",
        "chown": "Change ownership",
        "ssh": "Secure shell",
        "scp": "Secure copy",
        "curl": "Transfer data",
        "wget": "Download files",
        "tar": "Archive files",
        "zip": "Compress files",
        "unzip": "Decompress files",
        "git": "Version control",
        "npm": "Node package manager",
        "yarn": "Yarn package manager",
        "docker": "Container management",
        "python": "Python interpreter",
        "python3": "Python 3 interpreter",
        "node": "Node.js runtime",
        "vim": "Text editor",
        "nano": "Text editor",
        "less": "View file contents",
        "more": "View file contents",
        "head": "View first lines",
        "tail": "View last lines",
        "echo": "Print text",
        "export": "Set environment variable",
        "source": "Execute script",
        "history": "Command history",
        "clear": "Clear terminal",
        "exit": "Exit shell",
        "sudo": "Execute as superuser",
        "apt": "Package manager (Debian)",
        "brew": "Package manager (macOS)",
        "systemctl": "System service control",
        "service": "Service management",
        "ps": "Process status",
        "top": "Process monitor",
        "htop": "Interactive process viewer",
        "kill": "Terminate process",
        "df": "Disk usage",
        "du": "Directory usage",
        "free": "Memory usage",
        "which": "Locate command",
        "whoami": "Current user",
        "env": "Environment variables",
    ]

    private let gitSubcommands: [String: String] = [
        "status": "Show working tree status",
        "add": "Add file contents to index",
        "commit": "Record changes",
        "push": "Update remote refs",
        "pull": "Fetch and integrate",
        "fetch": "Download objects and refs",
        "branch": "List, create, or delete branches",
        "checkout": "Switch branches",
        "merge": "Join histories",
        "rebase": "Reapply commits",
        "log": "Show commit logs",
        "diff": "Show changes",
        "stash": "Stash changes",
        "clone": "Clone repository",
        "init": "Create repository",
        "remote": "Manage remotes",
        "reset": "Reset current HEAD",
        "revert": "Revert commits",
        "tag": "Create tags",
        "cherry-pick": "Apply commit",
    ]

    private let dockerSubcommands: [String: String] = [
        "run": "Run a container",
        "ps": "List containers",
        "images": "List images",
        "build": "Build image",
        "pull": "Pull image",
        "push": "Push image",
        "exec": "Execute command in container",
        "stop": "Stop container",
        "start": "Start container",
        "rm": "Remove container",
        "rmi": "Remove image",
        "logs": "View logs",
        "compose": "Docker Compose",
        "network": "Manage networks",
        "volume": "Manage volumes",
    ]

    private let npmSubcommands: [String: String] = [
        "install": "Install packages",
        "run": "Run script",
        "start": "Start application",
        "test": "Run tests",
        "build": "Build project",
        "init": "Initialize project",
        "update": "Update packages",
        "uninstall": "Remove packages",
        "list": "List packages",
        "outdated": "Check outdated",
        "audit": "Security audit",
        "publish": "Publish package",
        "cache": "Manage cache",
    ]

    // MARK: - Init
    init(historyManager: CommandHistoryManager) {
        self.historyManager = historyManager
    }

    // MARK: - Update Context
    func updateContext(
        workingDirectory: String,
        remoteItems: [String] = [],
        isSSH: Bool = false
    ) {
        self.currentWorkingDirectory = workingDirectory
        self.remoteItems = remoteItems
        self.isSSHSession = isSSH
    }

    // MARK: - Get Completions
    func getCompletions(for input: String) {
        lastInput = input

        guard input.count >= minInputLength else {
            clearCompletions()
            return
        }

        var allCompletions: [CompletionItem] = []

        // Parse the input to understand context
        let context = parseInputContext(input)

        // Get completions based on context
        switch context {
        case .command(let prefix):
            allCompletions += getCommandCompletions(prefix: prefix)
            allCompletions += getHistoryCompletions(prefix: input)

        case .gitSubcommand(let prefix):
            allCompletions += getGitSubcommandCompletions(prefix: prefix)

        case .dockerSubcommand(let prefix):
            allCompletions += getDockerSubcommandCompletions(prefix: prefix)

        case .npmSubcommand(let prefix):
            allCompletions += getNpmSubcommandCompletions(prefix: prefix)

        case .path(let prefix, let command):
            allCompletions += getPathCompletions(prefix: prefix, command: command)

        case .argument(let command, let prefix):
            allCompletions += getArgumentCompletions(command: command, prefix: prefix)
            allCompletions += getHistoryCompletions(prefix: input)
        }

        // Sort by score and limit
        let sorted = allCompletions
            .sorted { $0.score > $1.score }
            .prefix(maxCompletions)

        completions = Array(sorted)
        selectedIndex = 0
        isShowingCompletions = !completions.isEmpty

        // Set inline suggestion
        if let first = completions.first {
            inlineSuggestion = first.insertText ?? first.text
        } else {
            inlineSuggestion = nil
        }
    }

    // MARK: - Parse Input Context
    private enum InputContext {
        case command(prefix: String)
        case gitSubcommand(prefix: String)
        case dockerSubcommand(prefix: String)
        case npmSubcommand(prefix: String)
        case path(prefix: String, command: String?)
        case argument(command: String, prefix: String)
    }

    private func parseInputContext(_ input: String) -> InputContext {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        guard !parts.isEmpty else {
            return .command(prefix: "")
        }

        let command = parts[0].lowercased()

        // Check if we're completing the command itself (no space yet)
        if parts.count == 1 && !input.hasSuffix(" ") {
            return .command(prefix: parts[0])
        }

        // Get the last part being typed
        let lastPart = parts.last ?? ""
        let isTypingArg = input.hasSuffix(" ") || parts.count > 1

        // Check for special commands with subcommands
        if command == "git" && isTypingArg {
            let subPrefix = parts.count > 1 && !input.hasSuffix(" ") ? parts[1] : ""
            return .gitSubcommand(prefix: subPrefix)
        }

        if command == "docker" && isTypingArg {
            let subPrefix = parts.count > 1 && !input.hasSuffix(" ") ? parts[1] : ""
            return .dockerSubcommand(prefix: subPrefix)
        }

        if (command == "npm" || command == "yarn") && isTypingArg {
            let subPrefix = parts.count > 1 && !input.hasSuffix(" ") ? parts[1] : ""
            return .npmSubcommand(prefix: subPrefix)
        }

        // Check for path completions
        if command == "cd" || command == "ls" || lastPart.hasPrefix("/") ||
           lastPart.hasPrefix("./") || lastPart.hasPrefix("../") || lastPart.hasPrefix("~") {
            let pathPrefix = input.hasSuffix(" ") ? "" : lastPart
            return .path(prefix: pathPrefix, command: command)
        }

        // Default to argument completion
        let argPrefix = input.hasSuffix(" ") ? "" : lastPart
        return .argument(command: command, prefix: argPrefix)
    }

    // MARK: - Command Completions
    private func getCommandCompletions(prefix: String) -> [CompletionItem] {
        let lowercasePrefix = prefix.lowercased()

        return commonCommands.compactMap { (command, description) in
            guard command.hasPrefix(lowercasePrefix) else { return nil }

            let score = calculateScore(
                match: command,
                prefix: lowercasePrefix,
                baseScore: 0.7
            )

            return CompletionItem(
                text: command,
                type: .command,
                description: description,
                score: score
            )
        }
    }

    // MARK: - Git Subcommand Completions
    private func getGitSubcommandCompletions(prefix: String) -> [CompletionItem] {
        let lowercasePrefix = prefix.lowercased()

        return gitSubcommands.compactMap { (subcommand, description) in
            guard lowercasePrefix.isEmpty || subcommand.hasPrefix(lowercasePrefix) else { return nil }

            let score = calculateScore(
                match: subcommand,
                prefix: lowercasePrefix,
                baseScore: 0.8
            )

            return CompletionItem(
                text: "git \(subcommand)",
                displayText: subcommand,
                type: .gitCommand,
                description: description,
                score: score,
                insertText: "git \(subcommand)"
            )
        }
    }

    // MARK: - Docker Subcommand Completions
    private func getDockerSubcommandCompletions(prefix: String) -> [CompletionItem] {
        let lowercasePrefix = prefix.lowercased()

        return dockerSubcommands.compactMap { (subcommand, description) in
            guard lowercasePrefix.isEmpty || subcommand.hasPrefix(lowercasePrefix) else { return nil }

            let score = calculateScore(
                match: subcommand,
                prefix: lowercasePrefix,
                baseScore: 0.8
            )

            return CompletionItem(
                text: "docker \(subcommand)",
                displayText: subcommand,
                type: .dockerCommand,
                description: description,
                score: score,
                insertText: "docker \(subcommand)"
            )
        }
    }

    // MARK: - NPM Subcommand Completions
    private func getNpmSubcommandCompletions(prefix: String) -> [CompletionItem] {
        let lowercasePrefix = prefix.lowercased()

        return npmSubcommands.compactMap { (subcommand, description) in
            guard lowercasePrefix.isEmpty || subcommand.hasPrefix(lowercasePrefix) else { return nil }

            let score = calculateScore(
                match: subcommand,
                prefix: lowercasePrefix,
                baseScore: 0.8
            )

            return CompletionItem(
                text: "npm \(subcommand)",
                displayText: subcommand,
                type: .npmScript,
                description: description,
                score: score,
                insertText: "npm \(subcommand)"
            )
        }
    }

    // MARK: - Path Completions
    private func getPathCompletions(prefix: String, command: String?) -> [CompletionItem] {
        var completions: [CompletionItem] = []

        if isSSHSession {
            // Use remote items for SSH
            completions += getRemotePathCompletions(prefix: prefix, command: command)
        } else {
            // Local path completions
            completions += getLocalPathCompletions(prefix: prefix, command: command)
        }

        return completions
    }

    private func getLocalPathCompletions(prefix: String, command: String?) -> [CompletionItem] {
        var completions: [CompletionItem] = []

        // Determine base directory and search prefix
        let expandedPrefix = (prefix as NSString).expandingTildeInPath
        var searchDir: String
        var searchPrefix: String

        if prefix.isEmpty {
            searchDir = currentWorkingDirectory
            searchPrefix = ""
        } else if expandedPrefix.hasSuffix("/") {
            searchDir = expandedPrefix
            searchPrefix = ""
        } else {
            searchDir = (expandedPrefix as NSString).deletingLastPathComponent
            searchPrefix = (expandedPrefix as NSString).lastPathComponent.lowercased()
            if searchDir.isEmpty {
                searchDir = currentWorkingDirectory
            }
        }

        // List directory contents
        guard let contents = try? fileManager.contentsOfDirectory(atPath: searchDir) else {
            return completions
        }

        // Filter based on command context (cd only shows directories)
        let cdOnly = command == "cd"

        for item in contents {
            let lowercaseItem = item.lowercased()

            // Check prefix match
            guard searchPrefix.isEmpty || lowercaseItem.hasPrefix(searchPrefix) else { continue }

            let fullPath = (searchDir as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: fullPath, isDirectory: &isDir)

            // For cd, only show directories
            if cdOnly && !isDir.boolValue { continue }

            // Skip hidden files unless prefix starts with .
            if item.hasPrefix(".") && !searchPrefix.hasPrefix(".") { continue }

            let score = calculateScore(
                match: item,
                prefix: searchPrefix,
                baseScore: 0.75
            )

            // Build the completion text
            let displayItem = isDir.boolValue ? "\(item)/" : item
            var insertPath: String

            if prefix.isEmpty {
                insertPath = displayItem
            } else if prefix.hasPrefix("/") || prefix.hasPrefix("~") {
                insertPath = (searchDir as NSString).appendingPathComponent(displayItem)
                if prefix.hasPrefix("~") {
                    let home = NSHomeDirectory()
                    insertPath = insertPath.replacingOccurrences(of: home, with: "~")
                }
            } else if prefix.hasPrefix("./") {
                insertPath = "./\((searchDir as NSString).appendingPathComponent(displayItem).replacingOccurrences(of: currentWorkingDirectory + "/", with: ""))"
            } else {
                insertPath = displayItem
            }

            completions.append(CompletionItem(
                text: displayItem,
                displayText: displayItem,
                type: isDir.boolValue ? .directory : .file,
                description: isDir.boolValue ? "Directory" : "File",
                score: score,
                insertText: insertPath,
                isDirectory: isDir.boolValue
            ))
        }

        return completions.sorted { $0.score > $1.score }
    }

    private func getRemotePathCompletions(prefix: String, command: String?) -> [CompletionItem] {
        let lowercasePrefix = prefix.lowercased()
        let cdOnly = command == "cd"

        return remoteItems.compactMap { item in
            let lowercaseItem = item.lowercased()
            guard lowercasePrefix.isEmpty || lowercaseItem.hasPrefix(lowercasePrefix) else { return nil }

            let isDir = item.hasSuffix("/")
            if cdOnly && !isDir { return nil }

            let score = calculateScore(
                match: item,
                prefix: lowercasePrefix,
                baseScore: 0.7
            )

            return CompletionItem(
                text: item,
                type: isDir ? .directory : .file,
                description: isDir ? "Directory" : "File",
                score: score,
                isDirectory: isDir
            )
        }
    }

    // MARK: - Argument Completions
    private func getArgumentCompletions(command: String, prefix: String) -> [CompletionItem] {
        // Could be expanded with command-specific argument completions
        return []
    }

    // MARK: - History Completions
    private func getHistoryCompletions(prefix: String) -> [CompletionItem] {
        let lowercasePrefix = prefix.lowercased()

        // Get frequency map from history manager
        let commands = historyManager.recentCommands

        var seen = Set<String>()
        var completions: [CompletionItem] = []

        for cmd in commands {
            let command = cmd.command
            guard !seen.contains(command),
                  command.lowercased().hasPrefix(lowercasePrefix) else { continue }

            seen.insert(command)

            // Calculate score based on frequency and recency
            let frequencyScore = Double(cmd.frequency) / 100.0
            let recencyScore = 1.0 - (Date().timeIntervalSince(cmd.timestamp) / (7 * 24 * 60 * 60))
            let matchScore = calculateScore(match: command, prefix: lowercasePrefix, baseScore: 0.5)

            let score = min(1.0, matchScore + (frequencyScore * 0.2) + max(0, recencyScore * 0.1))

            completions.append(CompletionItem(
                text: command,
                type: .history,
                description: "History",
                score: score,
                insertText: command
            ))
        }

        return completions
    }

    // MARK: - Score Calculation
    private func calculateScore(match: String, prefix: String, baseScore: Double) -> Double {
        guard !prefix.isEmpty else { return baseScore }

        // Exact match gets highest score
        if match.lowercased() == prefix.lowercased() {
            return 1.0
        }

        // Prefix match score based on length ratio
        let prefixRatio = Double(prefix.count) / Double(match.count)

        return baseScore + (prefixRatio * 0.2)
    }

    // MARK: - Selection Navigation
    func selectNext() {
        guard !completions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % completions.count

        // Update inline suggestion
        inlineSuggestion = completions[selectedIndex].insertText ?? completions[selectedIndex].text
    }

    func selectPrevious() {
        guard !completions.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : completions.count - 1

        // Update inline suggestion
        inlineSuggestion = completions[selectedIndex].insertText ?? completions[selectedIndex].text
    }

    // MARK: - Accept Completion
    func acceptSelected() -> CompletionItem? {
        guard !completions.isEmpty, selectedIndex < completions.count else { return nil }
        let item = completions[selectedIndex]
        clearCompletions()
        return item
    }

    func acceptInline() -> String? {
        let suggestion = inlineSuggestion
        clearCompletions()
        return suggestion
    }

    // MARK: - Clear
    func clearCompletions() {
        completions = []
        selectedIndex = 0
        isShowingCompletions = false
        inlineSuggestion = nil
    }
}
