//
//  CommandAnalyzer.swift
//  Velo
//
//  AI-Powered Terminal - Pattern Recognition & Analysis
//

import Foundation

// MARK: - Command Analyzer
/// Analyzes command patterns, sequences, and provides insights
final class CommandAnalyzer {
    
    // MARK: - Singleton
    static let shared = CommandAnalyzer()
    
    // MARK: - Common Sequences
    /// Known command sequences (e.g., git add → commit → push)
    private let knownSequences: [[String]] = [
        ["git add", "git commit", "git push"],
        ["git pull", "git checkout"],
        ["npm install", "npm run"],
        ["cd", "ls"],
        ["mkdir", "cd"],
        ["docker build", "docker run"],
        ["pod install", "xcodebuild"],
    ]
    
    // MARK: - Analyze Sequence
    /// Predict next command based on recent sequence
    func predictNextInSequence(after commands: [CommandModel]) -> [PredictionModel] {
        guard !commands.isEmpty else { return [] }
        
        var predictions: [PredictionModel] = []
        let recentCommands = commands.prefix(5).map { normalizeForPattern($0.command) }
        
        for sequence in knownSequences {
            for i in 0..<sequence.count - 1 {
                let pattern = sequence[i]
                if let lastMatch = recentCommands.first(where: { $0.hasPrefix(pattern) }) {
                    let nextCommand = sequence[i + 1]
                    let confidence = 0.7 - Double(i) * 0.1
                    
                    predictions.append(PredictionModel(
                        suggestedCommand: nextCommand,
                        confidence: confidence,
                        reason: "Common follow-up after '\(lastMatch)'",
                        source: .sequential
                    ))
                }
            }
        }
        
        return predictions.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Detect Patterns
    /// Find repeated patterns in command history
    func detectPatterns(in commands: [CommandModel]) -> [CommandPattern] {
        var patterns: [CommandPattern] = []
        let normalizedCommands = commands.map { normalizeForPattern($0.command) }
        
        // Find 2-gram and 3-gram patterns
        for gramSize in 2...3 {
            let grams = findNGrams(normalizedCommands, n: gramSize)
            
            for (gram, count) in grams where count >= 3 {
                patterns.append(CommandPattern(
                    commands: gram,
                    frequency: count,
                    lastUsed: commands.first?.timestamp ?? Date()
                ))
            }
        }
        
        return patterns.sorted { $0.frequency > $1.frequency }
    }
    
    // MARK: - Context Analysis
    /// Analyze what context the user is working in
    func analyzeContext(commands: [CommandModel], workingDirectory: String) -> WorkContext {
        var contextScores: [CommandContext: Int] = [:]
        
        // Score based on recent commands
        for command in commands.prefix(20) {
            contextScores[command.context, default: 0] += 1
        }
        
        // Score based on working directory
        if workingDirectory.contains(".git") {
            contextScores[.git, default: 0] += 5
        }
        if workingDirectory.contains("node_modules") || workingDirectory.contains("package.json") {
            contextScores[.npm, default: 0] += 5
        }
        if workingDirectory.contains(".xcodeproj") || workingDirectory.contains(".xcworkspace") {
            contextScores[.xcode, default: 0] += 5
        }
        
        let dominantContext = contextScores.max(by: { $0.value < $1.value })?.key ?? .general
        
        return WorkContext(
            primary: dominantContext,
            secondary: Array(contextScores.keys.filter { $0 != dominantContext }.prefix(2)),
            workingDirectory: workingDirectory
        )
    }
    
    // MARK: - Generate Explanation
    /// Generate explanation for a command
    func explain(_ command: String) -> CommandExplanation {
        let tokens = tokenize(command)
        var breakdown: [ExplanationPart] = []
        var warnings: [String] = []
        var tips: [String] = []
        
        for token in tokens {
            let (explanation, type) = explainToken(token, inContext: command)
            breakdown.append(ExplanationPart(
                token: token,
                explanation: explanation,
                type: type
            ))
            
            // Add warnings for dangerous commands
            if isDangerous(token) {
                warnings.append("'\(token)' can be destructive - use with caution")
            }
        }
        
        // Add tips
        tips = generateTips(for: command)
        
        let summary = generateSummary(for: command, tokens: tokens)
        
        return CommandExplanation(
            command: command,
            summary: summary,
            breakdown: breakdown,
            relatedCommands: findRelatedCommands(command),
            warnings: warnings,
            tips: tips
        )
    }
    
    // MARK: - Private Helpers
    private func normalizeForPattern(_ command: String) -> String {
        return command.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .first ?? command
    }
    
    private func findNGrams(_ items: [String], n: Int) -> [([String], Int)] {
        var grams: [[String]: Int] = [:]
        
        for i in 0...(items.count - n) {
            let gram = Array(items[i..<i+n])
            grams[gram, default: 0] += 1
        }
        
        return grams.map { ($0.key, $0.value) }
    }
    
    private func tokenize(_ command: String) -> [String] {
        // Simple tokenization - split on spaces but respect quotes
        var tokens: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character = "\""
        
        for char in command {
            if (char == "\"" || char == "'") && !inQuotes {
                inQuotes = true
                quoteChar = char
                current.append(char)
            } else if char == quoteChar && inQuotes {
                inQuotes = false
                current.append(char)
            } else if char == " " && !inQuotes {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        
        if !current.isEmpty {
            tokens.append(current)
        }
        
        return tokens
    }
    
    private func explainToken(_ token: String, inContext command: String) -> (String, TokenType) {
        // Check if it's a known command
        let knownCommands: [String: String] = [
            "git": "Version control system",
            "cd": "Change directory",
            "ls": "List directory contents",
            "rm": "Remove files or directories",
            "cp": "Copy files",
            "mv": "Move or rename files",
            "mkdir": "Create directory",
            "cat": "Display file contents",
            "grep": "Search text patterns",
            "find": "Search for files",
            "chmod": "Change file permissions",
            "sudo": "Execute as superuser",
            "npm": "Node package manager",
            "pip": "Python package manager",
            "docker": "Container platform",
            "curl": "Transfer data from URLs",
            "ssh": "Secure shell connection",
        ]
        
        if let explanation = knownCommands[token] {
            return (explanation, .command)
        }
        
        // Check for flags
        if token.hasPrefix("--") {
            return ("Long flag: \(token.dropFirst(2))", .flag)
        } else if token.hasPrefix("-") && token.count <= 3 {
            return ("Short flag", .flag)
        }
        
        // Check for paths
        if token.contains("/") || token.hasPrefix("~") || token.hasPrefix(".") {
            return ("File or directory path", .path)
        }
        
        // Check for pipes/redirects
        if token == "|" {
            return ("Pipe output to next command", .pipe)
        } else if token == ">" || token == ">>" || token == "<" {
            return ("Redirect output/input", .redirect)
        }
        
        return ("Argument", .argument)
    }
    
    private func isDangerous(_ token: String) -> Bool {
        let dangerousTokens = ["rm", "sudo", "chmod", "chown", "dd", "mkfs", ":(){:|:&};:"]
        return dangerousTokens.contains(token)
    }
    
    private func generateTips(for command: String) -> [String] {
        var tips: [String] = []
        
        if command.contains("rm ") && !command.contains("-i") {
            tips.append("Add -i flag for interactive deletion confirmation")
        }
        
        if command.hasPrefix("git commit") && !command.contains("-m") {
            tips.append("Use -m flag to add commit message inline")
        }
        
        if command.hasPrefix("ls") && !command.contains("-la") {
            tips.append("Try 'ls -la' to see hidden files and details")
        }
        
        return tips
    }
    
    private func generateSummary(for command: String, tokens: [String]) -> String {
        guard let firstToken = tokens.first else { return command }
        
        let summaries: [String: String] = [
            "git": "Git version control operation",
            "cd": "Navigate to a directory",
            "ls": "List files in current directory",
            "rm": "Delete files or directories",
            "mkdir": "Create a new directory",
            "docker": "Docker container operation",
            "npm": "Node.js package operation",
        ]
        
        return summaries[firstToken] ?? "Execute '\(firstToken)' command"
    }
    
    private func findRelatedCommands(_ command: String) -> [String] {
        let related: [String: [String]] = [
            "git add": ["git commit", "git status", "git diff"],
            "git commit": ["git push", "git log"],
            "git push": ["git status", "git pull"],
            "npm install": ["npm run", "npm test"],
            "docker build": ["docker run", "docker images"],
        ]
        
        for (pattern, commands) in related {
            if command.hasPrefix(pattern) {
                return commands
            }
        }
        
        return []
    }
}

// MARK: - Supporting Types
struct CommandPattern: Identifiable {
    let id = UUID()
    let commands: [String]
    let frequency: Int
    let lastUsed: Date
}

struct WorkContext {
    let primary: CommandContext
    let secondary: [CommandContext]
    let workingDirectory: String
}

// MARK: - Prediction Model

struct PredictionModel: Identifiable {
    let id = UUID()
    let suggestedCommand: String
    let confidence: Double
    let reason: String
    let source: PredictionSource
    
    enum PredictionSource {
        case sequential
        case frequency
        case contextual
        case ai
    }
}

// MARK: - Command Explanation Types

struct CommandExplanation {
    let command: String
    let summary: String
    let breakdown: [ExplanationPart]
    let relatedCommands: [String]
    let warnings: [String]
    let tips: [String]
}

struct ExplanationPart: Identifiable {
    let id = UUID()
    let token: String
    let explanation: String
    let type: TokenType
}

enum TokenType {
    case command
    case flag
    case argument
    case path
    case pipe
    case redirect
    case variable
    case string
}

