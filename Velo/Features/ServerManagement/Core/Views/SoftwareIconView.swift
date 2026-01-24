import SwiftUI

struct SoftwareIconView: View {
    let iconURL: String
    let slug: String
    var color: Color = .blue
    var size: CGFloat = 32
    
    var body: some View {
        let _ = print("🖼️ [SoftwareIconView] Loading icon for slug: \(slug), URL: \(iconURL)")
        
        Group {
            if iconURL.hasPrefix("http") {
                AsyncImage(url: URL(string: iconURL.replacingOccurrences(of: "\\/", with: "/"))) { phase in
                    switch phase {
                    case .success(let image):
                        let _ = print("✅ [SoftwareIconView] Successfully loaded image for: \(slug)")
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure(let error):
                        let _ = print("❌ [SoftwareIconView] Failed to load image for: \(slug) - Error: \(error.localizedDescription)")
                        fallbackIcon
                    case .empty:
                        ProgressView()
                            .scaleEffect(size / 40)
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
        .padding(size * 0.2)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25))
        .foregroundStyle(color)
    }
    
    @ViewBuilder
    private var fallbackIcon: some View {
        Image(systemName: getSystemIcon(for: slug, iconName: iconURL))
            .font(.system(size: size * 0.5, weight: .semibold))
    }
    
    private func getSystemIcon(for slug: String, iconName: String) -> String {
        if !iconURL.isEmpty && !iconURL.contains("/") && !iconURL.contains(".") {
            return iconURL
        }
        
        switch slug.lowercased() {
        case "nginx", "apache": return "server.rack"
        case "php": return "terminal"
        case "mysql", "mariadb", "postgresql", "postgres": return "cylinder.split.1x2"
        case "redis": return "memorychip"
        case "mongodb": return "leaf"
        case "python", "node", "nodejs": return "terminal"
        default: return "app.dashed"
        }
    }
}
