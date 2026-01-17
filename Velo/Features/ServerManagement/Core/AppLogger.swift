//
//  AppLogger.swift
//  Velo
//
//  Simple logger for internal application activity.
//  Outputs strictly to the Xcode console for developer monitoring.
//

import Foundation

final class AppLogger {
    static let shared = AppLogger()
    
    private init() {}
    
    /// Log a message to the Xcode console
    func log(_ message: String, level: LogLevel = .info) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        
        let prefix: String
        switch level {
        case .info: prefix = "ℹ️ [INFO]"
        case .warning: prefix = "⚠️ [WARN]"
        case .error: prefix = "❌ [ERROR]"
        case .cmd: prefix = "🚀 [SSH_CMD]"
        case .result: prefix = "✅ [RESULT]"
        }
        
        // Final combined print for Xcode Console
        print("\(prefix) [\(timestamp)] \(message)")
    }
    
    enum LogLevel {
        case info
        case warning
        case error
        case cmd
        case result
    }
}
