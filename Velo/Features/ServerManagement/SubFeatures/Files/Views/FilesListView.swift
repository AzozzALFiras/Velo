//
//  FilesListView.swift
//  Velo
//
//  Server File Explorer View
//  Browsing files and folders with detailed metadata.
//

import SwiftUI

struct FilesListView: View {
    @ObservedObject var viewModel: ServerManagementViewModel
    
    @State private var searchText = ""
    @State private var selectedFileID: UUID?
    @State private var isShowingUploadDialog = false
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var filteredFiles: [ServerFileItem] {
        viewModel.files.filter { file in
            searchText.isEmpty || file.name.localizedCaseInsensitiveContains(searchText)
        }.sorted { (f1, f2) -> Bool in
            if f1.isDirectory != f2.isDirectory {
                return f1.isDirectory // Folders first
            }
            return f1.name.localizedLowercase < f2.name.localizedLowercase
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 16) {
                    // Navigation Controls
                    HStack(spacing: 4) {
                        Button(action: { viewModel.navigateBack() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(viewModel.pathStack.count > 1 ? ColorTokens.textPrimary : ColorTokens.textTertiary)
                                .frame(width: 32, height: 32)
                                .background(ColorTokens.layer1)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.pathStack.count <= 1)
                        
                        // Breadcrumbs
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ColorTokens.accentPrimary)
                                
                                let components = viewModel.currentPath.components(separatedBy: "/").filter { !$0.isEmpty }
                                
                                Button("/") {
                                    viewModel.jumpToPath("/")
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(components.isEmpty ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                                
                                ForEach(components.indices, id: \.self) { index in
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(ColorTokens.textTertiary)
                                    
                                    let path = "/" + components.prefix(through: index).joined(separator: "/")
                                    Button(components[index]) {
                                        viewModel.jumpToPath(path)
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(index == components.count - 1 ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        .padding(.vertical, 4)
                        .background(ColorTokens.layer1)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Spacer()
                    
                    // Search
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textTertiary)
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 12))
                    }
                    .frame(width: 180)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ColorTokens.layer1)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Upload Button
                    Button(action: {
                        selectAndUploadFiles()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.doc.fill")
                                .font(.system(size: 12))
                            Text("Upload")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(ColorTokens.accentPrimary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(ColorTokens.layer0)
                
                // Table Header
                HStack(spacing: 0) {
                    Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Size").frame(width: 100, alignment: .leading)
                    Text("Permissions").frame(width: 120, alignment: .leading)
                    Text("Owner").frame(width: 100, alignment: .leading)
                    Text("Modified").frame(width: 180, alignment: .leading)
                    Text("").frame(width: 40) // Options Column
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ColorTokens.textTertiary)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(ColorTokens.layer1.opacity(0.5))
                
                // File List
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    List {
                        ForEach(filteredFiles) { file in
                            FileRow(file: file, isSelected: selectedFileID == file.id) {
                                if file.isDirectory {
                                    viewModel.navigateTo(folder: file)
                                }
                            } onDelete: {
                                Task {
                                    viewModel.securelyPerformAction(reason: "Confirm deletion of \(file.name)") {
                                        Task {
                                            let success = await viewModel.deleteFile(file)
                                            if success {
                                                await MainActor.run {
                                                    triggerToast("Deleted \(file.name)")
                                                }
                                            }
                                        }
                                    }
                                }
                            } onRename: { newName in
                                Task {
                                    let success = await viewModel.renameFile(file, to: newName)
                                    if success {
                                        await MainActor.run {
                                            triggerToast("Renamed to \(newName)")
                                        }
                                    }
                                }
                            } onPermissionUpdate: { newPerms in
                                Task {
                                    let success = await viewModel.updatePermissions(file, to: newPerms)
                                    if success {
                                        await MainActor.run {
                                            triggerToast("Permissions updated for \(file.name)")
                                        }
                                    }
                                }
                            } onOwnerUpdate: { newOwner in
                                Task {
                                    let success = await viewModel.updateOwner(file, to: newOwner)
                                    if success {
                                        await MainActor.run {
                                            triggerToast("Owner changed to \(newOwner)")
                                        }
                                    }
                                }
                            } onDownload: {
                                viewModel.downloadFile(file)
                                triggerToast("Downloading \(file.name)...")
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .background(ColorTokens.layer0)
                }
            }
            
            // Floating Upload Progress
            if !viewModel.activeUploads.isEmpty {
                VStack {
                    Spacer()
                    UploadOverlayView(tasks: viewModel.activeUploads)
                        .padding(24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(), value: viewModel.activeUploads.count)
        .overlay(
            VStack {
                if showToast {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(toastMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(BlurView(material: .hudWindow, blendingMode: .withinWindow).clipShape(Capsule()))
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .padding(.top, 40)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
        )
    }
    
    private func triggerToast(_ message: String) {
        toastMessage = message
        withAnimation(.spring()) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showToast = false
            }
        }
    }
    
    private func selectAndUploadFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                viewModel.startMockUpload(fileName: url.lastPathComponent)
            }
        }
    }
}

// MARK: - File Row Component

private struct FileRow: View {
    let file: ServerFileItem
    let isSelected: Bool
    let onNavigate: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onPermissionUpdate: (String) -> Void
    let onOwnerUpdate: (String) -> Void
    let onDownload: () -> Void

    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var newNameBuffer = ""
    @State private var isShowingPermissionEditor = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingRenameDialog = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Name & Icon
            HStack(spacing: 12) {
                Image(systemName: file.isDirectory ? "folder.fill" : fileIcon(for: file.name))
                    .font(.system(size: 14))
                    .foregroundStyle(file.isDirectory ? .blue : ColorTokens.textSecondary)
                    .frame(width: 20)
                
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onTapGesture(count: 2) {
                if file.isDirectory { onNavigate() }
            }
            
            // Metadata
            Group {
                Text(file.sizeString).frame(width: 100, alignment: .leading)
                
                // Numeric Permissions Column
                Text(file.permissions)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(ColorTokens.accentPrimary)
                    .frame(width: 120, alignment: .leading)
                    .help(file.symbolicPermissions)
                
                Text(file.owner).frame(width: 100, alignment: .leading)
                Text(file.dateString).font(.system(size: 12)).foregroundStyle(ColorTokens.textTertiary).frame(width: 180, alignment: .leading)
            }
            .opacity(isHovered ? 1 : 0.8)
            
            // Context Menu Button
            Menu {
                if file.isDirectory {
                    Button(action: onNavigate) {
                        Label("Open Folder", systemImage: "folder.badge.plus")
                    }
                } else {
                    Button(action: onDownload) {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                }
                
                Button(action: {
                    newNameBuffer = file.name
                    isShowingRenameDialog = true
                }) {
                    Label("Rename", systemImage: "pencil")
                }
                
                // Permission Action
                Button(action: { isShowingPermissionEditor = true }) {
                    Label("Permissions", systemImage: "lock.shield")
                }
                
                Divider()
                
                Button(role: .destructive, action: { isShowingDeleteConfirmation = true }) {
                    Label("Trash", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .frame(width: 40)
            .opacity(isHovered ? 1 : 0)
            .popover(isPresented: $isShowingPermissionEditor, arrowEdge: .trailing) {
                PermissionEditorView(initialPerms: file.permissions, initialOwner: file.owner) { newPerms, newOwner in
                    onPermissionUpdate(newPerms)
                    if newOwner != file.owner {
                        onOwnerUpdate(newOwner)
                    }
                }
            }
            .popover(isPresented: $isShowingRenameDialog, arrowEdge: .trailing) {
                RenameDialogView(currentName: file.name) { newName in
                    onRename(newName)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 8)
        .background(isSelected ? ColorTokens.accentPrimary.opacity(0.1) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .alert("Delete File?", isPresented: $isShowingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            if file.isDirectory {
                Text("Are you sure you want to delete the folder '\(file.name)' and all its contents?")
            } else {
                Text("Are you sure you want to delete '\(file.name)'?")
            }
        }
    }
    
    private func fileIcon(for name: String) -> String {
        let ext = name.lowercased().components(separatedBy: ".").last ?? ""
        switch ext {
        case "php", "js", "ts", "py", "rs", "go", "swift": return "doc.text.fill"
        case "yml", "yaml", "conf", "ini", "json": return "doc.text.fill"
        case "gz", "zip", "tar": return "archivebox.fill"
        case "log": return "doc.plaintext.fill"
        case "png", "jpg", "jpeg", "svg": return "photo.fill"
        default: return "doc.fill"
        }
    }
}

// MARK: - Rename Dialog Component

private struct RenameDialogView: View {
    @Environment(\.dismiss) var dismiss
    let currentName: String
    let onRename: (String) -> Void
    
    @State private var newName: String
    
    init(currentName: String, onRename: @escaping (String) -> Void) {
        self.currentName = currentName
        self.onRename = onRename
        _newName = State(initialValue: currentName)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename File")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(ColorTokens.textPrimary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current name")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
                
                Text(currentName)
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.layer2.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("New name")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
                
                TextField("Enter new name", text: $newName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 13, weight: .medium))
                    .padding(8)
                    .background(ColorTokens.layer2)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            
            HStack(spacing: 12) {
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
                
                Button("Rename") {
                    onRename(newName)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTokens.accentPrimary)
                .controlSize(.regular)
            }
        }
        .padding(20)
        .frame(width: 320)
        .background(ColorTokens.layer1)
    }
}

// MARK: - Permission Editor Component

private struct PermissionEditorView: View {
    @Environment(\.dismiss) var dismiss
    let initialPerms: String
    let initialOwner: String
    let onSave: (String, String) -> Void

    @State private var octal: String
    @State private var ownerR: Bool
    @State private var ownerW: Bool
    @State private var ownerX: Bool
    @State private var groupR: Bool
    @State private var groupW: Bool
    @State private var groupX: Bool
    @State private var publicR: Bool
    @State private var publicW: Bool
    @State private var publicX: Bool
    @State private var owner: String
    @State private var applyToSubdir = false

    // Available owners for the picker
    let availableOwners = ["root", "www-data", "nginx", "admin", "nobody"]

    init(initialPerms: String, initialOwner: String, onSave: @escaping (String, String) -> Void) {
        self.initialPerms = initialPerms
        self.initialOwner = initialOwner
        self.onSave = onSave
        _octal = State(initialValue: initialPerms)
        _owner = State(initialValue: initialOwner)

        // Deconstruct octal to checkboxes
        let p = Int(initialPerms) ?? 644
        let o = p / 100
        let g = (p / 10) % 10
        let u = p % 10

        _ownerR = State(initialValue: (o & 4) != 0)
        _ownerW = State(initialValue: (o & 2) != 0)
        _ownerX = State(initialValue: (o & 1) != 0)

        _groupR = State(initialValue: (g & 4) != 0)
        _groupW = State(initialValue: (g & 2) != 0)
        _groupX = State(initialValue: (g & 1) != 0)

        _publicR = State(initialValue: (u & 4) != 0)
        _publicW = State(initialValue: (u & 2) != 0)
        _publicX = State(initialValue: (u & 1) != 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 24) {
                permissionBox(title: "Owner", r: $ownerR, w: $ownerW, x: $ownerX)
                permissionBox(title: "Group", r: $groupR, w: $groupW, x: $groupX)
                permissionBox(title: "Public", r: $publicR, w: $publicW, x: $publicX)
            }
            
            HStack(spacing: 16) {
                // Numeric Input
                TextField("644", text: $octal)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .frame(width: 45) // Slightly narrower for cleaner fit
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(ColorTokens.layer2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .onChange(of: octal) { _, newValue in
                        updateChecksFromOctal(newValue)
                    }
                
                Text("Permission,")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.textSecondary)
                
                Text("Owner")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.textSecondary)
                
                // Functional Owner Picker
                Menu {
                    ForEach(availableOwners, id: \.self) { o in
                        Button(o) { owner = o }
                    }
                } label: {
                    HStack {
                        Text(owner)
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ColorTokens.layer2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .menuStyle(.borderlessButton)
                
                Toggle(isOn: $applyToSubdir) {
                    Text("Apply to subdir")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .toggleStyle(.checkbox)
                
                Spacer()

                Button("Save") {
                    onSave(octal, owner)
                    dismiss() // Close the popover
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTokens.accentPrimary)
                .controlSize(.regular)
            }
        }
        .padding(24)
        .frame(width: 580) // Adjusted for better internal spacing
        .background(ColorTokens.layer1)
        .onChange(of: ownerR) { updateOctalFromChecks() }
        .onChange(of: ownerW) { updateOctalFromChecks() }
        .onChange(of: ownerX) { updateOctalFromChecks() }
        .onChange(of: groupR) { updateOctalFromChecks() }
        .onChange(of: groupW) { updateOctalFromChecks() }
        .onChange(of: groupX) { updateOctalFromChecks() }
        .onChange(of: publicR) { updateOctalFromChecks() }
        .onChange(of: publicW) { updateOctalFromChecks() }
        .onChange(of: publicX) { updateOctalFromChecks() }
    }
    
    private func permissionBox(title: String, r: Binding<Bool>, w: Binding<Bool>, x: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ColorTokens.textPrimary)
            
            VStack(alignment: .leading, spacing: 8) {
                permToggle("Read", isOn: r)
                permToggle("Write", isOn: w)
                permToggle("Execute", isOn: x)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }
    
    private func permToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.system(size: 13))
        }
        .toggleStyle(.checkbox)
    }
    
    private func updateOctalFromChecks() {
        let o = (ownerR ? 4 : 0) + (ownerW ? 2 : 0) + (ownerX ? 1 : 0)
        let g = (groupR ? 4 : 0) + (groupW ? 2 : 0) + (groupX ? 1 : 0)
        let u = (publicR ? 4 : 0) + (publicW ? 2 : 0) + (publicX ? 1 : 0)
        let newOctal = "\(o)\(g)\(u)"
        if octal != newOctal {
            octal = newOctal
        }
    }
    
    private func updateChecksFromOctal(_ val: String) {
        let p = Int(val) ?? 644
        let o = p / 100
        let g = (p / 10) % 10
        let u = p % 10
        
        let nr = (o & 4) != 0
        let nw = (o & 2) != 0
        let nx = (o & 1) != 0
        if ownerR != nr { ownerR = nr }
        if ownerW != nw { ownerW = nw }
        if ownerX != nx { ownerX = nx }
        
        let gr = (g & 4) != 0
        let gw = (g & 2) != 0
        let gx = (g & 1) != 0
        if groupR != gr { groupR = gr }
        if groupW != gw { groupW = gw }
        if groupX != gx { groupX = gx }
        
        let pr = (u & 4) != 0
        let pw = (u & 2) != 0
        let px = (u & 1) != 0
        if publicR != pr { publicR = pr }
        if publicW != pw { publicW = pw }
        if publicX != px { publicX = px }
    }
}

// MARK: - Upload Progress Component

private struct UploadOverlayView: View {
    let tasks: [FileUploadTask]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(tasks) { task in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 3)
                            .frame(width: 36, height: 36)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(task.progress))
                            .stroke(task.isCompleted ? Color.green : ColorTokens.accentPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                        
                        if task.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.green)
                        } else {
                            Text("\(task.progressPercentage)%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.fileName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Text(task.isCompleted ? "Upload finished" : "Uploading to \(task.fileName)...")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    
                    Spacer()
                    
                    if !task.isCompleted {
                        Button(action: {}) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(BlurView(material: .hudWindow, blendingMode: .withinWindow).clipShape(RoundedRectangle(cornerRadius: 12)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            }
        }
        .frame(width: 320)
    }
}

// Helper for Background Blur
private struct BlurView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
