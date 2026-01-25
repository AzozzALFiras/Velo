
import SwiftUI

struct UnifiedBlockedIpsSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel
    
    @State private var newIpAddress: String = ""
    @State private var diagnosticReport: String?
    @State private var isDiagnosing: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // Header & Manual Add
            HStack {
                Text("Blocked IPs")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                TextField("IP Address (e.g. 1.2.3.4)", text: $newIpAddress)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .frame(width: 200)
                
                Button {
                    Task {
                        if !newIpAddress.isEmpty {
                            _ = await viewModel.blockIP(newIpAddress)
                            newIpAddress = ""
                            await viewModel.loadSectionData()
                        }
                    }
                } label: {
                    Label("Block", systemImage: "hand.raised.fill")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.8))
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(newIpAddress.isEmpty)
                
                // Diagnostics
                Button {
                    isDiagnosing = true
                    let vm = viewModel
                    Task {
                        diagnosticReport = await vm.diagnoseSecurity()
                        isDiagnosing = false
                    }
                } label: {
                    Image(systemName: "stethoscope")
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("Diagnose Security Configuration")
                
                // Repair
                Button {
                    isDiagnosing = true
                    let vm = viewModel
                    Task {
                        diagnosticReport = await vm.repairVHostConfigs()
                        isDiagnosing = false
                    }
                } label: {
                    Image(systemName: "hammer.fill")
                         .foregroundStyle(.yellow)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("Repair Broken Nginx Config")
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            // Stats & List (Unchanged)
            HStack {
                Text("\(state.blockedIps.count) IPs Blocked")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Spacer()
            }
            .padding(.horizontal)
            
            // List
            if state.blockedIps.isEmpty {
                 VStack(spacing: 12) {
                    Image(systemName: "shield.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray)
                    Text("No IPs are currently blocked")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: 300)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(state.blockedIps, id: \.self) { ip in
                            HStack {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundStyle(.red)
                                Text(ip)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.white)
                                Spacer()
                                
                                Button {
                                    Task {
                                        _ = await viewModel.unblockIP(ip)
                                        await viewModel.loadSectionData()
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.gray)
                                        .padding(8)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding()
                            .background(Color.white.opacity(0.02))
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(Color.white.opacity(0.05)),
                                alignment: .bottom
                            )
                        }
                    }
                }
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
            }
        }
        .padding()
        .popover(item: $diagnosticReport) { report in
             VStack(alignment: .leading) {
                 HStack {
                     Text("Security Diagnostic Report")
                         .font(.headline)
                     Spacer()
                     Button {
                         diagnosticReport = nil
                     } label: {
                         Image(systemName: "xmark.circle.fill")
                             .foregroundStyle(.gray)
                     }
                     .buttonStyle(.plain)
                 }
                 .padding()
                 
                 ScrollView {
                     Text(report)
                         .font(.system(.caption, design: .monospaced))
                         .padding()
                         .textSelection(.enabled)
                 }
             }
             .frame(width: 500, height: 400)
        }
    }
}

extension String: Identifiable {
    public var id: String { self }
}
