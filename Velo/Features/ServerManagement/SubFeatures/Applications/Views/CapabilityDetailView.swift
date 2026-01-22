//
//  CapabilityDetailView.swift
//  Velo
//
//  Created for Velo Server Management
//

import SwiftUI

struct CapabilityDetailView: View {
    @ObservedObject var viewModel: ServerManagementViewModel
    @State var capability: Capability
    @State private var isLoadingDetails = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // MARK: - Header
                HStack(spacing: 20) {
                    AsyncImage(url: URL(string: capability.icon)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            Image(systemName: "cube.box.fill")
                                .foregroundStyle(Color(hex: capability.color ?? "#3B82F6"))
                        }
                    }
                    .frame(width: 80, height: 80)
                    .background(Color(hex: capability.color ?? "#3B82F6").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(capability.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text(capability.category.capitalized)
                            .font(.headline)
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.horizontal)
                
                Text(capability.description)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal)
                
                // MARK: - Versions
                VStack(alignment: .leading, spacing: 16) {
                    Text("apps.detail.available_versions".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                    
                    if isLoadingDetails {
                        ProgressView()
                            .padding()
                    } else if let versions = capability.versions {
                        ForEach(versions) { version in
                            VersionRow(version: version, capability: capability, viewModel: viewModel)
                        }
                    } else {
                        Text("apps.detail.no_versions".localized)
                            .foregroundStyle(.gray)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 32)
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea())
        .task {
            // Fetch full details if versions are missing
            if capability.versions == nil || capability.versions?.isEmpty == true {
                isLoadingDetails = true
                do {
                    let fullDetails = try await ApiService.shared.fetchCapabilityDetails(slug: capability.slug)
                    self.capability = fullDetails
                } catch {
                    AppLogger.shared.log("Error fetching details: \(error)", level: .error)
                }
                isLoadingDetails = false
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("apps.detail.close".localized) {
                    dismiss()
                }
            }
        }
    }
}

struct VersionRow: View {
    let version: CapabilityVersion
    let capability: Capability
    @ObservedObject var viewModel: ServerManagementViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("v\(version.version)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    if version.stability == "stable" {
                        Text("apps.detail.stable".localized)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    
                    if version.isDefault {
                        Text("apps.detail.default".localized)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                
                Text("apps.detail.released".localized(formatDate(version.releaseDate)))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            Button {
                Task {
                    await viewModel.installCapability(capability, version: version.version)
                }
            } label: {
                Text("apps.detail.install".localized)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "N/A" }
        // Simple formatter
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}
