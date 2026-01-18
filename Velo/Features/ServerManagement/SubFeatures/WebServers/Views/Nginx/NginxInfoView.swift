import SwiftUI

struct NginxInfoView: View {
    @ObservedObject var viewModel: NginxDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nginx Version & Modules")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            if viewModel.isLoadingInfo {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        InfoSection(title: "Build Arguments") {
                            Text(viewModel.configureArguments.joined(separator: "\n"))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.gray)
                        }
                        
                        InfoSection(title: "Detected Modules") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                                ForEach(viewModel.modules, id: \.self) { module in
                                    Text(module)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .cornerRadius(6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            
            content
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.03))
                .cornerRadius(10)
        }
    }
}
