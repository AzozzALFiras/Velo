
import SwiftUI

struct NginxModulesView: View {
    @ObservedObject var viewModel: NginxDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Installed Modules")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("List of compiled modules for this Nginx instance")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            
            if viewModel.isLoadingInfo {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if viewModel.modules.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cube.box")
                        .font(.system(size: 32))
                        .foregroundStyle(.gray)
                    Text("No modules detected")
                        .foregroundStyle(.gray)
                    
                    Button("Reload Info") {
                        Task { await viewModel.loadModules() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.modules, id: \.self) { module in
                            HStack {
                                Image(systemName: "cube.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.purple)
                                
                                Text(module)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)
                                
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            
            // Configure Arguments
            if !viewModel.configureArguments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configure Arguments")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.configureArguments, id: \.self) { arg in
                            Text(arg)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.gray)
                                .padding(8)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .onAppear {
            if viewModel.modules.isEmpty {
                Task { await viewModel.loadModules() }
            }
        }
    }
}
