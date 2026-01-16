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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                
                // MARK: - Search & Header
                VStack(alignment: .leading, spacing: 16) {
                    Text("Applications")
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
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                // MARK: - Installed (Downloads)
                if !viewModel.installedSoftware.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Installed")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(viewModel.installedSoftware) { software in
                                    InstalledAppCard(software: software)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // MARK: - All Applications
                VStack(alignment: .leading, spacing: 16) {
                    Text("All Applications")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                    
                    if viewModel.isLoading { // You might want a specific loading state for capabilities
                        ProgressView()
                            .padding()
                    } else if viewModel.filteredCapabilities.isEmpty {
                        Text("No applications found.")
                            .foregroundStyle(.gray)
                            .padding(.horizontal)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                            ForEach(viewModel.filteredCapabilities) { cap in
                                Button {
                                    selectedCapability = cap
                                } label: {
                                    CapabilityCard(capability: cap)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 32)
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea())
        .sheet(item: $selectedCapability) { cap in
            CapabilityDetailView(viewModel: viewModel, capability: cap)
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.showInstallOverlay {
                InstallationStatusOverlay(viewModel: viewModel)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Subviews

struct InstalledAppCard: View {
    let software: InstalledSoftware
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: software.iconName)
                    .font(.title2)
                    .foregroundStyle(.white)
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
            AsyncImage(url: URL(string: capability.icon)) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "cube.box.fill")
                        .foregroundStyle(Color(hex: capability.color))
                }
            }
            .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(capability.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(capability.category.capitalized)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding()
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

