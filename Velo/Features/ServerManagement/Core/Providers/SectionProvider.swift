//
//  SectionProvider.swift
//  Velo
//
//  Protocol for section data providers in the unified architecture.
//

import Foundation

/// Protocol for providing data loading for application sections
protocol SectionProvider {
    /// The type of section this provider handles
    static var providerType: SectionProviderType { get }

    /// Load data for the section
    /// - Parameters:
    ///   - app: The application definition
    ///   - state: The shared application state to populate
    ///   - session: The terminal session for SSH commands
    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws
}

/// Type-erased wrapper for section providers
struct AnySectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .service }

    private let _loadData: (ApplicationDefinition, ApplicationState, TerminalViewModel) async throws -> Void
    private let _providerType: SectionProviderType

    init<P: SectionProvider>(_ provider: P) {
        self._loadData = provider.loadData
        self._providerType = P.providerType
    }

    var providerType: SectionProviderType { _providerType }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        try await _loadData(app, state, session)
    }
}

/// Errors that can occur during section data loading
enum SectionProviderError: LocalizedError {
    case sessionNotAvailable
    case serviceNotFound(String)
    case loadFailed(String)
    case notSupported(SectionProviderType)

    var errorDescription: String? {
        switch self {
        case .sessionNotAvailable:
            return "SSH session is not available"
        case .serviceNotFound(let id):
            return "Service not found for application: \(id)"
        case .loadFailed(let reason):
            return "Failed to load section data: \(reason)"
        case .notSupported(let type):
            return "Section type '\(type.rawValue)' is not supported for this application"
        }
    }
}
