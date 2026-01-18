import SwiftUI

struct PHPDisabledFunctionsView: View {
    @ObservedObject var viewModel: PHPDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("php.disabled.count".localized(viewModel.disabledFunctions.count))
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                
                Spacer()
                
                Text("php.disabled.hint".localized)
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.8))
            }
            
            if viewModel.isLoadingDisabledFunctions {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if viewModel.disabledFunctions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("php.disabled.none.title".localized)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("php.disabled.none.desc".localized)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.disabledFunctions, id: \.self) { func_name in
                        Button {
                            Task {
                                _ = await viewModel.removeDisabledFunction(func_name)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                                
                                Text(func_name)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.gray)
                            }
                            .padding(10)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isPerformingAction)
                    }
                }
            }
        }
    }
}
