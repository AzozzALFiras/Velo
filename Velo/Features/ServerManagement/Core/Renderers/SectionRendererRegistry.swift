//
//  SectionRendererRegistry.swift
//  Velo
//
//  Registry for mapping section types to their view renderers.
//

import SwiftUI

/// Registry that provides views for rendering different section types
@MainActor
final class SectionRendererRegistry {
    static let shared = SectionRendererRegistry()

    private init() {}

    /// Get the appropriate view for a section type
    @ViewBuilder
    func view(
        for section: SectionDefinition,
        app: ApplicationDefinition,
        state: ApplicationState,
        viewModel: ApplicationDetailViewModel
    ) -> some View {
        switch section.providerType {
        case .service:
            UnifiedServiceSectionView(app: app, state: state, viewModel: viewModel)
        case .versions:
            UnifiedVersionsSectionView(app: app, state: state, viewModel: viewModel)
        case .configuration:
            UnifiedConfigurationSectionView(app: app, state: state, viewModel: viewModel)
        case .configFile:
            UnifiedConfigFileSectionView(app: app, state: state, viewModel: viewModel)
        case .logs:
            UnifiedLogsSectionView(app: app, state: state, viewModel: viewModel)
        case .status:
            UnifiedStatusSectionView(app: app, state: state, viewModel: viewModel)
        case .modules:
            UnifiedModulesSectionView(app: app, state: state, viewModel: viewModel)
        case .security:
            UnifiedSecuritySectionView(app: app, state: state, viewModel: viewModel)
        case .sites:
            UnifiedSitesSectionView(app: app, state: state, viewModel: viewModel)
        case .extensions:
            UnifiedExtensionsSectionView(app: app, state: state, viewModel: viewModel)
        case .disabledFunctions:
            UnifiedDisabledFunctionsSectionView(app: app, state: state, viewModel: viewModel)
        case .fpmProfile:
            UnifiedFPMProfileSectionView(app: app, state: state, viewModel: viewModel)
        case .phpinfo:
            UnifiedPHPInfoSectionView(app: app, state: state, viewModel: viewModel)
        case .uploadLimits, .timeouts:
            UnifiedConfigurationSectionView(app: app, state: state, viewModel: viewModel)
        case .databases:
            UnifiedDatabasesSectionView(app: app, state: state, viewModel: viewModel)
        case .users:
            UnifiedUsersSectionView(app: app, state: state, viewModel: viewModel)
        case .backup:
            UnifiedBackupSectionView(app: app, state: state, viewModel: viewModel)
        }
    }
}
