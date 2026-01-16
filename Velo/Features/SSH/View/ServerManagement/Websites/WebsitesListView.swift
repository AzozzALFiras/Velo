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
        Group {
            // Check if any web server is installed
            if viewModel.serverStatus.hasWebServer {
                websitesContent
            } else {
                WebServerSetupView(viewModel: viewModel)
            }
        }
        .background(ColorTokens.layer0)
        .onAppear {
            print("🌐 [WebsitesListView] Appeared - hasWebServer: \(viewModel.serverStatus.hasWebServer)")
            // Initial data is already loaded by ServerManagementViewModel.loadAllDataOptimized()
            // and maintained by startLiveUpdates() loop.
        }
        // Present Details Sheet
        .sheet(item: $selectedWebsite) { website in
            // Create a binding to the website in the viewModel array
            if let index = viewModel.websites.firstIndex(where: { $0.id == website.id }) {
                WebsiteDetailsView(website: $viewModel.websites[index])
            }
        }
        .sheet(isPresented: $showingEditor) {
            WebsiteEditorView(viewModel: viewModel, website: editingWebsite) { _ in
                showingEditor = false
            }
        }
        .alert("Delete Website", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { websiteToDelete = nil }
            Button("Delete Config Only", role: .destructive) {
                if let website = websiteToDelete {
                    viewModel.securelyPerformAction(reason: "Confirm website deletion") {
                        Task {
                            await viewModel.deleteWebsite(website, deleteFiles: false)
                        }
                    }
                }
                websiteToDelete = nil
            }
            Button("Delete All (with files)", role: .destructive) {
                if let website = websiteToDelete {
                    viewModel.securelyPerformAction(reason: "Confirm website and files deletion") {
                        Task {
                            await viewModel.deleteWebsite(website, deleteFiles: true)
                        }
                    }
                }
                websiteToDelete = nil
            }
        } message: {
            if let website = websiteToDelete {
                Text("Delete \(website.domain)?\n\n• Delete Config Only: Removes web server config but keeps files\n• Delete All: Removes config AND website files at \(website.path)")
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
        // Installation Progress Overlay
        .overlay(alignment: .bottomTrailing) {
            if viewModel.showInstallOverlay {
                InstallationStatusOverlay(viewModel: viewModel)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Websites Content
    @ViewBuilder
    private var websitesContent: some View {
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
                                Task {
                                    await viewModel.toggleWebsiteStatus(website)
                                }
                            }, onRestart: {
                                Task {
                                    await viewModel.restartWebsite(website)
                                }
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
    }
}

// MARK: - Web Server Setup View

struct WebServerSetupView: View {
    @ObservedObject var viewModel: ServerManagementViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Icon
                Image(systemName: "globe.badge.chevron.backward")
                    .font(.system(size: 64))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.top, 40)
                
                // Title
                VStack(spacing: 8) {
                    Text("No Web Server Installed")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Text("Install a web server to host websites on this server")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                
                // Web Server Options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Web Servers")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ColorTokens.textSecondary)
                    
                    HStack(spacing: 20) {
                        WebServerOptionCard(
                            name: "Nginx",
                            description: "High-performance\nweb server",
                            icon: "nginx",
                            color: .green
                        ) {
                            viewModel.installCapabilityBySlug("nginx")
                        }
                        
                        WebServerOptionCard(
                            name: "Apache",
                            description: "Reliable & flexible\nweb server",
                            icon: "apache",
                            color: .red
                        ) {
                            viewModel.installCapabilityBySlug("apache")
                        }
                        
                        WebServerOptionCard(
                            name: "LiteSpeed",
                            description: "Ultra-fast\nweb server",
                            icon: "litespeed",
                            color: .blue
                        ) {
                            viewModel.installCapabilityBySlug("litespeed")
                        }
                    }
                }
                
                // Quick Stack Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Stacks")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ColorTokens.textSecondary)
                    
                    HStack(spacing: 16) {
                        QuickStackCard(
                            name: "LEMP Stack",
                            components: "Nginx + PHP + MySQL",
                            color: .purple
                        ) {
                            viewModel.installStack(["nginx", "php", "mysql"])
                        }
                        
                        QuickStackCard(
                            name: "LAMP Stack", 
                            components: "Apache + PHP + MySQL",
                            color: .orange
                        ) {
                            viewModel.installStack(["apache", "php", "mysql"])
                        }
                    }
                }
                
                // Additional Components
                VStack(alignment: .leading, spacing: 16) {
                    Text("Additional Components")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ColorTokens.textSecondary)
                    
                    HStack(spacing: 12) {
                        ComponentInstallButton(name: "PHP", icon: "scroll", color: .indigo) {
                            viewModel.installCapabilityBySlug("php")
                        }
                        ComponentInstallButton(name: "MySQL", icon: "cylinder.split.1x2", color: .orange) {
                            viewModel.installCapabilityBySlug("mysql")
                        }
                        ComponentInstallButton(name: "PostgreSQL", icon: "cylinder.split.1x2", color: .blue) {
                            viewModel.installCapabilityBySlug("postgresql")
                        }
                        ComponentInstallButton(name: "Node.js", icon: "cube.box", color: .green) {
                            viewModel.installCapabilityBySlug("nodejs")
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Quick Stack Card

private struct QuickStackCard: View {
    let name: String
    let components: String
    let color: Color
    let onInstall: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onInstall) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(color)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Text(components)
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                
                Spacer()
                
                // Install Button
                Text("Install")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(color)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(16)
            .background(ColorTokens.layer1)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isHovered ? color.opacity(0.5) : ColorTokens.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Component Install Button

private struct ComponentInstallButton: View {
    let name: String
    let icon: String
    let color: Color
    let onInstall: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onInstall) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(color)
                }
                
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .padding(12)
            .background(isHovered ? ColorTokens.layer2 : ColorTokens.layer1)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isHovered ? color.opacity(0.4) : ColorTokens.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}


// MARK: - Web Server Option Card

private struct WebServerOptionCard: View {
    let name: String
    let description: String
    let icon: String
    let color: Color
    let onInstall: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onInstall) {
            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "server.rack")
                        .font(.system(size: 32))
                        .foregroundStyle(color)
                }
                
                // Name & Description
                VStack(spacing: 4) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Install Button
                Text("Install")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(color)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(24)
            .frame(width: 200)
            .background(ColorTokens.layer1)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isHovered ? color.opacity(0.5) : ColorTokens.borderSubtle, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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
    let onRestart: () -> Void
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

                ActionButton(title: "Restart", icon: "arrow.clockwise", color: .blue) {
                    onRestart()
                }
                
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
    @ObservedObject var viewModel: ServerManagementViewModel
    
    let website: Website?
    let onSave: (Website) -> Void // Just for callback if needed
    
    @State private var domain: String = ""
    @State private var path: String = "/var/www"
    @State private var framework: String = "Static HTML"
    @State private var port: String = "80"
    
    @State private var isAutoPath: Bool = true
    @State private var showFilePicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    // Computed frameworks based on installed software
    var availableFrameworks: [String] {
        var list = ["Static HTML"]
        if viewModel.serverStatus.php.isInstalled { list.append("PHP") }
        if viewModel.serverStatus.nodejs.isInstalled { list.append("Node.js") }
        if viewModel.serverStatus.python.isInstalled { list.append("Python") }
        return list
    }
    
    // Path/Domain sanitization
    private func sanitizeForPath(_ input: String) -> String {
        // Only allow a-z, A-Z, 0-9, ., _, -, /
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-/")
        return String(input.unicodeScalars.filter { allowed.contains($0) })
    }
    
    init(viewModel: ServerManagementViewModel, website: Website?, onSave: @escaping (Website) -> Void) {
        self.viewModel = viewModel
        self.website = website
        self.onSave = onSave
        
        // Initialize states
        _domain = State(initialValue: website?.domain ?? "")
        _path = State(initialValue: website?.path ?? "/var/www")
        _framework = State(initialValue: website?.framework ?? (viewModel.serverStatus.php.isInstalled ? "PHP" : "Static HTML"))
        _port = State(initialValue: String(website?.port ?? 80))
        
        // If editing existing, disable auto-path by default
        _isAutoPath = State(initialValue: website == nil)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                Text(website == nil ? "Add Website" : "Edit Website")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Spacer()
                
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            VStack(spacing: 16) {
                // Domain Field
                VStack(alignment: .leading, spacing: 8) {
                    VeloEditorField(label: "Domain Name", placeholder: "example.com", text: $domain)
                        .onChange(of: domain) { newValue in
                            let sanitized = sanitizeForPath(newValue.lowercased())
                            if sanitized != newValue {
                                domain = sanitized
                            }
                            
                            if isAutoPath && website == nil {
                                // Auto-update path
                                let cleanDomain = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
                                if cleanDomain.isEmpty {
                                    path = "/var/www"
                                } else {
                                    path = "/var/www/\(cleanDomain)"
                                }
                            }
                        }
                    
                    if website == nil {
                        Toggle("Auto-generate root path", isOn: $isAutoPath)
                            .toggleStyle(CheckboxToggleStyle()) // Assuming this exists or standard toggle
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                
                // Root Path Field with Browse
                VStack(alignment: .leading, spacing: 8) {
                    Text("Root Path")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                    
                    HStack(spacing: 8) {
                        TextField("/var/www/html", text: $path)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(10)
                            .background(ColorTokens.layer2)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorTokens.borderSubtle, lineWidth: 1))
                            .onChange(of: path) { newValue in
                                let sanitized = sanitizeForPath(newValue)
                                if sanitized != newValue {
                                    path = sanitized
                                }
                                if !domain.isEmpty && !path.contains(domain) {
                                    isAutoPath = false // Disable auto if user manually edits away from domain
                                }
                            }
                        
                        Button(action: { showFilePicker = true }) {
                            Image(systemName: "folder")
                                .font(.system(size: 14))
                                .frame(width: 36, height: 36)
                                .background(ColorTokens.layer2)
                                .foregroundStyle(ColorTokens.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorTokens.borderSubtle, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                HStack(spacing: 16) {
                    // Framework Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Framework")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ColorTokens.textSecondary)
                        
                        Menu {
                            ForEach(availableFrameworks, id: \.self) { fw in
                                Button(fw) { framework = fw }
                            }
                        } label: {
                            HStack {
                                Text(framework)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                            .padding(10)
                            .background(ColorTokens.layer2)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorTokens.borderSubtle, lineWidth: 1))
                        }
                        .menuStyle(.borderlessButton)
                    }
                    
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
                    .disabled(isSaving)
                
                Button(website == nil ? "Create Website" : "Save Changes") {
                    saveWebsite()
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTokens.accentPrimary)
                .disabled(isSaving || domain.isEmpty)
            }
        }
        .padding(32)
        .frame(width: 500, height: 500) // Increased height for toggle
        .background(ColorTokens.layer1)
        .sheet(isPresented: $showFilePicker) {
            FilePickerSheet(viewModel: viewModel, currentPath: $path)
        }
        .task {
            // Ensure status is up to date (e.g. if we just installed PHP)
            await viewModel.refreshServerStatus()
            
            // Re-evaluate default framework if it was static HTML and PHP is now found
            if framework == "Static HTML" && viewModel.serverStatus.php.isInstalled {
                framework = "PHP"
            }
        }
    }
    
    private func saveWebsite() {
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                if let _ = website {
                    // Edit mode - just update local for now (or implement updateRealWebsite)
                    // Currently user only asked for CREATE logic changes
                    let updated = Website(
                        id: website!.id,
                        domain: domain,
                        path: path,
                        status: website!.status,
                        port: Int(port) ?? 80,
                        framework: framework
                    )
                    // Pass back to parent to handle (which calls viewModel.updateWebsite)
                    // But wait, the closure in WebsitesListView is now dummy?
                    // Ah, I should call viewModel.updateWebsite here if I want consistency
                    // But let's stick to ViewModel calls
                    await MainActor.run {
                        viewModel.updateWebsite(updated)
                        isSaving = false
                        dismiss()
                    }
                } else {
                    // Create mode - REAL creation
                    try await viewModel.createRealWebsite(
                        domain: domain,
                        path: path,
                        framework: framework,
                        port: Int(port) ?? 80
                    )
                    
                    await MainActor.run {
                        isSaving = false
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - File Picker Sheet
struct FilePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ServerManagementViewModel
    @Binding var currentPath: String
    
    @State private var navigationPath: String = "/var/www"
    @State private var files: [ServerFileItem] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Root Path")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            .background(ColorTokens.layer2)
            
            // Path Bar
            HStack {
                Text(navigationPath)
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
                Spacer()
                if navigationPath != "/" {
                    Button(action: goUp) {
                        Image(systemName: "arrow.up.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(ColorTokens.layer1)
            
            // List
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List(files, id: \.name) { file in
                    HStack {
                        Image(systemName: file.isDirectory ? "folder.fill" : "doc")
                            .foregroundStyle(file.isDirectory ? Color.blue : Color.gray)
                        Text(file.name)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if file.isDirectory {
                            enterDirectory(file.name)
                        }
                    }
                }
                .listStyle(.plain)
            }
            
            // Footer Selection
            HStack {
                Text("Selected: \(navigationPath)")
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                Spacer()
                Button("Use Current Folder") {
                    currentPath = navigationPath
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(ColorTokens.layer2)
        }
        .frame(width: 400, height: 500)
        .onAppear {
            if !currentPath.isEmpty && currentPath.hasPrefix("/") {
                // Try to start at current path's parent
                navigationPath = (currentPath as NSString).deletingLastPathComponent
                if navigationPath.isEmpty { navigationPath = "/" }
            }
            loadFiles()
        }
    }
    
    private func loadFiles() {
        isLoading = true
        Task {
            let items = await viewModel.fetchFilesForPicker(path: navigationPath)
            // Filter only directories ideally, but showing all is fine
            await MainActor.run {
                self.files = items.filter { $0.isDirectory }.sorted { $0.name < $1.name }
                self.isLoading = false
            }
        }
    }
    
    private func enterDirectory(_ name: String) {
        if navigationPath == "/" {
            navigationPath = "/\(name)"
        } else {
            navigationPath = "\(navigationPath)/\(name)"
        }
        loadFiles()
    }
    
    private func goUp() {
        navigationPath = (navigationPath as NSString).deletingLastPathComponent
        if navigationPath.isEmpty { navigationPath = "/" }
        loadFiles()
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
