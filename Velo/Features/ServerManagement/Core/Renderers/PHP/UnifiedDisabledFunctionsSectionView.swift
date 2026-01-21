//
//  UnifiedDisabledFunctionsSectionView.swift
//  Velo
//
//  Unified PHP disabled functions view.
//

import SwiftUI

struct UnifiedDisabledFunctionsSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Disabled Functions")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("\(state.disabledFunctions.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)

                Spacer()
            }

            Text("These PHP functions are disabled for security reasons in php.ini")
                .font(.caption)
                .foregroundStyle(.gray)

            if state.disabledFunctions.isEmpty {
                emptyStateView
            } else {
                functionsGrid
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("No functions disabled")
                .font(.subheadline)
                .foregroundStyle(.gray)

            Text("All PHP functions are currently enabled")
                .font(.caption)
                .foregroundStyle(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var functionsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
            ForEach(state.disabledFunctions, id: \.self) { func_ in
                functionChip(func_)
            }
        }
    }

    private func functionChip(_ name: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)

            Text(name)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
