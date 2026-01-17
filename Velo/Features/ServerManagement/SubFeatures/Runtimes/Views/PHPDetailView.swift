//
//  PHPDetailView.swift
//  Velo
//
//  Full Navigation View for detailed PHP management.
//  Provides comprehensive control over PHP service, extensions, configuration, and versions.
//

import SwiftUI

struct PHPDetailView: View {
    
    @StateObject private var viewModel: PHPDetailViewModel
    var onDismiss: (() -> Void)?
    
    init(session: TerminalViewModel?, onDismiss: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: PHPDetailViewModel(session: session))
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebarView
            
            // Main Content
            mainContentView
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        .task {
            await viewModel.loadData()
        }
        .onChange(of: viewModel.selectedSection) { _ in
            Task {
                await viewModel.loadSectionData()
            }
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // PHP Icon
                if let iconURL = viewModel.capabilityIcon, let url = URL(string: iconURL) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .foregroundStyle(.purple)
                        }
                    }
                    .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 24))
                        .foregroundStyle(.purple)
                        .frame(width: 32, height: 32)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("PHP \(viewModel.activeVersion)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isRunning ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(viewModel.isRunning ? "Running" : "Stopped")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                
                Spacer()
                
                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.black.opacity(0.3))
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Navigation Items
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(PHPDetailSection.allCases) { section in
                        sidebarButton(for: section)
                    }
                }
                .padding(12)
            }
            
            Spacer()
            
            // Version Switcher
            versionSwitcherView
        }
        .frame(width: 220)
        .background(Color.black.opacity(0.4))
    }
    
    private func sidebarButton(for section: PHPDetailSection) -> some View {
        Button {
            viewModel.selectedSection = section
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(viewModel.selectedSection == section ? .white : .gray)
                    .frame(width: 20)
                
                Text(section.rawValue)
                    .font(.system(size: 13, weight: viewModel.selectedSection == section ? .semibold : .regular))
                    .foregroundStyle(viewModel.selectedSection == section ? .white : .gray)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                viewModel.selectedSection == section
                    ? Color.purple.opacity(0.3)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private var versionSwitcherView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Installed Versions")
                .font(.caption)
                .foregroundStyle(.gray)
            
            ForEach(viewModel.installedVersions, id: \.self) { version in
                HStack {
                    Text("PHP \(version)")
                        .font(.system(size: 12, weight: version == viewModel.activeVersion ? .bold : .regular))
                        .foregroundStyle(version == viewModel.activeVersion ? .green : .white)
                    
                    Spacer()
                    
                    if version == viewModel.activeVersion {
                        Text("Active")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    } else {
                        Button("Switch") {
                            Task {
                                await viewModel.switchVersion(to: version)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - Main Content
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Content Header
            HStack {
                Text(viewModel.selectedSection.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if viewModel.isLoading || viewModel.isPerformingAction {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }
            }
            .padding(24)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Section Content
            ScrollView {
                ZStack {
                    Group {
                        switch viewModel.selectedSection {
                        case .service:
                            serviceSection
                        case .extensions:
                            extensionsSection
                        case .disabledFunctions:
                            disabledFunctionsSection
                        case .configuration:
                            configurationSection
                        case .uploadLimits:
                            uploadLimitsSection
                        case .timeouts:
                            timeoutsSection
                        case .configFile:
                            configFileSection
                        case .fpmProfile:
                            fpmProfileSection
                        case .logs:
                            logsSection
                        case .phpinfo:
                            phpInfoSection
                        }
                    }
                    
                    // Show installation status overlay (non-blocking)
                    if viewModel.isInstallingVersion && viewModel.selectedSection != .service {
                        VStack(alignment: .leading) {
                            Spacer()
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Installing PHP \(viewModel.installingVersionName)...")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.orange)
                                    Text(viewModel.installStatus)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.gray)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.black.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                }
                .padding(24)
            }
            
            // Feedback Messages
            if let error = viewModel.errorMessage {
                feedbackBanner(message: error, isError: true)
            }
            
            if let success = viewModel.successMessage {
                feedbackBanner(message: success, isError: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Service Section
    
    private var serviceSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Status Card
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Status")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(viewModel.isRunning ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                            .shadow(color: viewModel.isRunning ? .green : .red, radius: 4)
                        
                        Text(viewModel.isRunning ? "Running" : "Stopped")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 12) {
                    if viewModel.isRunning {
                        actionButton(title: "Stop", icon: "stop.fill", color: .red) {
                            await viewModel.stopService()
                        }
                    } else {
                        actionButton(title: "Start", icon: "play.fill", color: .green) {
                            await viewModel.startService()
                        }
                    }
                    
                    actionButton(title: "Restart", icon: "arrow.clockwise", color: .orange) {
                        await viewModel.restartService()
                    }
                    
                    actionButton(title: "Reload", icon: "arrow.triangle.2.circlepath", color: .blue) {
                        await viewModel.reloadService()
                    }
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            
            // Info Cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                infoCard(title: "Version", value: viewModel.activeVersion, icon: "number")
                infoCard(title: "Binary Path", value: viewModel.binaryPath, icon: "terminal")
                infoCard(title: "Config Path", value: viewModel.configPath, icon: "doc.text")
                infoCard(title: "Installed Versions", value: "\(viewModel.installedVersions.count)", icon: "square.stack.3d.up")
            }
            
            // Installed Versions Section
            if !viewModel.installedVersions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Installed Versions")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    ForEach(viewModel.installedVersions, id: \.self) { version in
                        installedVersionRow(version: version)
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Available Versions from API
            if !viewModel.availableVersionsFromAPI.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Available Versions")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text("from API")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    
                    ForEach(viewModel.availableVersionsFromAPI) { version in
                        availableVersionRow(version: version)
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private func installedVersionRow(version: String) -> some View {
        HStack {
            Circle()
                .fill(version == viewModel.activeVersion ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
            
            Text("PHP \(version)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            
            if version == viewModel.activeVersion {
                Text("Active")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            }
            
            Spacer()
            
            if version != viewModel.activeVersion {
                Button {
                    Task {
                        await viewModel.setAsDefaultVersion(version)
                    }
                } label: {
                    Text("Set as Default")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.6))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isPerformingAction)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func availableVersionRow(version: CapabilityVersion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("PHP \(version.version)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    
                    Text(version.stability)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(stabilityColor(version.stability).opacity(0.2))
                        .foregroundStyle(stabilityColor(version.stability))
                        .clipShape(Capsule())
                    
                    if version.isDefault {
                        Text("Recommended")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
                
                if let eolDate = version.eolDate {
                    Text("EOL: \(eolDate)")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
            
            Spacer()
            
            let isInstalled = viewModel.installedVersions.contains(version.version)
            let isInstalling = viewModel.isInstallingVersion && viewModel.installingVersionName == version.version
            
            if isInstalled {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Installed")
                        .font(.caption)
                }
                .foregroundStyle(.green)
            } else if isInstalling {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text(viewModel.installStatus.isEmpty ? "Installing..." : viewModel.installStatus)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Text("This may take several minutes")
                        .font(.system(size: 9))
                        .foregroundStyle(.gray)
                }
            } else if viewModel.isInstallingVersion {
                // Another version is being installed
                Text("Please wait...")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.6))
            } else {
                Button {
                    Task {
                        await viewModel.installVersion(version)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 10))
                        Text("Install")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.8))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isInstallingVersion)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func stabilityColor(_ stability: String) -> Color {
        switch stability.lowercased() {
        case "stable": return .green
        case "security": return .blue
        case "beta": return .orange
        case "eol": return .red
        default: return .gray
        }
    }
    
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () async -> Void) -> some View {
        Button {
            Task {
                await action()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isPerformingAction)
    }
    
    private func infoCard(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.purple)
                .frame(width: 36, height: 36)
                .background(Color.purple.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.gray)
                
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    // MARK: - Extensions Section
    
    @State private var showInstallExtensionSheet = false
    @State private var extensionToInstall = ""
    
    private var extensionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(viewModel.extensions.count) extensions loaded")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                
                Spacer()
                
                Button {
                    showInstallExtensionSheet = true
                    Task {
                        await viewModel.loadAvailableExtensions()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Install Extension")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            
            if viewModel.isLoadingExtensions {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.extensions) { ext in
                        extensionCard(ext)
                    }
                }
            }
        }
        .sheet(isPresented: $showInstallExtensionSheet) {
            installExtensionSheet
        }
    }
    
    private var installExtensionSheet: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Install PHP Extension")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    showInstallExtensionSheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
            }
            
            TextField("Extension name (e.g., redis, imagick)", text: $extensionToInstall)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white)
            
            Text("Available: bcmath, gd, imagick, redis, memcached, mongodb, intl, soap, zip...")
                .font(.caption)
                .foregroundStyle(.gray)
            
            if viewModel.isInstallingExtension {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Installing...")
                        .foregroundStyle(.gray)
                }
            }
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    showInstallExtensionSheet = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.gray)
                
                Button {
                    Task {
                        let success = await viewModel.installExtension(extensionToInstall)
                        if success {
                            extensionToInstall = ""
                            showInstallExtensionSheet = false
                        }
                    }
                } label: {
                    Text("Install")
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(extensionToInstall.isEmpty || viewModel.isInstallingExtension)
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
    }
    
    private func extensionCard(_ ext: PHPExtension) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ext.isCore ? "cube.fill" : "puzzlepiece.extension.fill")
                .font(.system(size: 14))
                .foregroundStyle(ext.isCore ? .blue : .green)
            
            Text(ext.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Spacer()
            
            if ext.isCore {
                Text("Core")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    // MARK: - Disabled Functions Section
    
    private var disabledFunctionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(viewModel.disabledFunctions.count) functions disabled")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                
                Spacer()
                
                Text("Click function to enable it")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.8))
            }
            
            if viewModel.isLoadingDisabledFunctions {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if viewModel.disabledFunctions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("No disabled functions")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("All PHP functions are enabled")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.disabledFunctions, id: \.self) { func_name in
                        Button {
                            Task {
                                _ = await viewModel.removeDisabledFunction(func_name)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                                
                                Text(func_name)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.gray)
                            }
                            .padding(10)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isPerformingAction)
                    }
                }
            }
        }
    }

    
    // MARK: - Configuration Section
    
    @State private var editingConfigKey: String? = nil
    @State private var editingConfigValue: String = ""
    
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PHP Configuration")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                
                Spacer()
                
                Text("Click value to edit")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.8))
            }
            
            if viewModel.isLoadingConfig {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(viewModel.configValues) { config in
                    editableConfigRow(config)
                }
            }
        }
    }
    
    private func editableConfigRow(_ config: PHPConfigValue) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(config.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                
                Text(config.description)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            if editingConfigKey == config.key {
                // Editing mode
                HStack(spacing: 8) {
                    TextField("Value", text: $editingConfigValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(width: 120)
                        .background(Color.purple.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.purple, lineWidth: 1)
                        )
                    
                    Button {
                        Task {
                            _ = await viewModel.updateConfigValue(config.key, to: editingConfigValue)
                            editingConfigKey = nil
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isPerformingAction)
                    
                    Button {
                        editingConfigKey = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Display mode - clickable to edit
                Button {
                    editingConfigKey = config.key
                    editingConfigValue = config.value
                } label: {
                    HStack(spacing: 6) {
                        Text(config.value)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.purple)
                        
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(.purple.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    
    // MARK: - Upload Limits Section
    
    private var uploadLimitsSection: some View {
        let uploadConfigs = viewModel.configValues.filter { config in
            ["upload_max_filesize", "post_max_size", "max_file_uploads"].contains(config.key)
        }
        
        return VStack(alignment: .leading, spacing: 16) {
            if uploadConfigs.isEmpty && !viewModel.isLoadingConfig {
                Text("No upload limit configurations found.")
                    .foregroundStyle(.gray)
            } else {
                ForEach(uploadConfigs) { config in
                    editableConfigRow(config)
                }
            }
        }
    }
    
    // MARK: - Timeouts Section
    
    private var timeoutsSection: some View {
        let timeoutConfigs = viewModel.configValues.filter { config in
            ["max_execution_time", "max_input_time"].contains(config.key)
        }
        
        return VStack(alignment: .leading, spacing: 16) {
            if timeoutConfigs.isEmpty && !viewModel.isLoadingConfig {
                Text("No timeout configurations found.")
                    .foregroundStyle(.gray)
            } else {
                ForEach(timeoutConfigs) { config in
                    editableConfigRow(config)
                }
            }
        }
    }
    
    // MARK: - Config File Section
    
    @State private var showConfigEditor = false
    @State private var editableConfigContent = ""
    @State private var showingFullFile = false
    
    private var configFileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.configPath)
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    if !viewModel.configFileContent.isEmpty {
                        let lineCount = viewModel.configFileContent.components(separatedBy: "\n").count
                        HStack(spacing: 8) {
                            Text("\(lineCount) active directives")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            
                            if !showingFullFile {
                                Text("(comments hidden)")
                                    .font(.caption2)
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Toggle full file
                    Button {
                        Task {
                            showingFullFile.toggle()
                            if showingFullFile {
                                await viewModel.loadFullConfigFile()
                            } else {
                                await viewModel.loadConfigFile()
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showingFullFile ? "eye.slash" : "eye")
                            Text(showingFullFile ? "Hide Comments" : "Show Full")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    
                    if !viewModel.configFileContent.isEmpty {
                        Button {
                            editableConfigContent = viewModel.configFileContent
                            showConfigEditor = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil.and.outline")
                                Text("Edit")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            if viewModel.isLoadingConfigFile {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(showingFullFile ? "Loading full config file..." : "Loading active directives...")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 60)
            } else if viewModel.configFileContent.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray.opacity(0.5))
                    Text("No active configuration found.")
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 60)
            } else {
                // Use ScrollView + Text for the filtered content (now small enough)
                ScrollView {
                    Text(viewModel.configFileContent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.9))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(height: 400)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .sheet(isPresented: $showConfigEditor) {
            configEditorSheet
        }
    }

    
    private var configEditorSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Edit php.ini")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(viewModel.configPath)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showConfigEditor = false
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.gray)
                    
                    Button {
                        Task {
                            viewModel.configFileContent = editableConfigContent
                            let success = await viewModel.saveConfigFile()
                            if success {
                                showConfigEditor = false
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isSavingConfigFile {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text("Save & Reload")
                        }
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSavingConfigFile)
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            
            // Editor - Using native NSTextView for high-performance editing
            NativeEditableTextView(text: $editableConfigContent)
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(red: 0.08, green: 0.08, blue: 0.1))
    }

    
    // MARK: - FPM Profile Section
    
    private var fpmProfileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PHP-FPM Instances")
                .font(.subheadline)
                .foregroundStyle(.gray)
            
            if viewModel.isLoadingFPM {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if viewModel.fpmStatus.isEmpty {
                Text("No PHP-FPM instances found.")
                    .foregroundStyle(.gray)
            } else {
                ForEach(Array(viewModel.fpmStatus.keys.sorted()), id: \.self) { serviceName in
                    let isActive = viewModel.fpmStatus[serviceName] ?? false
                    
                    HStack {
                        Circle()
                            .fill(isActive ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        
                        Text(serviceName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text(isActive ? "Running" : "Stopped")
                            .font(.caption)
                            .foregroundStyle(isActive ? .green : .red)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    // MARK: - Logs Section
    
    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PHP Error Logs")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                
                Spacer()
                
                Button {
                    Task {
                        await viewModel.loadSectionData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            
            if viewModel.isLoadingLogs {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    Text(viewModel.logContent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(minHeight: 300)
            }
        }
    }
    
    // MARK: - PHP Info Section
    
    private var phpInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if viewModel.isLoadingPHPInfo {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading PHP Information...")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 60)
            } else if viewModel.phpInfoData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray.opacity(0.5))
                    Text("No PHP information available.")
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 60)
            } else {
                // System Info Card
                phpInfoCard(title: "System Information", icon: "desktopcomputer", items: [
                    ("PHP Version", viewModel.phpInfoData["PHP Version"] ?? viewModel.activeVersion),
                    ("System", viewModel.phpInfoData["System"] ?? "Unknown"),
                    ("Server API", viewModel.phpInfoData["Server API"] ?? "CLI"),
                    ("PHP API", viewModel.phpInfoData["PHP API"] ?? "-"),
                ])
                
                // Build Info Card
                phpInfoCard(title: "Build Information", icon: "hammer", items: [
                    ("Build Date", viewModel.phpInfoData["Build Date"] ?? "-"),
                    ("Build System", viewModel.phpInfoData["Build System"] ?? "-"),
                    ("Build Provider", viewModel.phpInfoData["Build Provider"] ?? "-"),
                    ("Configure Command", viewModel.phpInfoData["Configure Command"]?.prefix(50).description ?? "-"),
                ])
                
                // Configuration Card
                phpInfoCard(title: "Configuration Paths", icon: "folder", items: [
                    ("Configuration File (php.ini) Path", viewModel.phpInfoData["Configuration File (php.ini) Path"] ?? "-"),
                    ("Loaded Configuration File", viewModel.phpInfoData["Loaded Configuration File"] ?? viewModel.configPath),
                    ("Scan this dir for .ini files", viewModel.phpInfoData["Scan this dir for additional .ini files"] ?? "-"),
                ])
                
                // Virtual Directory Support
                phpInfoCard(title: "Features", icon: "checkmark.seal", items: [
                    ("Virtual Directory Support", viewModel.phpInfoData["Virtual Directory Support"] ?? "disabled"),
                    ("Zend Memory Manager", viewModel.phpInfoData["Zend Memory Manager"] ?? "enabled"),
                    ("Thread Safety", viewModel.phpInfoData["Thread Safety"] ?? "-"),
                    ("Debug Build", viewModel.phpInfoData["Debug Build"] ?? "no"),
                ])
                
                // Show Raw Output Toggle
                DisclosureGroup("Raw Output") {
                    ScrollView {
                        Text(viewModel.phpInfoHTML)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 200)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
            }
        }
    }
    
    private func phpInfoCard(title: String, icon: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            // Items
            VStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    HStack(alignment: .top) {
                        Text(item.0)
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)
                            .frame(width: 180, alignment: .leading)
                        
                        Text(item.1)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .textSelection(.enabled)
                        
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Feedback Banner
    
    private func feedbackBanner(message: String, isError: Bool) -> some View {
        HStack {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? .red : .green)
            
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.white)
            
            Spacer()
            
            Button {
                if isError {
                    viewModel.errorMessage = nil
                } else {
                    viewModel.successMessage = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(isError ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
