//
//  ApplicationsManagementView.swift
//  Velo
//
//  Created for Velo Server Management
//

import SwiftUI

struct ApplicationsManagementView: View {
    @ObservedObject var viewModel: ServerManagementViewModel
    @State private var selectedCapability: Capability?
    @State private var showPHPDetail = false
    @State private var showNginxDetail = false
    @State private var showPythonDetail = false
    @State private var showNodeDetail = false
    @State private var showApacheDetail = false
    
    /// Slugs of installed software (lowercased for matching)
    private var installedSlugs: Set<String> {
        Set(viewModel.installedSoftware.map { $0.name.lowercased() })
    }
    
    /// Filter capabilities to show only those NOT installed
    private var availableToInstall: [Capability] {
        viewModel.filteredCapabilities.filter { cap in
            !installedSlugs.contains(cap.slug.lowercased()) &&
            !installedSlugs.contains(cap.name.lowercased())
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                
                // MARK: - Search & Header
                VStack(alignment: .leading, spacing: 16) {
                    Text("apps.title".localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.gray)
                        TextField("Search applications...", text: $viewModel.searchQuery)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                // MARK: - Installed Applications
                if !viewModel.installedSoftware.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("apps.installed".localized)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            
                            Text("\(viewModel.installedSoftware.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                                .foregroundStyle(.white)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(viewModel.installedSoftware) { software in
                                    InstalledAppCard(software: software)
                                        .onTapGesture {
                                            handleInstalledSoftwareTap(software)
                                        }
                                }
                            }
                        }
                    }
                }
                
                // MARK: - Available to Install
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("apps.available".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        
                        Text("\(availableToInstall.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if availableToInstall.isEmpty {
                        Text("apps.all_installed".localized)
                            .foregroundStyle(.gray)
                            .padding(.horizontal)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                            ForEach(availableToInstall) { cap in
                                CapabilityCard(capability: cap)
                                    .onTapGesture {
                                        selectedCapability = cap
                                    }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 24) // Added extra horizontal padding to prevent sidebar overlap
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea())
        .sheet(item: $selectedCapability) { cap in
            CapabilityDetailView(viewModel: viewModel, capability: cap)
        }
        .overlay {
            if showPHPDetail {
                PHPDetailView(session: viewModel.session, onDismiss: {
                    showPHPDetail = false
                })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(100)
            }
            
            if showNginxDetail {
                NginxDetailView(session: viewModel.session, onDismiss: {
                    showNginxDetail = false
                })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(100)
            }
            
            if showPythonDetail {
                PythonDetailView(session: viewModel.session)
                    .overlay(alignment: .topTrailing) {
                        Button { showPythonDetail = false } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.gray)
                                .padding()
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(100)
            }
            
            if showNodeDetail {
                NodeDetailView(session: viewModel.session)
                    .overlay(alignment: .topTrailing) {
                        Button { showNodeDetail = false } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.gray)
                                .padding()
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(100)
            }
            
            if showApacheDetail {
                ApacheDetailView(session: viewModel.session, onDismiss: {
                    showApacheDetail = false
                })
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showPHPDetail)
        .animation(.easeInOut(duration: 0.25), value: showNginxDetail)
        .animation(.easeInOut(duration: 0.25), value: showPythonDetail)
        .animation(.easeInOut(duration: 0.25), value: showNodeDetail)
        .animation(.easeInOut(duration: 0.25), value: showApacheDetail)
        .overlay(alignment: .bottomTrailing) {
            if viewModel.showInstallOverlay {
                InstallationStatusOverlay(viewModel: viewModel)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }

    }
    
    // MARK: - Helpers
    
    private func handleInstalledSoftwareTap(_ software: InstalledSoftware) {
        switch software.name.lowercased() {
        case "php":
            showPHPDetail = true
        case "nginx":
            showNginxDetail = true
        case "python":
            showPythonDetail = true
        case "node", "nodejs":
            showNodeDetail = true
        case "apache", "apache2":
            showApacheDetail = true
        // Future: Add cases for mysql, python, etc.
        default:
            break
        }
    }
}


// MARK: - Subviews

struct InstalledAppCard: View {
    let software: InstalledSoftware
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AsyncImage(url: URL(string: "https://velo.3zozz.com/assets/icons/\(software.name.lowercased()).png")) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "cube.box.fill")
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Spacer()
                
                Circle()
                    .fill(software.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(software.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(software.version)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding()
        .frame(width: 160, height: 120)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct CapabilityCard: View {
    let capability: Capability
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: URL(string: "https://velo.3zozz.com/assets/icons/\(capability.slug).png")) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "cube.box.fill")
                        .foregroundStyle(Color(hex: capability.color ?? "#3B82F6"))
                }
            }
            .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(capability.name)
                    .font(.subheadline) // Was headline
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(capability.category.capitalized)
                    .font(.caption2) // Was caption
                    .foregroundStyle(.gray)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct InstallationStatusOverlay: View {
    @ObservedObject var viewModel: ServerManagementViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.isInstalling ? "Installing \(viewModel.currentInstallingCapability ?? "")..." : "Installation Finished")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if viewModel.isInstalling {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Button {
                        withAnimation {
                            viewModel.showInstallOverlay = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.gray)
                    }
                }
            }
            
            ProgressView(value: viewModel.installProgress)
                .tint(.blue)
            
            ScrollView {
                Text(viewModel.installLog)
                    .font(.custom("Menlo", size: 10))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 100)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
        }
        .padding()
        .frame(width: 350)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
        .cornerRadius(16)
        .shadow(radius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

