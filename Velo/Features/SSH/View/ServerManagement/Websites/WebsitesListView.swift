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
    
    @State private var showingEditor = false
    @State private var editingWebsite: Website? = nil
    
    // For Deletion Confirmation
    @State private var showingDeleteAlert = false
    @State private var websiteToDelete: Website? = nil
    @State private var showingErrorAlert = false
    
    var filteredWebsites: [Website] {
        viewModel.websites.filter { site in
            let matchesSearch = searchText.isEmpty || site.domain.localizedCaseInsensitiveContains(searchText) || site.path.localizedCaseInsensitiveContains(searchText)
            let matchesStatus = selectedStatus == nil || site.status == selectedStatus
            return matchesSearch && matchesStatus
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Add Button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Websites")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("\(viewModel.websites.count) sites hosted on this server")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    editingWebsite = nil
                    showingEditor = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add Website")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ColorTokens.accentPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 20)

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
                    
                    // Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 16)], spacing: 16) {
                        ForEach(filteredWebsites) { website in
                            WebsiteCard(website: website, onToggleStatus: {
                                viewModel.toggleWebsiteStatus(website)
                            }, onOpenDetails: {
                                selectedWebsite = website
                            }, onEdit: {
                                editingWebsite = website
                                showingEditor = true
                            }, onDelete: {
                                websiteToDelete = website
                                showingDeleteAlert = true
                            })
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
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
        .sheet(isPresented: $showingEditor) {
            WebsiteEditorView(website: editingWebsite) { newWebsite in
                if let _ = editingWebsite {
                    viewModel.updateWebsite(newWebsite)
                } else {
                    viewModel.addWebsite(newWebsite)
                }
            }
        }
        .alert("Delete Website", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { websiteToDelete = nil }
            Button("Delete", role: .destructive) {
                if let website = websiteToDelete {
                    viewModel.securelyPerformAction(reason: "Confirm website deletion") {
                        viewModel.deleteWebsite(website)
                    }
                }
                websiteToDelete = nil
            }
        } message: {
            if let website = websiteToDelete {
                Text("Are you sure you want to delete \(website.domain)? This action cannot be undone.")
            }
        }
        .alert("Authentication Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .onChange(of: viewModel.errorMessage) { newValue in
            if newValue != nil {
                showingErrorAlert = true
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
    let onEdit: () -> Void
    let onDelete: () -> Void
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
                
                ActionButton(title: "Edit", icon: "pencil", color: .orange) {
                    onEdit()
                }
                
                Spacer()
                
                ActionButton(title: "Delete", icon: "trash", color: .red) {
                    onDelete()
                }
                
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

// MARK: - Website Editor View

struct WebsiteEditorView: View {
    @Environment(\.dismiss) var dismiss
    let website: Website?
    let onSave: (Website) -> Void
    
    @State private var domain: String = ""
    @State private var path: String = "/var/www/html"
    @State private var framework: String = "PHP"
    @State private var port: String = "80"
    
    init(website: Website?, onSave: @escaping (Website) -> Void) {
        self.website = website
        self.onSave = onSave
        _domain = State(initialValue: website?.domain ?? "")
        _path = State(initialValue: website?.path ?? "/var/www/html")
        _framework = State(initialValue: website?.framework ?? "PHP")
        _port = State(initialValue: String(website?.port ?? 80))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(website == nil ? "Add Website" : "Edit Website")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(ColorTokens.textPrimary)
            
            VStack(spacing: 16) {
                VeloEditorField(label: "Domain Name", placeholder: "example.com", text: $domain)
                VeloEditorField(label: "Root Path", placeholder: "/var/www/html", text: $path)
                
                HStack(spacing: 16) {
                    VeloEditorField(label: "Framework", placeholder: "PHP", text: $framework)
                    VeloEditorField(label: "Port", placeholder: "80", text: $port)
                        .frame(width: 80)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(ColorTokens.textSecondary)
                
                Button("Save") {
                    let newWebsite = Website(
                        id: website?.id ?? UUID(),
                        domain: domain,
                        path: path,
                        status: website?.status ?? .stopped,
                        port: Int(port) ?? 80,
                        framework: framework
                    )
                    onSave(newWebsite)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTokens.accentPrimary)
            }
        }
        .padding(32)
        .frame(width: 500, height: 400)
        .background(ColorTokens.layer1)
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
