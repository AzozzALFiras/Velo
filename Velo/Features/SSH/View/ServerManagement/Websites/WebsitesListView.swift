//
//  WebsitesListView.swift
//  Velo
//
//  Websites Management View
//  List of hosted websites with quick actions.
//

import SwiftUI

struct WebsitesListView: View {
    
    @ObservedObject var viewModel: ServerManagementViewModel
    
    // State for Search & Filter
    @State private var searchText = ""
    @State private var selectedStatus: Website.WebsiteStatus? = nil
    @State private var selectedWebsite: Website? = nil
    
    var filteredWebsites: [Website] {
        viewModel.websites.filter { site in
            let matchesSearch = searchText.isEmpty || site.domain.localizedCaseInsensitiveContains(searchText) || site.path.localizedCaseInsensitiveContains(searchText)
            let matchesStatus = selectedStatus == nil || site.status == selectedStatus
            return matchesSearch && matchesStatus
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Controls: Search & Filter
                HStack(spacing: 12) {
                    // Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(ColorTokens.textTertiary)
                        TextField("Search websites...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(8)
                    .background(ColorTokens.layer1)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(ColorTokens.borderSubtle, lineWidth: 1)
                    )
                    
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterPill(title: "All", isSelected: selectedStatus == nil) {
                                selectedStatus = nil
                            }
                            
                            ForEach(Website.WebsiteStatus.allCases, id: \.self) { status in
                                FilterPill(title: status.title, isSelected: selectedStatus == status) {
                                    selectedStatus = selectedStatus == status ? nil : status
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 16)], spacing: 16) {
                    ForEach(filteredWebsites) { website in
                        WebsiteCard(website: website, onToggleStatus: {
                            viewModel.toggleWebsiteStatus(website)
                        }, onOpenDetails: {
                            selectedWebsite = website
                        })
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(ColorTokens.layer0)
        // Present Details Sheet
        .sheet(item: $selectedWebsite) { website in
            // Create a binding to the website in the viewModel array
            if let index = viewModel.websites.firstIndex(where: { $0.id == website.id }) {
                WebsiteDetailsView(website: $viewModel.websites[index])
            }
        }
    }
}

// MARK: - Filter Pill
private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? ColorTokens.accentPrimary : ColorTokens.layer1)
                .foregroundStyle(isSelected ? .white : ColorTokens.textSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.clear : ColorTokens.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Website Card

private struct WebsiteCard: View {
    
    let website: Website
    let onToggleStatus: () -> Void
    let onOpenDetails: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onOpenDetails) {
            VStack(alignment: .leading, spacing: 16) {
            
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(website.domain)
                        .font(.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Text(website.path)
                        .font(.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    HStack(spacing: 6) {
                        Text(website.framework)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ColorTokens.layer2)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(ColorTokens.textSecondary)
                        
                        Text("Port: \(website.port)")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ColorTokens.layer2)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
                
                // Status Badge
                HStack(spacing: 4) {
                    Image(systemName: website.status.icon)
                        .font(.system(size: 8))
                    Text(website.status.title)
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(website.status.color.opacity(0.15))
                .foregroundStyle(website.status.color)
                .clipShape(Capsule())
            }
            
            Divider()
                .background(ColorTokens.borderSubtle)
            
            // Actions
            HStack {
                ActionButton(
                    title: website.status == .running ? "Stop" : "Start",
                    icon: website.status == .running ? "stop.fill" : "play.fill",
                    color: website.status == .running ? .red : .green
                ) {
                    onToggleStatus()
                }
                
                ActionButton(title: "Restart", icon: "arrow.clockwise", color: .blue) {}
                
                Spacer()
                
                ActionButton(title: "Open", icon: "safari", color: .gray) {}
            }
            }
            .padding()
            .background(ColorTokens.layer1)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isHovered ? ColorTokens.accentPrimary.opacity(0.3) : ColorTokens.borderSubtle, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.05 : 0), radius: 8, x: 0, y: 2)
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain) // Important for wrapping button
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(isHovered ? 0.2 : 0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
