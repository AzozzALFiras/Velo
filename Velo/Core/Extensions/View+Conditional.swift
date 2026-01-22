//
//  View+Conditional.swift
//  Velo
//
//  Conditional View modifier extension
//

import SwiftUI

extension View {
    /// Applies the given transform if the condition evaluates to true.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
