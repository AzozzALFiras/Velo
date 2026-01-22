//
//  SecurityManager.swift
//  Velo
//
//  Shared security and authentication manager.
//

import Foundation
import LocalAuthentication

@MainActor
final class SecurityManager {
    
    static let shared = SecurityManager()
    
    private let authContext = LAContext()
    
    private init() {}
    
    /// Performs an action securely by requiring biometric or device password authentication.
    /// - Parameters:
    ///   - reason: The reason displayed to the user for the authentication prompt.
    ///   - action: The closure to execute upon successful authentication.
    ///   - onError: Optional closure to handle authentication failures.
    func securelyPerformAction(
        reason: String,
        action: @escaping () -> Void,
        onError: ((String) -> Void)? = nil
    ) {
        var error: NSError?
        
        // Check if biometric or device password authentication is available
        if authContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            authContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                Task { @MainActor in
                    if success {
                        action()
                    } else if let laError = authError as? LAError, laError.code != .userCancel {
                        onError?(laError.localizedDescription)
                    }
                }
            }
        } else {
            // Fallback: If no authentication is set up on the device,
            // we proceed with the action but it's recommended to log this or handle it.
            // In a production app, you might want to require a password if biometrics aren't available.
            action()
        }
    }
}
