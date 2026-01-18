import SwiftUI

struct MySQLDetailView: View {
    
    @StateObject private var viewModel: MySQLDetailViewModel
    var onDismiss: (() -> Void)?
    
    init(session: TerminalViewModel?, onDismiss: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: MySQLDetailViewModel(session: session))
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            MySQLSidebarView(viewModel: viewModel, onDismiss: onDismiss)
            
            // Main Content
            mainContentView
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        .task {
            await viewModel.loadData()
        }
        .onChange(of: viewModel.selectedSection) { _ in
            Task {
                await viewModel.loadSectionData()
            }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Content Header
            HStack {
                Text(viewModel.selectedSection.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if viewModel.isLoading || viewModel.isPerformingAction {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }
            }
            .padding(24)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Section Content
            ScrollView {
                ZStack {
                    Group {
                        switch viewModel.selectedSection {
                        case .service:
                            MySQLServiceView(viewModel: viewModel)
                        case .configuration:
                            MySQLConfigurationView(viewModel: viewModel)
                        case .users:
                            MySQLUsersView(viewModel: viewModel)
                        case .logs:
                            MySQLLogsView(viewModel: viewModel)
                        case .status:
                            MySQLStatusView(viewModel: viewModel)
                        case .databases:
                            // Fallback or list
                            Text("Databases list managed in Databases tab.")
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .padding(24)
            }
            
            // Feedback Messages
            if let error = viewModel.errorMessage {
                feedbackBanner(message: error, isError: true)
            }
            
            if let success = viewModel.successMessage {
                feedbackBanner(message: success, isError: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func feedbackBanner(message: String, isError: Bool) -> some View {
        HStack {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? .red : .green)
            
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.white)
            
            Spacer()
            
            Button {
                if isError {
                    viewModel.errorMessage = nil
                } else {
                    viewModel.successMessage = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(isError ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
