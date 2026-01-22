
import SwiftUI

struct NginxSidebarView: View {
    @ObservedObject var viewModel: NginxDetailViewModel
    var onDismiss: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                        .frame(width: 32, height: 32)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    Text("Nginx")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                            .padding(8)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
            .padding(20)
            
            // Navigation Items
            ScrollView {
                VStack(spacing: 4) {
                    sidebarItem(title: "Service", icon: "gearshape.fill", section: .service)
                    sidebarItem(title: "Configuration", icon: "slider.horizontal.3", section: .configuration)
                    sidebarItem(title: "Config File", icon: "doc.text.fill", section: .configFile)
                    sidebarItem(title: "Modules", icon: "puzzlepiece.fill", section: .modules)
                    sidebarItem(title: "Security", icon: "shield.fill", section: .security)
                    sidebarItem(title: "Logs", icon: "list.bullet.rectangle.portrait.fill", section: .logs)
                    sidebarItem(title: "Status", icon: "chart.bar.fill", section: .status)
                }
                .padding(.horizontal, 12)
            }
        }
        .frame(width: 260)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(Color.white.opacity(0.08)),
            alignment: .trailing
        )
    }
    
    private func sidebarItem(title: String, icon: String, section: NginxDetailSection) -> some View {
        Button {
            viewModel.selectedSection = section
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                
                Spacer()
                
                if section == viewModel.selectedSection {
                    Capsule()
                        .fill(Color.green)
                        .frame(width: 3, height: 16)
                }
            }
            .foregroundStyle(section == viewModel.selectedSection ? .white : .gray)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                section == viewModel.selectedSection ? Color.white.opacity(0.08) : Color.clear
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
