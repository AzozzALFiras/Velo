//
//  SSHCommandResult.swift
//  Velo
//
//  Result of an SSH command execution.
//

import Foundation

public struct SSHCommandResult: Codable {
    public let command: String
    public let output: String
    public let exitCode: Int
    public let executionTime: TimeInterval
    
    public init(command: String, output: String, exitCode: Int, executionTime: TimeInterval) {
        self.command = command
        self.output = output
        self.exitCode = exitCode
        self.executionTime = executionTime
    }
}
