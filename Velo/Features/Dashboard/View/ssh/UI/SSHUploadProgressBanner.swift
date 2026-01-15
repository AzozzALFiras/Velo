//
//  SSHUploadProgressBanner.swift
//  Velo
//
//  SSH Upload Progress Banner
//  Displays upload progress with filename, percentage, and elapsed time
//

import SwiftUI

// MARK: - SSH Upload Progress Banner

/// Banner showing SSH file upload progress
struct SSHUploadProgressBanner: View {

    let fileName: String
    let progress: Double
    let startTime: Date?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Uploading: \(fileName)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        if progress > 0 {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(VeloDesign.Colors.neonCyan)
                        }

                        if let startTime = startTime {
                            Text(elapsedTimeString(from: startTime))
                                .font(.system(size: 9))
                                .foregroundColor(VeloDesign.Colors.textMuted)
                        }
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(VeloDesign.Colors.neonCyan)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if progress > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(VeloDesign.Colors.neonCyan.opacity(0.1))

                        Rectangle()
                            .frame(width: geo.size.width * CGFloat(progress), height: 2)
                            .foregroundColor(VeloDesign.Colors.neonCyan)
                    }
                }
                .frame(height: 2)
            }
        }
        .background(VeloDesign.Colors.neonCyan.opacity(0.15))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(VeloDesign.Colors.neonCyan.opacity(0.3)),
            alignment: .bottom
        )
    }

    /// Format elapsed time for upload progress
    private func elapsedTimeString(from startTime: Date) -> String {
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s elapsed"
        } else {
            return "\(seconds)s elapsed"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        SSHUploadProgressBanner(
            fileName: "project.zip",
            progress: 0.45,
            startTime: Date().addingTimeInterval(-30)
        )

        SSHUploadProgressBanner(
            fileName: "config.json",
            progress: 0.0,
            startTime: Date()
        )
    }
    .frame(width: 340)
    .background(ColorTokens.layer1)
}
