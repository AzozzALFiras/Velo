import SwiftUI

struct NginxDetailView: View {
    let session: TerminalViewModel?
    var onDismiss: (() -> Void)?
    
    @StateObject private var viewModel: NginxDetailViewModel
    
    init(session: TerminalViewModel?, onDismiss: (() -> Void)? = nil) {
        self.session = session
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: NginxDetailViewModel(session: session))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            NginxSidebarView(viewModel: viewModel)
                .frame(width: 250)
                .background(Color(red: 0.08, green: 0.08, blue: 0.1))
                .overlay(
                    Rectangle()
                        .frame(width: 1)
                        .foregroundColor(Color.white.opacity(0.1)),
                    alignment: .trailing
                )
            
            // Content
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with overlay close button (if needed, but sidebar has navigation usually)
                    // Actually, let's put the close button in the top right of the content area
                    HStack {
                        Spacer()
                        Button {
                            onDismiss?()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.gray.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .padding([.top, .trailing], 16)
                    }
                    
                    contentView
                        .padding(24)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 20)
        .overlay(alignment: .bottom) {
            if let error = viewModel.errorMessage {
                feedbackBanner(message: error, isError: true)
            }
            if let success = viewModel.successMessage {
                feedbackBanner(message: success, isError: false)
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
    
    @ViewBuilder
    var contentView: some View {
        switch viewModel.selectedSection {
        case .service:
            NginxServiceView(viewModel: viewModel)
        case .configuration:
            NginxConfigurationView(viewModel: viewModel)
        case .configFile:
            NginxConfigFileView(viewModel: viewModel)
        case .logs:
            NginxLogsView(viewModel: viewModel)
        case .modules:
            NginxInfoView(viewModel: viewModel)
        case .security:
            NginxSecurityView(viewModel: viewModel)
        case .status:
            NginxStatusView(viewModel: viewModel)
        }
    }
    
    func feedbackBanner(message: String, isError: Bool) -> some View {
        HStack {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? .red : .green)
            Text(message)
                .foregroundStyle(.white)
        }
        .padding()
        .background(Color(red: 0.15, green: 0.15, blue: 0.18))
        .cornerRadius(8)
        .shadow(radius: 10)
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            if !isError {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        viewModel.successMessage = nil
                    }
                }
            }
        }
    }
}
