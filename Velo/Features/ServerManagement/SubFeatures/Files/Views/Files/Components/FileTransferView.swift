//
//  FileTransferView.swift
//  Velo
//
//  Transfer progress overlay and transfer list view.
//

import SwiftUI

// MARK: - Transfer Overlay (Floating Progress)

struct TransferOverlayView: View {
    @ObservedObject var viewModel: FilesDetailViewModel

    var body: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.activeTransfers) { task in
                TransferItemView(task: task) {
                    viewModel.cancelTransfer(task)
                }
            }
        }
        .frame(width: 320)
        .padding(20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Transfer Item

private struct TransferItemView: View {
    let task: FileTransferTask
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: task.progress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))

                progressIcon
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.fileName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textSecondary)

                    if case .inProgress = task.state {
                        Text("\(task.transferredString) / \(task.totalString)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }

            Spacer()

            // Cancel button
            if task.state.isActive {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }

    private var progressColor: Color {
        switch task.state {
        case .completed: return ColorTokens.success
        case .failed: return ColorTokens.error
        case .cancelled: return ColorTokens.warning
        default: return ColorTokens.accentPrimary
        }
    }

    @ViewBuilder
    private var progressIcon: some View {
        switch task.state {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ColorTokens.success)
        case .failed:
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ColorTokens.error)
        case .cancelled:
            Image(systemName: "minus")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ColorTokens.warning)
        default:
            Text("\(task.progressPercentage)%")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ColorTokens.textPrimary)
        }
    }

    private var statusText: String {
        switch task.state {
        case .pending:
            return "files.transfer.pending".localized
        case .inProgress:
            return task.isUpload ? "files.transfer.uploading".localized : "files.transfer.downloading".localized
        case .completed:
            return "files.transfer.completed".localized
        case .failed(let error):
            return "files.transfer.failed".localized(error)
        case .cancelled:
            return "files.transfer.cancelled".localized
        }
    }
}

// MARK: - Transfers Section View (for sidebar section)

struct TransfersSectionView: View {
    @ObservedObject var viewModel: FilesDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("files.transfers.title".localized)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                if !viewModel.completedTransfers.isEmpty {
                    Button("files.transfers.clear".localized) {
                        viewModel.clearCompletedTransfers()
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .buttonStyle(.plain)
                }
            }

            if viewModel.activeTransfers.isEmpty && viewModel.completedTransfers.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(ColorTokens.textTertiary)

                    Text("files.transfers.empty".localized)
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Active transfers
                if !viewModel.activeTransfers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("files.transfers.active".localized(viewModel.activeTransfers.count))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ColorTokens.textTertiary)

                        ForEach(viewModel.activeTransfers) { task in
                            TransferListItem(task: task, showCancel: true) {
                                viewModel.cancelTransfer(task)
                            }
                        }
                    }
                }

                // Completed transfers
                if !viewModel.completedTransfers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("files.transfers.completed.count".localized(viewModel.completedTransfers.count))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .padding(.top, viewModel.activeTransfers.isEmpty ? 0 : 12)

                        ForEach(viewModel.completedTransfers.prefix(10)) { task in
                            TransferListItem(task: task, showCancel: false, onCancel: nil)
                        }
                    }
                }
            }
        }
        .padding(20)
    }
}

// MARK: - Transfer List Item (Compact)

private struct TransferListItem: View {
    let task: FileTransferTask
    let showCancel: Bool
    let onCancel: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            // Direction icon
            Image(systemName: task.isUpload ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(iconColor)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.fileName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)

                if case .inProgress(let progress) = task.state {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(ColorTokens.accentPrimary)
                        .scaleEffect(y: 0.5)
                } else {
                    Text(statusText)
                        .font(.system(size: 10))
                        .foregroundStyle(statusColor)
                }
            }

            Spacer()

            // Cancel or status
            if showCancel, let onCancel = onCancel {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(ColorTokens.layer2.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var iconColor: Color {
        switch task.state {
        case .completed: return ColorTokens.success
        case .failed: return ColorTokens.error
        case .cancelled: return ColorTokens.warning
        default: return ColorTokens.accentPrimary
        }
    }

    private var statusText: String {
        switch task.state {
        case .pending: return "files.transfer.pending".localized
        case .inProgress: return "\(task.progressPercentage)%"
        case .completed: return "files.transfer.completed".localized
        case .failed: return "files.transfer.failed.short".localized
        case .cancelled: return "files.transfer.cancelled".localized
        }
    }

    private var statusColor: Color {
        switch task.state {
        case .completed: return ColorTokens.success
        case .failed: return ColorTokens.error
        case .cancelled: return ColorTokens.warning
        default: return ColorTokens.textTertiary
        }
    }
}
