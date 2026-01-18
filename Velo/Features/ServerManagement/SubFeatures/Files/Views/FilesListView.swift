//
//  FilesListView.swift
//  Velo
//
//  Server File Explorer View - Integration wrapper
//  This view integrates the new modular Files feature with the ServerManagementView.
//

import SwiftUI

struct FilesListView: View {
    @ObservedObject var viewModel: ServerManagementViewModel

    var body: some View {
        FilesDetailView(session: viewModel.session)
    }
}
