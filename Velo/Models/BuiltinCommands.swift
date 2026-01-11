//
//  BuiltinCommands.swift
//  Velo
//
//  Created by Velo AI
//

import Foundation

// MARK: - Builtin Commands Database
/// Common commands for contextual suggestions
struct BuiltinCommands {
    static let git = [
        "git status",
        "git add .",
        "git commit -m \"\"",
        "git push",
        "git pull",
        "git checkout",
        "git branch",
        "git log --oneline -10",
        "git diff",
        "git stash",
    ]
    
    static let npm = [
        "npm install",
        "npm run dev",
        "npm run build",
        "npm test",
        "npm start",
        "npm update",
    ]
    
    static let docker = [
        "docker ps",
        "docker images",
        "docker build -t",
        "docker run",
        "docker-compose up",
        "docker-compose down",
    ]
    
    static let filesystem = [
        "ls -la",
        "cd ..",
        "pwd",
        "mkdir",
        "touch",
        "cat",
        "less",
    ]
}
